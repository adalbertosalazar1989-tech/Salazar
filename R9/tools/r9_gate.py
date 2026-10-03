from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sys
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Iterable

FORBIDDEN_SUFFIXES = {".pfx", ".p12", ".pem", ".key"}
TEXT_SUFFIXES = {
    ".py",
    ".ps1",
    ".cmd",
    ".bat",
    ".env",
    ".ini",
    ".toml",
    ".yaml",
    ".yml",
    ".json",
    ".html",
    ".js",
    ".ts",
    ".css",
    ".md",
    ".txt",
}
IGNORED_PARTS = {
    ".git",
    ".venv",
    "__pycache__",
    ".pytest_cache",
    "node_modules",
    "backups",
}


@dataclass(frozen=True)
class Finding:
    code: str
    severity: str
    title: str
    evidence: str
    remediation: str


def _iter_files(root: Path) -> Iterable[Path]:
    for path in root.rglob("*"):
        if not path.is_file():
            continue
        relative_parts = set(path.relative_to(root).parts)
        if relative_parts & IGNORED_PARTS:
            continue
        yield path


def _read_text(path: Path, limit: int = 2_000_000) -> str:
    try:
        if path.stat().st_size > limit:
            return ""
        return path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return ""


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def normalize_cnpj(value: str) -> str:
    """Normaliza CNPJ numérico legado ou alfanumérico sem descartar letras."""
    token = re.sub(r"[^A-Za-z0-9]", "", value or "").upper()
    if len(token) != 14:
        raise ValueError("CNPJ deve possuir 14 posições após normalização.")
    if not token[:12].isalnum() or not token[12:].isdigit():
        raise ValueError("As 12 primeiras posições devem ser alfanuméricas e os DVs numéricos.")
    return token


def _cnpj_char_value(char: str) -> int:
    value = ord(char) - 48
    if value < 0:
        raise ValueError("Caractere inválido no CNPJ.")
    return value


def _cnpj_digit(base: str, weights: list[int]) -> str:
    total = sum(_cnpj_char_value(char) * weight for char, weight in zip(base, weights, strict=True))
    remainder = total % 11
    return "0" if remainder < 2 else str(11 - remainder)


def validate_cnpj(value: str) -> bool:
    token = normalize_cnpj(value)
    base = token[:12]
    first = _cnpj_digit(base, [5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2])
    second = _cnpj_digit(base + first, [6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2])
    return token[-2:] == first + second


def audit(root: Path) -> dict[str, object]:
    findings: list[Finding] = []
    required = [
        "app/main.py",
        "app/config.py",
        "app/database.py",
        "app/models.py",
        "requirements.txt",
        "tests",
        "schemas",
    ]
    for relative in required:
        if not (root / relative).exists():
            findings.append(
                Finding(
                    "R9-STRUCT-001",
                    "BLOCKER",
                    "Componente obrigatório ausente",
                    relative,
                    "Restaurar o componente a partir do backup canônico antes de qualquer release.",
                )
            )

    forbidden_files = [
        str(path.relative_to(root))
        for path in _iter_files(root)
        if path.suffix.lower() in FORBIDDEN_SUFFIXES
    ]
    if forbidden_files:
        findings.append(
            Finding(
                "R9-SECRET-001",
                "BLOCKER",
                "Certificado ou chave privada dentro do projeto",
                ", ".join(forbidden_files[:20]),
                "Remover do repositório, ZIP, backup comum e árvore de testes; usar sessão/cofre controlado.",
            )
        )

    app_dir = root / "app"
    python_files = list(app_dir.rglob("*.py")) if app_dir.exists() else []
    bases: list[str] = []
    for path in python_files:
        text = _read_text(path)
        if "declarative_base(" in text or "DeclarativeBase" in text:
            bases.append(str(path.relative_to(root)))
    if len(bases) > 1:
        findings.append(
            Finding(
                "R9-DATA-001",
                "HIGH",
                "Mais de uma definição de base ORM detectada",
                ", ".join(bases),
                "Consolidar a base declarativa e garantir uma única fonte de metadados/migrations.",
            )
        )

    extension = root / "app" / "v2_extensions.py"
    if extension.exists():
        extension_text = _read_text(extension)
        if "sqlite3" in extension_text and "saeng_v2_extensions.db" in extension_text:
            findings.append(
                Finding(
                    "R9-DATA-002",
                    "BLOCKER",
                    "Banco paralelo da extensão V2",
                    "app/v2_extensions.py usa saeng_v2_extensions.db",
                    "Migrar tabelas para o banco canônico, com migration e chaves estrangeiras; não manter domínio paralelo.",
                )
            )
        if re.search(r"re\.sub\(r?[\"']\\D", extension_text):
            findings.append(
                Finding(
                    "R9-CNPJ-001",
                    "BLOCKER",
                    "Normalização remove letras do CNPJ",
                    "app/v2_extensions.py",
                    "Adotar normalização alfanumérica e validar os dois dígitos verificadores conforme especificação RFB.",
                )
            )

    if not (root / "alembic.ini").exists() or not (root / "alembic").is_dir():
        findings.append(
            Finding(
                "R9-MIG-001",
                "BLOCKER",
                "Migrações Alembic ausentes",
                "alembic.ini/alembic não encontrados",
                "Criar baseline do banco existente, aplicar stamp controlado e migrations incrementais testadas em cópia.",
            )
        )

    env_path = root / ".env"
    if env_path.exists():
        env_text = _read_text(env_path)
        secret_keys = []
        for line in env_text.splitlines():
            stripped = line.strip()
            if not stripped or stripped.startswith("#") or "=" not in stripped:
                continue
            key, value = stripped.split("=", 1)
            if re.search(r"(?i)(password|passwd|secret|token|admin.*pass|pfx.*pass)", key) and value.strip():
                secret_keys.append(key.strip())
        if secret_keys:
            findings.append(
                Finding(
                    "R9-SECRET-002",
                    "BLOCKER",
                    "Segredo persistido no .env",
                    ", ".join(sorted(set(secret_keys))),
                    "Substituir por hash/cofre/DPAPI conforme o tipo; nunca registrar ou empacotar o valor.",
                )
            )

    source_texts: list[tuple[Path, str]] = []
    for path in _iter_files(root):
        if path.suffix.lower() in TEXT_SUFFIXES:
            text = _read_text(path)
            if text:
                source_texts.append((path, text))

    patterns = [
        (r"TRANSMISSION_MODE\s*=\s*[\"']?PRODUCTION", "R9-PROD-001", "Produção definida diretamente em código"),
        (r"ALLOW_PRODUCTION_TRANSMISSION\s*=\s*[\"']?true", "R9-PROD-002", "Produção habilitada por padrão"),
        (r"ACEITO_MOCK", "R9-STATE-001", "Estado MOCK presente no código operacional"),
    ]
    for pattern, code, title in patterns:
        matched = [str(path.relative_to(root)) for path, text in source_texts if re.search(pattern, text, flags=re.IGNORECASE)]
        if matched:
            severity = "BLOCKER" if code.startswith("R9-PROD") else "MEDIUM"
            findings.append(
                Finding(
                    code,
                    severity,
                    title,
                    ", ".join(matched[:20]),
                    "Separar configuração por ambiente e impedir aparência jurídica para simulação.",
                )
            )

    xsd_files = list((root / "schemas").rglob("*.xsd")) if (root / "schemas").exists() else []
    if not xsd_files:
        findings.append(
            Finding(
                "R9-XSD-001",
                "BLOCKER",
                "Nenhum XSD encontrado",
                "schemas/",
                "Instalar o pacote XSD oficial versionado e registrar manifesto SHA-256.",
            )
        )

    inventory = []
    for path in _iter_files(root):
        try:
            inventory.append(
                {
                    "path": str(path.relative_to(root)),
                    "size": path.stat().st_size,
                    "sha256": _sha256(path),
                }
            )
        except OSError:
            continue

    counts = {
        "blocker": sum(item.severity == "BLOCKER" for item in findings),
        "high": sum(item.severity == "HIGH" for item in findings),
        "medium": sum(item.severity == "MEDIUM" for item in findings),
        "xsd": len(xsd_files),
        "files": len(inventory),
    }
    return {
        "root": str(root),
        "status": "BLOCKED" if counts["blocker"] or counts["high"] else "LOCAL_GATE_READY",
        "counts": counts,
        "findings": [asdict(item) for item in findings],
        "inventory": inventory,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Gate técnico R9 do SAENG Software SST")
    parser.add_argument("--root", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--strict", action="store_true")
    parser.add_argument("--validate-cnpj")
    args = parser.parse_args()

    if args.validate_cnpj is not None:
        try:
            valid = validate_cnpj(args.validate_cnpj)
        except ValueError as exc:
            print(json.dumps({"valid": False, "error": str(exc)}, ensure_ascii=False))
            return 2
        print(json.dumps({"valid": valid, "normalized": normalize_cnpj(args.validate_cnpj)}, ensure_ascii=False))
        return 0 if valid else 2

    root = args.root.resolve()
    report = audit(root)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps({"status": report["status"], "counts": report["counts"]}, ensure_ascii=False))
    if args.strict and report["status"] != "LOCAL_GATE_READY":
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
