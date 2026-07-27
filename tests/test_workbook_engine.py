from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED

from cnc_nc_generator import WorkbookEngine


def make_workbook(path: Path) -> None:
    files = {
        "xl/workbook.xml": '''<?xml version="1.0" encoding="UTF-8"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="Input" sheetId="1" r:id="rId1"/><sheet name="NC" sheetId="2" r:id="rId2"/></sheets></workbook>''',
        "xl/_rels/workbook.xml.rels": '''<?xml version="1.0" encoding="UTF-8"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="worksheet" Target="worksheets/sheet1.xml"/><Relationship Id="rId2" Type="worksheet" Target="worksheets/sheet2.xml"/></Relationships>''',
        "xl/worksheets/sheet1.xml": '''<?xml version="1.0" encoding="UTF-8"?>
<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData><row r="1"><c r="A1" t="inlineStr"><is><t>Width</t></is></c><c r="B1"><v>100</v></c></row></sheetData></worksheet>''',
        "xl/worksheets/sheet2.xml": '''<?xml version="1.0" encoding="UTF-8"?>
<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData><row r="1"><c r="A1" t="inlineStr"><is><t>%</t></is></c></row><row r="2"><c r="A2"><f>CONCATENATE("O",Input!B1)</f><v>O100</v></c></row><row r="3"><c r="A3"><f>"G01 X"&amp;Input!B1</f><v>G01 X100</v></c></row><row r="4"><c r="A4" t="inlineStr"><is><t>M30</t></is></c></row></sheetData></worksheet>''',
    }
    with ZipFile(path, "w", ZIP_DEFLATED) as archive:
        for name, content in files.items():
            archive.writestr(name, content)


def test_reverse_engineers_all_worksheets_formulas_and_dependencies(tmp_path):
    workbook = tmp_path / "program.xlsx"
    make_workbook(workbook)
    engine = WorkbookEngine(workbook)

    models = engine.reverse_engineer()
    assert [model.name for model in models] == ["Input", "NC"]
    catalog = engine.formula_catalog()
    assert catalog["NC"]["A2"]["formula"] == 'CONCATENATE("O",Input!B1)'
    assert catalog["NC"]["A2"]["dependencies"] == ("Input!B1",)


def test_extracts_nc_from_workbook_cached_values(tmp_path):
    workbook = tmp_path / "program.xlsx"
    make_workbook(workbook)

    assert WorkbookEngine(workbook).extract_nc("NC") == "%\nO100\nG01 X100\nM30\n"
