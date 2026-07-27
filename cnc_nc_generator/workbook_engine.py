from __future__ import annotations

import json
import re
import zipfile
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable
from xml.etree import ElementTree as ET

NS = {"x": "http://schemas.openxmlformats.org/spreadsheetml/2006/main", "r": "http://schemas.openxmlformats.org/officeDocument/2006/relationships"}
REL_NS = {"rel": "http://schemas.openxmlformats.org/package/2006/relationships"}
CELL_REF_RE = re.compile(r"(?:(?:'[^']+'|[A-Za-z_][A-Za-z0-9_ .]*)!)?\$?[A-Z]{1,3}\$?\d+")


@dataclass(frozen=True, slots=True)
class WorkbookCell:
    sheet: str
    address: str
    value: str
    formula: str | None = None

    @property
    def dependencies(self) -> tuple[str, ...]:
        if not self.formula:
            return ()
        return tuple(dict.fromkeys(CELL_REF_RE.findall(self.formula)))


@dataclass(frozen=True, slots=True)
class WorksheetModel:
    name: str
    cells: tuple[WorkbookCell, ...]

    @property
    def formulas(self) -> tuple[WorkbookCell, ...]:
        return tuple(cell for cell in self.cells if cell.formula)


class WorkbookEngine:
    """Read-only workbook inspection and formula-analysis helper."""

    def __init__(self, workbook_path: str | Path) -> None:
        self.path = Path(workbook_path)
        if not self.path.exists():
            raise FileNotFoundError(self.path)
        self._shared_strings: list[str] | None = None

    def reverse_engineer(self) -> tuple[WorksheetModel, ...]:
        with zipfile.ZipFile(self.path) as archive:
            workbook = ET.fromstring(archive.read("xl/workbook.xml"))
            rels = ET.fromstring(archive.read("xl/_rels/workbook.xml.rels"))
            rel_targets = {rel.attrib["Id"]: rel.attrib["Target"] for rel in rels.findall("rel:Relationship", REL_NS)}
            models: list[WorksheetModel] = []
            for sheet in workbook.findall("x:sheets/x:sheet", NS):
                name = sheet.attrib["name"]
                rel_id = sheet.attrib[f"{{{NS['r']}}}id"]
                target = rel_targets[rel_id]
                xml_path = "xl/" + target.lstrip("/") if not target.startswith("xl/") else target
                models.append(WorksheetModel(name, tuple(self._read_sheet(archive, xml_path, name))))
            return tuple(models)

    def formula_catalog(self) -> dict[str, dict[str, dict[str, object]]]:
        catalog: dict[str, dict[str, dict[str, object]]] = {}
        for sheet in self.reverse_engineer():
            catalog[sheet.name] = {
                cell.address: {"formula": cell.formula, "cached_value": cell.value, "dependencies": cell.dependencies}
                for cell in sheet.formulas
            }
        return catalog

    def write_formula_catalog(self, output_path: str | Path) -> None:
        Path(output_path).write_text(json.dumps(self.formula_catalog(), indent=2, sort_keys=True), encoding="utf-8")

    def _read_sheet(self, archive: zipfile.ZipFile, xml_path: str, sheet_name: str) -> Iterable[WorkbookCell]:
        root = ET.fromstring(archive.read(xml_path))
        for cell in root.findall(".//x:sheetData/x:row/x:c", NS):
            address = cell.attrib.get("r", "")
            formula_node = cell.find("x:f", NS)
            value = self._cell_value(archive, cell)
            formula = formula_node.text if formula_node is not None else None
            if value or formula:
                yield WorkbookCell(sheet_name, address, value, formula)

    def _cell_value(self, archive: zipfile.ZipFile, cell: ET.Element) -> str:
        cell_type = cell.attrib.get("t")
        if cell_type == "inlineStr":
            text = cell.find("x:is/x:t", NS)
            return text.text or "" if text is not None else ""
        value_node = cell.find("x:v", NS)
        if value_node is None or value_node.text is None:
            return ""
        if cell_type == "s":
            return self._get_shared_strings(archive)[int(value_node.text)]
        return value_node.text

    def _get_shared_strings(self, archive: zipfile.ZipFile) -> list[str]:
        if self._shared_strings is not None:
            return self._shared_strings
        try:
            root = ET.fromstring(archive.read("xl/sharedStrings.xml"))
        except KeyError:
            self._shared_strings = []
            return self._shared_strings
        strings: list[str] = []
        for item in root.findall("x:si", NS):
            strings.append("".join(node.text or "" for node in item.findall(".//x:t", NS)))
        self._shared_strings = strings
        return strings
