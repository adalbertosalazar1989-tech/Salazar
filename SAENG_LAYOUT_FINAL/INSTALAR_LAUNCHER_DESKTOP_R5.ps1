#requires -Version 5.1
[CmdletBinding()]
param(
    [string]$Root = "C:\SAENG_Software_SST_V2",
    [switch]$StartAfterInstall
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

function Write-Step {
    param([string]$Text)
    Write-Host ""
    Write-Host "==> $Text" -ForegroundColor Cyan
}

function Write-Ok {
    param([string]$Text)
    Write-Host $Text -ForegroundColor Green
}

$Port = 8765
$Url = "http://127.0.0.1:$Port/"
$HealthUrl = "http://127.0.0.1:$Port/login"
$Python = Join-Path $Root ".venv\Scripts\python.exe"
$Pythonw = Join-Path $Root ".venv\Scripts\pythonw.exe"
$LauncherDir = Join-Path $Root "launcher"
$LauncherPyw = Join-Path $LauncherDir "SAENG_Software_SST.pyw"
$Desktop = [Environment]::GetFolderPath("Desktop")
$ShortcutPath = Join-Path $Desktop "SAENG Software SST.lnk"
$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$BackupDir = Join-Path $Root "backup_launcher_r5_$Timestamp"
$LogPath = Join-Path $Root "storage\launcher_server.log"
$ReportPath = Join-Path $Root "docs\RELATORIO_LAUNCHER_R5.txt"
$BackupReady = $false

$IconCandidates = @(
    (Join-Path $Root "app\static\saeng_software_sst.ico"),
    (Join-Path $Root "app\static\saeng.ico"),
    (Join-Path $Root "saeng_software_sst.ico")
)
$IconPath = $IconCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1

try {
    Write-Host "======================================================" -ForegroundColor DarkBlue
    Write-Host " SAENG SOFTWARE SST V2 - LAUNCHER SILENCIOSO R5" -ForegroundColor Yellow
    Write-Host "======================================================" -ForegroundColor DarkBlue

    if (-not (Test-Path $Root)) {
        throw "Pasta do projeto nao encontrada: $Root"
    }
    if (-not (Test-Path $Python)) {
        throw "Python do ambiente virtual nao encontrado: $Python"
    }
    if (-not (Test-Path $Pythonw)) {
        throw "Pythonw do ambiente virtual nao encontrado: $Pythonw"
    }
    if (-not $IconPath) {
        throw "Icone SAENG nao encontrado em app\static."
    }

    Write-Step "Encerrando somente a instancia SAENG atualmente visivel"
    $Connections = @(Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue)
    foreach ($Connection in $Connections) {
        $PidValue = [int]$Connection.OwningProcess
        $ProcessInfo = Get-CimInstance Win32_Process -Filter "ProcessId=$PidValue" -ErrorAction SilentlyContinue
        $CommandLine = if ($ProcessInfo) { [string]$ProcessInfo.CommandLine } else { "" }
        $Executable = if ($ProcessInfo) { [string]$ProcessInfo.ExecutablePath } else { "" }
        $LooksLikeSaeng = (
            $CommandLine -like "*$Root*" -or
            $CommandLine -match "uvicorn|run_saeng_sst|SAENG_Software_SST_V2" -or
            $Executable -like "*$Root*"
        )
        if (-not $LooksLikeSaeng) {
            throw "A porta $Port esta ocupada por outro programa (PID $PidValue)."
        }
        Stop-Process -Id $PidValue -Force -ErrorAction Stop
        Write-Host "Instancia anterior encerrada. PID: $PidValue" -ForegroundColor Yellow
    }

    Write-Step "Criando backup reversivel"
    New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
    if (Test-Path $LauncherDir) {
        Copy-Item $LauncherDir (Join-Path $BackupDir "launcher") -Recurse -Force
    }
    $OldShortcuts = @(Get-ChildItem -Path $Desktop -Filter "SAENG Software*.lnk" -File -ErrorAction SilentlyContinue)
    foreach ($OldShortcut in $OldShortcuts) {
        Copy-Item $OldShortcut.FullName (Join-Path $BackupDir $OldShortcut.Name) -Force
    }
    $BackupReady = $true
    Write-Ok "Backup criado: $BackupDir"

    Write-Step "Removendo bloqueio de origem dos arquivos locais do SAENG"
    Get-ChildItem -Path $Root -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Extension -in ".bat", ".cmd", ".ps1", ".py", ".pyw", ".ico" } |
        ForEach-Object { Unblock-File -Path $_.FullName -ErrorAction SilentlyContinue }
    Write-Ok "Arquivos locais desbloqueados."

    Write-Step "Criando o iniciador oculto sem janela preta"
    New-Item -ItemType Directory -Path $LauncherDir -Force | Out-Null
    New-Item -ItemType Directory -Path (Split-Path $LogPath) -Force | Out-Null
    New-Item -ItemType Directory -Path (Split-Path $ReportPath) -Force | Out-Null

    $LauncherCode = @'
from __future__ import annotations

import ctypes
import os
import socket
import subprocess
import sys
import time
import urllib.request
import webbrowser
from pathlib import Path

ROOT = Path(r"C:\SAENG_Software_SST_V2")
PORT = 8765
BASE_URL = f"http://127.0.0.1:{PORT}/"
HEALTH_URL = f"http://127.0.0.1:{PORT}/login"
LOG_PATH = ROOT / "storage" / "launcher_server.log"
MUTEX_NAME = "Local\\SAENG_Software_SST_V2_Launcher"

CREATE_NO_WINDOW = getattr(subprocess, "CREATE_NO_WINDOW", 0x08000000)
DETACHED_PROCESS = getattr(subprocess, "DETACHED_PROCESS", 0x00000008)
CREATE_NEW_PROCESS_GROUP = getattr(subprocess, "CREATE_NEW_PROCESS_GROUP", 0x00000200)


def message(title: str, text: str, error: bool = False) -> None:
    flags = 0x10 if error else 0x40
    ctypes.windll.user32.MessageBoxW(None, text, title, flags)


def port_open(timeout: float = 0.35) -> bool:
    try:
        with socket.create_connection(("127.0.0.1", PORT), timeout=timeout):
            return True
    except OSError:
        return False


def saeng_ready(timeout: float = 1.5) -> bool:
    try:
        request = urllib.request.Request(
            HEALTH_URL,
            headers={"User-Agent": "SAENG-Launcher-R5"},
        )
        with urllib.request.urlopen(request, timeout=timeout) as response:
            body = response.read(256_000).decode("utf-8", errors="ignore").lower()
            return response.status == 200 and (
                "saeng" in body or "certificado digital a1" in body
            )
    except Exception:
        return False


def open_application() -> None:
    try:
        webbrowser.open(BASE_URL, new=1, autoraise=True)
    except Exception:
        os.startfile(BASE_URL)  # type: ignore[attr-defined]


def start_hidden_server() -> None:
    LOG_PATH.parent.mkdir(parents=True, exist_ok=True)
    log_handle = open(LOG_PATH, "a", encoding="utf-8", buffering=1)
    log_handle.write("\n=== SAENG launcher R5: nova inicializacao ===\n")

    command = [
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
    ]

    environment = os.environ.copy()
    environment["PYTHONIOENCODING"] = "utf-8"

    subprocess.Popen(
        command,
        cwd=str(ROOT),
        stdin=subprocess.DEVNULL,
        stdout=log_handle,
        stderr=log_handle,
        env=environment,
        creationflags=(
            CREATE_NO_WINDOW
            | DETACHED_PROCESS
            | CREATE_NEW_PROCESS_GROUP
        ),
        close_fds=True,
    )


def main() -> None:
    mutex = ctypes.windll.kernel32.CreateMutexW(None, False, MUTEX_NAME)
    already_running = ctypes.windll.kernel32.GetLastError() == 183

    if already_running:
        for _ in range(45):
            if saeng_ready():
                open_application()
                return
            time.sleep(0.4)
        return

    try:
        if port_open() and not saeng_ready():
            message(
                "SAENG Software SST",
                "A porta 8765 esta sendo usada por outro programa. "
                "Feche o outro programa e tente novamente.",
                error=True,
            )
            return

        if not saeng_ready():
            start_hidden_server()

            for _ in range(75):
                if saeng_ready():
                    break
                time.sleep(0.4)
            else:
                message(
                    "SAENG Software SST",
                    "O servidor nao iniciou dentro do prazo esperado.\n\n"
                    f"Consulte o log em:\n{LOG_PATH}",
                    error=True,
                )
                return

        open_application()
    except Exception as exc:
        message(
            "SAENG Software SST",
            f"Nao foi possivel abrir o sistema.\n\n{exc}\n\n"
            f"Log: {LOG_PATH}",
            error=True,
        )
    finally:
        if mutex:
            ctypes.windll.kernel32.ReleaseMutex(mutex)
            ctypes.windll.kernel32.CloseHandle(mutex)


if __name__ == "__main__":
    main()
'@

    Set-Content -Path $LauncherPyw -Value $LauncherCode -Encoding UTF8
    Unblock-File -Path $LauncherPyw -ErrorAction SilentlyContinue

    Write-Step "Validando o iniciador Python"
    & $Python -m py_compile $LauncherPyw
    if ($LASTEXITCODE -ne 0) {
        throw "O iniciador oculto possui erro de sintaxe."
    }
    Write-Ok "Iniciador oculto validado."

    Write-Step "Substituindo o atalho antigo pelo atalho profissional"
    foreach ($OldShortcut in $OldShortcuts) {
        Remove-Item $OldShortcut.FullName -Force -ErrorAction SilentlyContinue
    }

    $Shell = New-Object -ComObject WScript.Shell
    $Shortcut = $Shell.CreateShortcut($ShortcutPath)
    $Shortcut.TargetPath = $Pythonw
    $Shortcut.Arguments = "`"$LauncherPyw`""
    $Shortcut.WorkingDirectory = $Root
    $Shortcut.IconLocation = "$IconPath,0"
    $Shortcut.Description = "SAENG Software SST - Gestao eSocial e SST"
    $Shortcut.WindowStyle = 7
    $Shortcut.Save()
    Unblock-File -Path $ShortcutPath -ErrorAction SilentlyContinue

    if (-not (Test-Path $ShortcutPath)) {
        throw "O novo atalho nao foi criado na Area de Trabalho."
    }

    $ShortcutCheck = $Shell.CreateShortcut($ShortcutPath)
    if ($ShortcutCheck.TargetPath -ne $Pythonw) {
        throw "O atalho criado nao aponta para pythonw.exe."
    }
    if ($ShortcutCheck.IconLocation -notlike "*$IconPath*") {
        throw "O atalho nao recebeu o icone SAENG."
    }
    Write-Ok "Atalho criado com a identidade visual SAENG."

    Write-Step "Executando compilacao e testes do sistema"
    Push-Location $Root
    try {
        & $Python -m compileall -q app tests $LauncherDir
        if ($LASTEXITCODE -ne 0) {
            throw "Falha na compilacao."
        }
        & $Python -m pytest -q
        if ($LASTEXITCODE -ne 0) {
            throw "Os testes automatizados falharam."
        }
    }
    finally {
        Pop-Location
    }

    @"
SAENG SOFTWARE SST V2 - RELATORIO DO LAUNCHER R5
Data: $(Get-Date -Format "dd/MM/yyyy HH:mm:ss")
Projeto: $Root
Atalho: $ShortcutPath
Executavel silencioso: $Pythonw
Launcher: $LauncherPyw
Icone: $IconPath
URL inicial: $Url
Janela preta: ELIMINADA
Aviso de execucao do arquivo BAT: ELIMINADO PELO NOVO ATALHO
Prevencao de servidores duplicados: ATIVA
Servidor em segundo plano: ATIVO
Compilacao: APROVADA
Testes: APROVADOS
Backup: $BackupDir
"@ | Set-Content -Path $ReportPath -Encoding UTF8

    Write-Host ""
    Write-Host "======================================================" -ForegroundColor DarkBlue
    Write-Host " LAUNCHER SILENCIOSO R5 INSTALADO E VALIDADO" -ForegroundColor Green
    Write-Host "======================================================" -ForegroundColor DarkBlue
    Write-Host "Atalho: $ShortcutPath" -ForegroundColor White
    Write-Host "Icone: $IconPath" -ForegroundColor White
    Write-Host "Launcher: $LauncherPyw" -ForegroundColor White
    Write-Host "Backup: $BackupDir" -ForegroundColor Cyan
    Write-Host "Relatorio: $ReportPath" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "A partir de agora, use somente o novo icone da Area de Trabalho." -ForegroundColor Green
    Write-Host "Nao use mais START_SAENG_SST.bat para abrir o sistema." -ForegroundColor Yellow

    if ($StartAfterInstall) {
        Write-Step "Abrindo o SAENG pelo novo atalho silencioso"
        Start-Process -FilePath $ShortcutPath

        $Online = $false
        for ($Attempt = 1; $Attempt -le 40; $Attempt++) {
            Start-Sleep -Milliseconds 500
            try {
                $Response = Invoke-WebRequest -Uri $HealthUrl -UseBasicParsing -TimeoutSec 2
                if ($Response.StatusCode -eq 200) {
                    $Online = $true
                    break
                }
            }
            catch {
            }
        }
        if (-not $Online) {
            throw "O servidor oculto nao respondeu na porta $Port."
        }
        Write-Ok "Servidor oculto iniciado e pagina respondeu HTTP 200."
    }
}
catch {
    Write-Host ""
    Write-Host "FALHA: $($_.Exception.Message)" -ForegroundColor Red
    if ($BackupReady) {
        Write-Host "O backup foi preservado em: $BackupDir" -ForegroundColor Yellow
    }
    throw
}
