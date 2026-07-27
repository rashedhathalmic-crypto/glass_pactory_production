from __future__ import annotations

import sys
from pathlib import Path

from PySide6.QtCore import Qt
from PySide6.QtWidgets import (
    QApplication,
    QFileDialog,
    QHBoxLayout,
    QLabel,
    QLineEdit,
    QListWidget,
    QMainWindow,
    QMessageBox,
    QPushButton,
    QTextEdit,
    QVBoxLayout,
    QWidget,
)

from .workbook_engine import WorkbookEngine


class MainWindow(QMainWindow):
    def __init__(self) -> None:
        super().__init__()
        self.setWindowTitle("Workbook NC Exporter - SKG1625 Shanlong L68")
        self.resize(1100, 760)
        self.engine: WorkbookEngine | None = None
        self.workbook_path = QLineEdit()
        self.workbook_path.setReadOnly(True)
        self.sheets = QListWidget()
        self.output = QTextEdit()
        self.output.setLineWrapMode(QTextEdit.LineWrapMode.NoWrap)
        self.formulas = QTextEdit()
        self.formulas.setReadOnly(True)
        self._build_ui()

    def _build_ui(self) -> None:
        root = QWidget(); layout = QVBoxLayout(root)
        top = QHBoxLayout()
        open_button = QPushButton("Open workbook"); open_button.clicked.connect(self.open_workbook)
        export_button = QPushButton("Export NC"); export_button.clicked.connect(self.export_nc)
        save_button = QPushButton("Save NC"); save_button.clicked.connect(self.save_nc)
        catalog_button = QPushButton("Save formula catalog"); catalog_button.clicked.connect(self.save_catalog)
        top.addWidget(QLabel("Workbook:")); top.addWidget(self.workbook_path, stretch=1)
        for button in (open_button, export_button, save_button, catalog_button):
            top.addWidget(button)
        body = QHBoxLayout()
        left = QVBoxLayout(); left.addWidget(QLabel("Worksheets")); left.addWidget(self.sheets, stretch=1)
        middle = QVBoxLayout(); middle.addWidget(QLabel("Workbook-derived NC output")); middle.addWidget(self.output, stretch=1)
        right = QVBoxLayout(); right.addWidget(QLabel("Formula/dependency catalog")); right.addWidget(self.formulas, stretch=1)
        body.addLayout(left, stretch=1); body.addLayout(middle, stretch=3); body.addLayout(right, stretch=2)
        layout.addLayout(top); layout.addLayout(body, stretch=1)
        self.setCentralWidget(root)

    def open_workbook(self) -> None:
        path, _ = QFileDialog.getOpenFileName(self, "Open workbook", "", "Excel workbooks (*.xlsx *.xlsm)")
        if not path:
            return
        try:
            self.engine = WorkbookEngine(path)
            models = self.engine.reverse_engineer()
            self.workbook_path.setText(path)
            self.sheets.clear()
            self.formulas.clear()
            for model in models:
                self.sheets.addItem(f"{model.name} ({len(model.cells)} cells, {len(model.formulas)} formulas)")
            self.formulas.setPlainText(_catalog_text(models))
            self.export_nc()
        except Exception as exc:
            QMessageBox.critical(self, "Workbook load failed", str(exc))

    def export_nc(self) -> None:
        if not self.engine:
            QMessageBox.information(self, "Open workbook", "Open the uploaded Excel workbook first.")
            return
        try:
            item = self.sheets.currentItem()
            sheet = item.text().split(" (", 1)[0] if item else None
            self.output.setPlainText(self.engine.extract_nc(sheet))
        except Exception:
            try:
                self.output.setPlainText(self.engine.extract_nc(None))
            except Exception as exc:
                QMessageBox.critical(self, "NC export failed", str(exc))

    def save_nc(self) -> None:
        if not self.output.toPlainText().strip():
            self.export_nc()
        path, _ = QFileDialog.getSaveFileName(self, "Save NC", "program.nc", "NC programs (*.nc *.cnc *.tap *.txt)")
        if path:
            Path(path).write_text(self.output.toPlainText(), encoding="utf-8")

    def save_catalog(self) -> None:
        if not self.engine:
            QMessageBox.information(self, "Open workbook", "Open the uploaded Excel workbook first.")
            return
        path, _ = QFileDialog.getSaveFileName(self, "Save formula catalog", "formula_catalog.json", "JSON (*.json)")
        if path:
            self.engine.write_formula_catalog(path)


def _catalog_text(models) -> str:
    chunks: list[str] = []
    for model in models:
        chunks.append(f"[{model.name}]")
        for cell in model.formulas:
            deps = ", ".join(cell.dependencies) or "-"
            chunks.append(f"{cell.address}: ={cell.formula} -> {cell.value} | deps: {deps}")
        chunks.append("")
    return "\n".join(chunks)


def main() -> int:
    app = QApplication(sys.argv)
    app.setAttribute(Qt.ApplicationAttribute.AA_DontUseNativeMenuBar, True)
    window = MainWindow(); window.show()
    return app.exec()


if __name__ == "__main__":
    raise SystemExit(main())
