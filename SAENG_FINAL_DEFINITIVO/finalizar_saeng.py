from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
import re
import secrets
import shutil
import subprocess
import sys
import zipfile
from pathlib import Path

SKIP_DIRS = {".venv", "__pycache__", ".pytest_cache", ".git", "node_modules"}
SKIP_PREFIXES = ("backup_", "SAENG_Software_SST_BACKUP")
FORBIDDEN_SUFFIXES = {".pfx", ".p12", ".pem", ".key"}
PORT = 8765


def write_text(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8", newline="\n")


def run(command: list[str], cwd: Path | None = None, log_file: Path | None = None) -> None:
    if log_file is None:
        completed = subprocess.run(command, cwd=cwd, check=False)
    else:
        log_file.parent.mkdir(parents=True, exist_ok=True)
        with log_file.open("a", encoding="utf-8", errors="replace") as handle:
            handle.write("\n$ " + " ".join(map(str, command)) + "\n")
            completed = subprocess.run(
                command,
                cwd=cwd,
                stdout=handle,
                stderr=subprocess.STDOUT,
                text=True,
                check=False,
            )
    if completed.returncode != 0:
        raise RuntimeError(
            f"Comando falhou com código {completed.returncode}: {' '.join(map(str, command))}"
        )


def stop_saeng_server(source: Path, target: Path) -> None:
    source_text = str(source).replace("'", "''")
    target_text = str(target).replace("'", "''")
    script = f"""
$ErrorActionPreference = 'Stop'
$connections = @(Get-NetTCPConnection -LocalPort {PORT} -State Listen -ErrorAction SilentlyContinue)
foreach ($connection in $connections) {{
    $pidValue = [int]$connection.OwningProcess
    $processInfo = Get-CimInstance Win32_Process -Filter ("ProcessId=" + $pidValue) -ErrorAction SilentlyContinue
    $commandLine = if ($processInfo) {{ [string]$processInfo.CommandLine }} else {{ '' }}
    $executable = if ($processInfo) {{ [string]$processInfo.ExecutablePath }} else {{ '' }}
    $isSaeng = (
        $commandLine -like '*{source_text}*' -or
        $commandLine -like '*{target_text}*' -or
        $commandLine -match 'uvicorn|run_saeng_sst|SAENG_Software_SST'
    )
    if (-not $isSaeng) {{
        throw "A porta {PORT} está ocupada por outro programa. PID: $pidValue"
    }}
    Stop-Process -Id $pidValue -Force
}}
"""
    run(
        [
            "powershell.exe",
            "-NoProfile",
            "-NonInteractive",
            "-ExecutionPolicy",
            "Bypass",
            "-Command",
            script,
        ]
    )


def ignore_copy(_directory: str, names: list[str]) -> set[str]:
    ignored: set[str] = set()
    for name in names:
        lower = name.lower()
        if (
            name in SKIP_DIRS
            or name.startswith(SKIP_PREFIXES)
            or lower.endswith((".pyc", ".pyo", ".zip"))
        ):
            ignored.add(name)
    return ignored


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8-sig")


def find_requirements(root: Path) -> Path:
    requirements_txt = root / "requirements.txt"
    if requirements_txt.exists():
        return requirements_txt
    legacy = root / "requirements"
    if legacy.exists():
        write_text(requirements_txt, read_text(legacy))
        return requirements_txt
    raise RuntimeError("Arquivo requirements.txt não encontrado.")


def patch_require_login(text: str) -> str:
    replacement = (
        "def require_login(request: Request) -> str:\n"
        "    \"\"\"Exige sessão autenticada. O A1 é exigido somente em operações oficiais.\"\"\"\n"
        "    user = current_user(request)\n"
        "    if not user:\n"
        "        raise HTTPException(status_code=401)\n"
        "    return user\n"
    )
    pattern = re.compile(
        r"def require_login\(request: Request\) -> str:\s*\n"
        r"(?:    .*\n)+?(?=\n\ndef add_audit)",
        re.MULTILINE,
    )
    if pattern.search(text):
        return pattern.sub(replacement, text, count=1)
    old = (
        "def require_login(request: Request) -> str:\n"
        "    user = current_user(request)\n"
        "    if not user:\n"
        "        raise HTTPException(status_code=401)\n"
        "    if settings.certificate_login_required and not current_certificate(request):\n"
        "        raise HTTPException(status_code=401)\n"
        "    return user\n"
    )
    return text.replace(old, replacement)


WINDOWS_CERTIFICATE_MODULE = r'''from __future__ import annotations

import base64
import json
import os
import re
import secrets
import subprocess
from typing import Any

_THUMBPRINT = re.compile(r"^[A-Fa-f0-9]{40}$")


class WindowsCertificateError(RuntimeError):
    pass


def _run_powershell(script: str, env: dict[str, str] | None = None, timeout: int = 45) -> str:
    completed = subprocess.run(
        [
            "powershell.exe",
            "-NoLogo",
            "-NoProfile",
            "-NonInteractive",
            "-ExecutionPolicy",
            "Bypass",
            "-Command",
            "-",
        ],
        input=script,
        text=True,
        capture_output=True,
        encoding="utf-8",
        errors="replace",
        env=env,
        timeout=timeout,
        creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0),
        check=False,
    )
    if completed.returncode != 0:
        detail = (completed.stderr or completed.stdout or "Falha no armazenamento de certificados.").strip()
        raise WindowsCertificateError(detail[:2000])
    return completed.stdout.strip()


def list_installed_certificates() -> list[dict[str, Any]]:
    if os.name != "nt":
        return []
    script = r'''
$ErrorActionPreference = 'Stop'
$now = Get-Date
$result = foreach ($cert in Get-ChildItem Cert:\CurrentUser\My) {
    if (-not $cert.HasPrivateKey) { continue }
    if ($cert.NotBefore -gt $now -or $cert.NotAfter -le $now) { continue }
    $exportable = $false
    try {
        $pwd = [Guid]::NewGuid().ToString('N')
        $bytes = $cert.Export(
            [System.Security.Cryptography.X509Certificates.X509ContentType]::Pfx,
            $pwd
        )
        $exportable = ($bytes.Length -gt 0)
        if ($bytes) { [Array]::Clear($bytes, 0, $bytes.Length) }
    }
    catch {
        $exportable = $false
    }
    [PSCustomObject]@{
        thumbprint = $cert.Thumbprint
        name = $cert.GetNameInfo(
            [System.Security.Cryptography.X509Certificates.X509NameType]::SimpleName,
            $false
        )
        subject = $cert.Subject
        issuer = $cert.Issuer
        not_before = $cert.NotBefore.ToString('o')
        not_after = $cert.NotAfter.ToString('o')
        exportable = $exportable
    }
}
@($result) | ConvertTo-Json -Depth 4 -Compress
'''
    raw = _run_powershell(script)
    if not raw:
        return []
    data = json.loads(raw)
    if isinstance(data, dict):
        data = [data]
    result: list[dict[str, Any]] = []
    for item in data:
        if not isinstance(item, dict) or not item.get("exportable"):
            continue
        thumbprint = str(item.get("thumbprint", "")).replace(" ", "").upper()
        if not _THUMBPRINT.fullmatch(thumbprint):
            continue
        item["thumbprint"] = thumbprint
        result.append(item)
    result.sort(key=lambda item: str(item.get("not_after", "")), reverse=True)
    return result


def export_installed_certificate(thumbprint: str) -> tuple[bytes, str, dict[str, Any]]:
    if os.name != "nt":
        raise WindowsCertificateError("Recurso disponível somente no Windows.")
    normalized = thumbprint.replace(" ", "").upper()
    if not _THUMBPRINT.fullmatch(normalized):
        raise WindowsCertificateError("Thumbprint inválido.")
    available = {item["thumbprint"]: item for item in list_installed_certificates()}
    if normalized not in available:
        raise WindowsCertificateError(
            "Certificado válido, exportável e com chave privada não encontrado."
        )
    ephemeral_password = secrets.token_urlsafe(32)
    env = os.environ.copy()
    env["SAENG_CERT_THUMBPRINT"] = normalized
    env["SAENG_EPHEMERAL_PASSWORD"] = ephemeral_password
    script = r'''
$ErrorActionPreference = 'Stop'
$thumbprint = $env:SAENG_CERT_THUMBPRINT
$password = $env:SAENG_EPHEMERAL_PASSWORD
$cert = Get-Item ("Cert:\CurrentUser\My\" + $thumbprint)
if (-not $cert.HasPrivateKey) { throw 'Certificado sem chave privada.' }
if ($cert.NotBefore -gt (Get-Date) -or $cert.NotAfter -le (Get-Date)) {
    throw 'Certificado fora da validade.'
}
$bytes = $cert.Export(
    [System.Security.Cryptography.X509Certificates.X509ContentType]::Pfx,
    $password
)
try {
    [Console]::Out.Write([Convert]::ToBase64String($bytes))
}
finally {
    if ($bytes) { [Array]::Clear($bytes, 0, $bytes.Length) }
}
'''
    encoded = _run_powershell(script, env=env)
    try:
        pfx_bytes = base64.b64decode(encoded, validate=True)
    except Exception as exc:
        raise WindowsCertificateError(
            "O Windows não devolveu um PFX válido em memória."
        ) from exc
    if not pfx_bytes:
        raise WindowsCertificateError("Exportação em memória retornou conteúdo vazio.")
    return pfx_bytes, ephemeral_password, available[normalized]
'''


WINDOWS_ENDPOINTS = r'''

# SAENG_WINDOWS_CERTIFICATE_FINAL
@app.get("/api/windows-certificates")
def windows_certificates_api(request: Request):
    if not request.client or request.client.host not in {"127.0.0.1", "::1", "testclient"}:
        raise HTTPException(status_code=403)
    try:
        return {"certificates": list_installed_certificates()}
    except WindowsCertificateError as exc:
        return {"certificates": [], "error": str(exc)}


@app.post("/login/windows-certificate")
async def windows_certificate_login(
    request: Request,
    thumbprint: Annotated[str, Form()],
    db: Session = Depends(get_db),
):
    if not request.client or request.client.host not in {"127.0.0.1", "::1", "testclient"}:
        raise HTTPException(status_code=403)
    import io
    from starlette.datastructures import UploadFile as StarletteUploadFile
    try:
        pfx_bytes, ephemeral_password, _metadata = export_installed_certificate(thumbprint)
        upload = StarletteUploadFile(
            file=io.BytesIO(pfx_bytes),
            filename="windows-store.pfx",
        )
        try:
            return await certificate_login(
                request,
                ephemeral_password,
                upload,
                db,
            )
        finally:
            await upload.close()
    except WindowsCertificateError as exc:
        return templates.TemplateResponse(
            request,
            "login.html",
            {"request": request, "settings": settings, "error": str(exc)},
            status_code=400,
        )
'''


WINDOWS_CERTIFICATE_JS = r'''"use strict";
(function () {
  const panel = document.getElementById("saeng-windows-certificate");
  const select = document.getElementById("saeng-windows-thumbprint");
  const status = document.getElementById("saeng-windows-status");
  if (!panel || !select || !status) return;

  fetch("/api/windows-certificates", {
    credentials: "same-origin",
    cache: "no-store"
  })
    .then((response) => {
      if (!response.ok) throw new Error("Consulta indisponível");
      return response.json();
    })
    .then((payload) => {
      const certificates = Array.isArray(payload.certificates)
        ? payload.certificates
        : [];
      if (!certificates.length) {
        status.textContent = "Nenhum certificado A1 exportável e válido foi localizado. Use o PFX/P12 manual.";
        return;
      }
      select.replaceChildren();
      certificates.forEach((certificate) => {
        const option = document.createElement("option");
        option.value = certificate.thumbprint;
        const expires = certificate.not_after
          ? new Date(certificate.not_after).toLocaleDateString("pt-BR")
          : "";
        option.textContent = `${certificate.name || certificate.subject} — válido até ${expires}`;
        select.appendChild(option);
      });
      panel.hidden = false;
      status.textContent = "Certificado instalado no Windows localizado. Basta autorizar a entrada.";
    })
    .catch(() => {
      status.textContent = "Não foi possível consultar o Windows. Use o PFX/P12 manual.";
    });
})();
'''


DEFINITIVE_CSS = r'''
/* SAENG FINAL — complemento idempotente */
.saeng-windows-certificate {
  margin: 0 0 16px;
  padding: 16px;
  border: 1px solid rgba(193, 139, 29, .30);
  border-radius: 16px;
  background: linear-gradient(180deg, #fffdf8, #fff);
}
.saeng-windows-certificate[hidden] { display: none !important; }
.saeng-windows-certificate label { display: block; margin-bottom: 8px; font-weight: 750; }
.saeng-windows-certificate select {
  width: 100%;
  min-height: 48px;
  padding: 0 12px;
  border: 1px solid #d7dee8;
  border-radius: 12px;
  background: #fff;
}
.saeng-windows-certificate button {
  width: 100%;
  min-height: 50px;
  margin-top: 12px;
  border: 0;
  border-radius: 13px;
  font-weight: 800;
  color: #071a31;
  background: linear-gradient(135deg, #efc24a, #cf8f08);
  cursor: pointer;
}
.saeng-windows-status { margin: 8px 0 0; font-size: .84rem; color: #607089; }
.saeng-manual-certificate { margin-top: 12px; padding-top: 12px; border-top: 1px solid #e5e9ef; }
.saeng-manual-certificate summary { cursor: pointer; font-weight: 750; color: #24364d; }
.saeng-brand-logo { display: block; width: 100%; height: 100%; object-fit: contain; background: transparent; }
@media (min-width: 921px) {
  html, body.login-body { min-height: 100%; overflow: hidden; }
}
'''


LAUNCHER_TEMPLATE = r'''from __future__ import annotations

import ctypes
import socket
import subprocess
import sys
import time
import urllib.request
import webbrowser
from pathlib import Path

ROOT = Path(r"__ROOT__")
PORT = 8765
BASE_URL = f"http://127.0.0.1:{PORT}/"
HEALTH_URL = f"http://127.0.0.1:{PORT}/login"
LOG_PATH = ROOT / "storage" / "launcher_server.log"
FLAGS = (
    getattr(subprocess, "CREATE_NO_WINDOW", 0x08000000)
    | getattr(subprocess, "DETACHED_PROCESS", 0x00000008)
    | getattr(subprocess, "CREATE_NEW_PROCESS_GROUP", 0x00000200)
)


def ready(timeout: float = 1.2) -> bool:
    try:
        with urllib.request.urlopen(HEALTH_URL, timeout=timeout) as response:
            return response.status == 200
    except Exception:
        return False


def port_open() -> bool:
    try:
        with socket.create_connection(("127.0.0.1", PORT), timeout=.3):
            return True
    except OSError:
        return False


def alert(text: str) -> None:
    ctypes.windll.user32.MessageBoxW(None, text, "SAENG Software SST", 0x10)


def main() -> None:
    mutex = ctypes.windll.kernel32.CreateMutexW(
        None,
        False,
        "Local\\SAENG_SST_FINAL_LAUNCHER",
    )
    try:
        if ready():
            webbrowser.open(BASE_URL, new=1)
            return
        if port_open():
            alert("A porta 8765 está sendo usada por outro programa.")
            return
        LOG_PATH.parent.mkdir(parents=True, exist_ok=True)
        log_handle = LOG_PATH.open("a", encoding="utf-8", buffering=1)
        subprocess.Popen(
            [
                sys.executable,
                "-m",
                "uvicorn",
                "app.main:app",
                "--host",
                "127.0.0.1",
                "--port",
                str(PORT),
                "--log-level",
                "warning",
                "--no-access-log",
            ],
            cwd=str(ROOT),
            stdin=subprocess.DEVNULL,
            stdout=log_handle,
            stderr=log_handle,
            creationflags=FLAGS,
            close_fds=True,
        )
        for _ in range(80):
            if ready():
                webbrowser.open(BASE_URL, new=1)
                return
            time.sleep(.4)
        alert(f"O SAENG não iniciou. Consulte o log:\n{LOG_PATH}")
    finally:
        if mutex:
            ctypes.windll.kernel32.ReleaseMutex(mutex)
            ctypes.windll.kernel32.CloseHandle(mutex)


if __name__ == "__main__":
    main()
'''


def patch_main(root: Path) -> None:
    path = root / "app" / "main.py"
    text = read_text(path)
    text = patch_require_login(text)
    import_line = (
        "from .windows_certificate import WindowsCertificateError, "
        "export_installed_certificate, list_installed_certificates"
    )
    if import_line not in text:
        anchor = "from .session_vault import certificate_vault"
        if anchor not in text:
            raise RuntimeError("Importação session_vault não localizada em main.py.")
        text = text.replace(anchor, anchor + "\n" + import_line, 1)
    if "SAENG_WINDOWS_CERTIFICATE_FINAL" not in text:
        text = text.rstrip() + WINDOWS_ENDPOINTS + "\n"
    write_text(path, text)


def extract_form(text: str, action: str) -> tuple[str, int, int]:
    expression = re.compile(
        rf'<form\b(?=[^>]*action=["\']{re.escape(action)}["\'])[^>]*>'
        rf'[\s\S]*?</form>',
        re.IGNORECASE,
    )
    match = expression.search(text)
    if not match:
        raise RuntimeError(f"Formulário {action} não localizado em login.html.")
    return match.group(0), match.start(), match.end()


def patch_login(root: Path) -> None:
    path = root / "app" / "templates" / "login.html"
    text = read_text(path)
    text = re.sub(
        r"(?is)<!-- SAENG_WINDOWS_CERT_START -->.*?<!-- SAENG_WINDOWS_CERT_END -->",
        "",
        text,
    )
    text = re.sub(
        r"(?is)<!-- SAENG_SPLASH_START -->.*?<!-- SAENG_SPLASH_END -->",
        "",
        text,
    )
    text = re.sub(
        r"(?is)<img\b[^>]*src=[\"'][^\"']*(?:splash-saeng|abertura-saeng)\.png[^\"']*[\"'][^>]*>",
        "",
        text,
    )
    form, start, end = extract_form(text, "/login/certificate")
    block = (
        '<!-- SAENG_WINDOWS_CERT_START -->\n'
        '<section id="saeng-windows-certificate" class="saeng-windows-certificate" hidden>\n'
        '  <form action="/login/windows-certificate" method="post">\n'
        '    <label for="saeng-windows-thumbprint">Certificado instalado no Windows</label>\n'
        '    <select id="saeng-windows-thumbprint" name="thumbprint" required></select>\n'
        '    <button type="submit">Entrar com certificado instalado</button>\n'
        '    <p id="saeng-windows-status" class="saeng-windows-status">Consultando certificados...</p>\n'
        '  </form>\n'
        '</section>\n'
        '<details class="saeng-manual-certificate">\n'
        '  <summary>Usar arquivo PFX/P12 manualmente</summary>\n'
        + form
        + '\n</details>\n'
        '<!-- SAENG_WINDOWS_CERT_END -->'
    )
    text = text[:start] + block + text[end:]
    css_link = '<link rel="stylesheet" href="/static/login-definitive.css?v=1.0.0">'
    js_link = '<script src="/static/login-windows-certificate.js?v=1.0.0" defer></script>'
    favicon = '<link rel="icon" href="/static/favicon.ico">'
    if css_link not in text:
        text = text.replace(
            "</head>",
            f"  {favicon}\n  {css_link}\n  {js_link}\n</head>",
            1,
        )
    write_text(path, text)


def patch_branding(root: Path) -> None:
    templates = root / "app" / "templates"
    for path in templates.rglob("*.html"):
        text = read_text(path)
        original = text
        text = re.sub(
            r'<div\s+class=["\'](?:login-logo|brand-mark)["\']>\s*SS\s*</div>',
            '<div class="brand-mark"><img class="saeng-brand-logo" '
            'src="/static/logo_saeng_transparente.png" alt="SAENG"></div>',
            text,
            flags=re.IGNORECASE,
        )
        if "/static/favicon.ico" not in text and "</head>" in text:
            text = text.replace(
                "</head>",
                '  <link rel="icon" href="/static/favicon.ico">\n</head>',
                1,
            )
        if text != original:
            write_text(path, text)


def install_assets(root: Path) -> None:
    app = root / "app"
    static = app / "static"
    static.mkdir(parents=True, exist_ok=True)
    write_text(app / "windows_certificate.py", WINDOWS_CERTIFICATE_MODULE)
    write_text(static / "login-windows-certificate.js", WINDOWS_CERTIFICATE_JS)
    write_text(static / "login-definitive.css", DEFINITIVE_CSS)
    icon_candidates = [
        static / "saeng_desktop_icon_r6.ico",
        static / "saeng_software_sst.ico",
        static / "saeng.ico",
    ]
    icon = next((candidate for candidate in icon_candidates if candidate.exists()), None)
    if icon:
        (static / "favicon.ico").write_bytes(icon.read_bytes())


def ensure_directories(root: Path) -> None:
    required = [
        "docs",
        "imports",
        "schemas",
        "scripts",
        "storage",
        "storage/uploads",
        "storage/reports",
        "storage/documents",
        "tests",
        "launcher",
    ]
    for relative in required:
        directory = root / relative
        directory.mkdir(parents=True, exist_ok=True)
        if not any(directory.iterdir()):
            write_text(
                directory / ".keep",
                "Diretório operacional requerido pelo SAENG Software SST.\n",
            )


def scan_forbidden(root: Path) -> None:
    forbidden: list[str] = []
    for path in root.rglob("*"):
        if (
            path.is_file()
            and path.suffix.lower() in FORBIDDEN_SUFFIXES
            and ".venv" not in path.parts
        ):
            forbidden.append(str(path))
    if forbidden:
        raise RuntimeError(
            "Certificados ou chaves não podem permanecer na pasta do software: "
            + "; ".join(forbidden)
        )


def create_manifest(root: Path) -> int:
    lines: list[str] = []
    manifest_path = root / "MANIFEST_SHA256_FINAL.txt"
    for path in sorted(root.rglob("*")):
        if (
            not path.is_file()
            or ".venv" in path.parts
            or path == manifest_path
        ):
            continue
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        lines.append(f"{digest}  {path.relative_to(root)}")
    write_text(manifest_path, "\n".join(lines) + "\n")
    return len(lines)


def create_shortcut(root: Path) -> Path:
    launcher_dir = root / "launcher"
    launcher_dir.mkdir(parents=True, exist_ok=True)
    launcher = launcher_dir / "SAENG_Software_SST.pyw"
    launcher_text = LAUNCHER_TEMPLATE.replace(
        "__ROOT__",
        str(root).replace("\\", "\\\\"),
    )
    write_text(launcher, launcher_text)
    static = root / "app" / "static"
    icon = next(
        (
            candidate
            for candidate in [
                static / "saeng_desktop_icon_r6.ico",
                static / "saeng_software_sst.ico",
                static / "favicon.ico",
            ]
            if candidate.exists()
        ),
        None,
    )
    if icon is None:
        raise RuntimeError("Ícone ICO do SAENG não encontrado.")
    desktop = Path(os.environ.get("USERPROFILE", str(Path.home()))) / "Desktop"
    shortcut = desktop / "SAENG Software SST.lnk"
    pythonw = root / ".venv" / "Scripts" / "pythonw.exe"
    script = (
        "$shell = New-Object -ComObject WScript.Shell;"
        f"$shortcut = $shell.CreateShortcut('{shortcut}');"
        f"$shortcut.TargetPath = '{pythonw}';"
        f"$shortcut.Arguments = '\"{launcher}\"';"
        f"$shortcut.WorkingDirectory = '{root}';"
        f"$shortcut.IconLocation = '{icon},0';"
        "$shortcut.Description = 'SAENG Software SST';"
        "$shortcut.Save();"
        f"Unblock-File '{shortcut}' -ErrorAction SilentlyContinue"
    )
    run(
        [
            "powershell.exe",
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-Command",
            script,
        ]
    )
    if not shortcut.exists():
        raise RuntimeError("Atalho da Área de Trabalho não foi criado.")
    return shortcut


def create_code_zip(root: Path, destination: Path) -> None:
    if destination.exists():
        destination.unlink()
    with zipfile.ZipFile(
        destination,
        "w",
        compression=zipfile.ZIP_DEFLATED,
        compresslevel=9,
    ) as archive:
        for path in root.rglob("*"):
            if not path.is_file():
                continue
            relative = path.relative_to(root)
            if (
                ".venv" in relative.parts
                or path.name == ".env"
                or path.suffix.lower() in FORBIDDEN_SUFFIXES
                or path.name.lower().endswith((".db", ".sqlite", ".sqlite3"))
                or "uploads" in relative.parts
                or "logs" in relative.parts
            ):
                continue
            archive.write(path, Path(root.name) / relative)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", required=True)
    parser.add_argument("--target", required=True)
    parser.add_argument("--start", action="store_true")
    args = parser.parse_args()

    if os.name != "nt":
        raise RuntimeError("Este finalizador deve ser executado no Windows 10 ou 11.")

    source = Path(args.source)
    target = Path(args.target)
    timestamp = dt.datetime.now().strftime("%Y%m%d_%H%M%S")
    backup = Path(f"C:\\SAENG_Software_SST_BACKUP_FINAL_{timestamp}")
    staging = Path(str(target) + ".__staging__")
    previous: Path | None = None
    log_file = Path(os.environ.get("TEMP", r"C:\Windows\Temp")) / f"SAENG_FINAL_{timestamp}.log"

    if not (source / "app" / "main.py").exists():
        raise RuntimeError(f"Pasta de origem inválida: {source}")

    print("======================================================")
    print(" SAENG SOFTWARE SST — CONSTRUÇÃO FINAL CONTROLADA")
    print("======================================================")

    try:
        stop_saeng_server(source, target)

        print(f"Backup integral: {backup}")
        shutil.copytree(source, backup, ignore=ignore_copy)

        if staging.exists():
            shutil.rmtree(staging)
        print(f"Criando cópia transacional: {staging}")
        shutil.copytree(source, staging, ignore=ignore_copy)

        install_assets(staging)
        patch_main(staging)
        patch_login(staging)
        patch_branding(staging)
        ensure_directories(staging)
        scan_forbidden(staging)

        requirements = find_requirements(staging)
        python_command = ["py", "-3.11"] if shutil.which("py") else [sys.executable]
        run(
            python_command + ["-m", "venv", str(staging / ".venv")],
            log_file=log_file,
        )
        python = staging / ".venv" / "Scripts" / "python.exe"
        run(
            [str(python), "-m", "pip", "install", "--upgrade", "pip"],
            log_file=log_file,
        )
        run(
            [str(python), "-m", "pip", "install", "-r", str(requirements)],
            log_file=log_file,
        )
        run(
            [str(python), "-m", "compileall", "-q", "app", "tests", "launcher"],
            cwd=staging,
            log_file=log_file,
        )
        run(
            [str(python), "-m", "pytest", "-q"],
            cwd=staging,
            log_file=log_file,
        )

        manifest_count = create_manifest(staging)
        status = {
            "version": "1.0.0-RC1",
            "installed_at": dt.datetime.now().isoformat(),
            "source": str(source),
            "target": str(target),
            "backup": str(backup),
            "manifest_files": manifest_count,
            "local_tests": "APPROVED",
            "production_status": (
                "PENDING_RESTRICTED_ENVIRONMENT_AND_OFFICIAL_RECEIPT"
            ),
        }
        write_text(
            staging / "FINAL_STATUS.json",
            json.dumps(status, ensure_ascii=False, indent=2),
        )

        if target.exists():
            previous = Path(str(target) + f"_ANTERIOR_{timestamp}")
            target.rename(previous)
        staging.rename(target)

        shortcut = create_shortcut(target)
        code_zip = Path(r"C:\SAENG_Software_SST_FINAL_CODIGO.zip")
        create_code_zip(target, code_zip)

        report = target / "docs" / "RELATORIO_INSTALACAO_FINAL.txt"
        write_text(
            report,
            (
                "SAENG SOFTWARE SST FINAL\n"
                f"Data: {dt.datetime.now():%d/%m/%Y %H:%M:%S}\n"
                f"Origem: {source}\n"
                f"Destino: {target}\n"
                f"Backup: {backup}\n"
                f"Atalho: {shortcut}\n"
                f"ZIP: {code_zip}\n"
                "Testes locais: APROVADOS\n"
                "Produção oficial: PENDENTE de Produção Restrita, protocolo e recibo individual.\n"
                f"Log: {log_file}\n"
            ),
        )

        print("\nSAENG SOFTWARE SST FINAL — INSTALAÇÃO APROVADA")
        print(f"Pasta: {target}")
        print(f"Atalho: {shortcut}")
        print(f"Relatório: {report}")
        print(f"ZIP: {code_zip}")

        if args.start:
            subprocess.Popen([str(shortcut)], shell=True)
        return 0

    except Exception as exc:
        print(f"\nFALHA CONTROLADA: {exc}")
        if staging.exists():
            shutil.rmtree(staging, ignore_errors=True)
        if previous is not None and previous.exists() and not target.exists():
            previous.rename(target)
        print("A instalação de origem permaneceu preservada.")
        print(f"Backup: {backup if backup.exists() else 'não concluído'}")
        print(f"Log técnico: {log_file}")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
