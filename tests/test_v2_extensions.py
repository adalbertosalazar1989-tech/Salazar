from __future__ import annotations

import sqlite3
from pathlib import Path

from openpyxl import Workbook

import v2_extensions as v2


def configure_root(tmp_path: Path) -> None:
    v2.ROOT_DIR = tmp_path
    v2.STORAGE_DIR = tmp_path / "storage"
    v2.REFERENCE_DIR = tmp_path / "imports" / "references"
    v2.DOCS_DIR = tmp_path / "docs"
    v2.DB_PATH = v2.STORAGE_DIR / "saeng_v2_extensions.db"
    for directory in (v2.STORAGE_DIR, v2.REFERENCE_DIR, v2.DOCS_DIR):
        directory.mkdir(parents=True, exist_ok=True)
    v2.init_database()


def make_workbook(path: Path) -> None:
    workbook = Workbook()
    sheet = workbook.active
    sheet.title = "Riscos Quimicos"
    sheet.append(["Empresa", "Produto", "Substancia", "CAS", "Tabela 24", "Tabela 27"])
    sheet.append(["Empresa Teste", "Thinner", "Tolueno", "108-88-3", "01.17.001", "0295"])
    second = workbook.create_sheet("ASO")
    second.append(["Trabalhador", "Tipo ASO", "Exame", "Codigo Tabela 27"])
    workbook.save(path)


def test_workbook_inspection_and_classification(tmp_path: Path):
    path = tmp_path / "5. Planilha Mestra Riscos Ocupacionais SST - 2026.xlsx"
    make_workbook(path)
    info = v2.inspect_workbook(path)
    assert info["sheet_count"] == 2
    assert info["sheets"][0]["name"] == "Riscos Quimicos"
    assert "Substancia" in info["sheets"][0]["headers"]
    assert v2.classify_file(path) == "PLANILHA_RISCOS"
    assert v2.classify_file(tmp_path / "6. Controle ASO.xlsx") == "PLANILHA_ASO"


def test_reference_scan_indexes_xlsx_and_ignores_pfx(tmp_path: Path):
    configure_root(tmp_path)
    workbook_path = v2.REFERENCE_DIR / "Planilha Mestra Riscos.xlsx"
    make_workbook(workbook_path)
    (v2.REFERENCE_DIR / "certificado.pfx").write_bytes(b"segredo-nao-deve-ser-lido")

    result = v2.scan_reference_folder()
    assert result["processed"] == 1
    assert result["ignored"] == 1
    assert not result["errors"]

    with sqlite3.connect(v2.DB_PATH) as conn:
        assert conn.execute("SELECT COUNT(*) FROM source_files").fetchone()[0] == 1
        assert conn.execute("SELECT COUNT(*) FROM workbook_sheets").fetchone()[0] == 2


def test_project_audit_detects_forbidden_secret(tmp_path: Path):
    configure_root(tmp_path)
    required_files = [
        "app/main.py", "app/config.py", "app/database.py", "app/models.py",
        "requirements.txt", "START_SAENG_SST.bat", "EXECUTAR_TESTES.bat",
    ]
    required_dirs = [
        "app/templates", "app/static", "app/esocial", "schemas", "storage/documents",
        "storage/xml", "storage/reports", "imports/references", "docs", "tests",
    ]
    for relative in required_files:
        path = tmp_path / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text("ok", encoding="utf-8")
    for relative in required_dirs:
        path = tmp_path / relative
        path.mkdir(parents=True, exist_ok=True)
        (path / ".keep").write_text("ok", encoding="utf-8")

    clean = v2.audit_project_tree()
    assert clean["required_files_missing"] == []
    assert clean["required_directories_missing"] == []
    assert clean["forbidden_secret_files"] == []

    (tmp_path / "certificado.p12").write_bytes(b"nao-empacotar")
    blocked = v2.audit_project_tree()
    assert "certificado.p12" in blocked["forbidden_secret_files"]
    assert blocked["ok"] is False
