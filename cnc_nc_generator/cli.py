from __future__ import annotations

import argparse
from pathlib import Path

from .workbook_engine import WorkbookEngine


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Export NC output directly from the Excel workbook cache.")
    parser.add_argument("workbook", type=Path, help="Source .xlsx/.xlsm workbook")
    parser.add_argument("--sheet", help="Worksheet containing the NC output; defaults to best detected sheet")
    parser.add_argument("--output", type=Path, help="Write NC output to this file")
    parser.add_argument("--catalog", type=Path, help="Write a JSON catalog of every worksheet formula/dependency")
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    engine = WorkbookEngine(args.workbook)
    if args.catalog:
        engine.write_formula_catalog(args.catalog)
    nc = engine.extract_nc(args.sheet)
    if args.output:
        args.output.write_text(nc, encoding="utf-8")
    else:
        print(nc, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
