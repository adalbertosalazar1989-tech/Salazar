param(
    [string]$Origem = "C:\SAENG_Software_SST_V2",
    [string]$Destino = "C:\SAENG_Software_SST_R9_CANDIDATE",
    [switch]$Iniciar
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

function Write-Step([string]$Text) {
    Write-Host ""
    Write-Host "==> $Text" -ForegroundColor Cyan
}

function Write-Warn([string]$Text) {
    Write-Host "AVISO: $Text" -ForegroundColor Yellow
}

function Find-Python {
    $Candidates = @(
        @{ Command = "py"; Args = @("-3.12") },
        @{ Command = "py"; Args = @("-3.11") },
        @{ Command = "python"; Args = @() }
    )
    foreach ($Candidate in $Candidates) {
        try {
            & $Candidate.Command @($Candidate.Args) --version *> $null
            if ($LASTEXITCODE -eq 0) { return $Candidate }
        } catch {}
    }
    throw "Python 3.11 ou 3.12 nao encontrado. Instale uma versao suportada e habilite o launcher py."
}

function Set-EnvValue([string]$Path, [string]$Name, [string]$Value) {
    $Lines = @()
    if (Test-Path $Path) { $Lines = @(Get-Content -Path $Path -Encoding UTF8) }
    $Pattern = "^" + [regex]::Escape($Name) + "="
    $Found = $false
    $NewLines = foreach ($Line in $Lines) {
        if ($Line -match $Pattern) {
            $Found = $true
            "$Name=$Value"
        } else {
            $Line
        }
    }
    if (-not $Found) { $NewLines += "$Name=$Value" }
    Set-Content -Path $Path -Value $NewLines -Encoding UTF8
}

function Test-Robocopy([int]$ExitCode, [string]$Context) {
    if ($ExitCode -gt 7) {
        throw "$Context falhou. Codigo Robocopy: $ExitCode"
    }
}

function New-Inventory([string]$Root, [string]$Output) {
    Get-ChildItem -Path $Root -Recurse -File -Force |
        Where-Object {
            $_.FullName -notmatch '\\.venv\\|\\.git\\|\\__pycache__\\|\\.pytest_cache\\|\\node_modules\\'
        } |
        ForEach-Object {
            [pscustomobject]@{
                Path = $_.FullName.Substring($Root.Length).TrimStart("\\")
                Size = $_.Length
                SHA256 = (Get-FileHash -Path $_.FullName -Algorithm SHA256).Hash
            }
        } |
        Sort-Object Path |
        Export-Csv -Path $Output -NoTypeInformation -Encoding UTF8
}

function Invoke-Checked([string]$Name, [scriptblock]$Action, [string]$LogPath) {
    Write-Step $Name
    & $Action 2>&1 | Tee-Object -FilePath $LogPath
    if ($LASTEXITCODE -ne 0) {
        throw "$Name reprovado. Consulte $LogPath"
    }
}

Write-Host "==============================================================" -ForegroundColor DarkBlue
Write-Host " SAENG SOFTWARE SST R9 - FINALIZACAO CONTROLADA" -ForegroundColor Yellow
Write-Host "==============================================================" -ForegroundColor DarkBlue
Write-Host "Este processo nao habilita Producao oficial automaticamente." -ForegroundColor Yellow
Write-Host "PFX, P12, PEM, KEY e senhas nao serao empacotados." -ForegroundColor Green

$PackageRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$Backup = "C:\SAENG_Software_SST_BACKUP_R9_$Timestamp"
$ZipCandidate = "C:\SAENG_Software_SST_R9_CANDIDATE.zip"
$Required = @(
    "app\main.py",
    "app\config.py",
    "app\database.py",
    "app\models.py",
    "requirements.txt",
    "tests",
    "schemas"
)

Write-Step "Validando a instalacao canônica"
if (-not (Test-Path $Origem)) {
    throw "Instalacao nao encontrada em $Origem. Nao exclua a versao atual."
}
foreach ($Relative in $Required) {
    if (-not (Test-Path (Join-Path $Origem $Relative))) {
        throw "Componente obrigatorio ausente: $Relative"
    }
}

Write-Step "Criando backup reversivel"
New-Item -ItemType Directory -Path $Backup -Force | Out-Null
$BackupArgs = @(
    $Origem,
    $Backup,
    "/E",
    "/COPY:DAT",
    "/DCOPY:DAT",
    "/R:2",
    "/W:2",
    "/XD",
    ".venv",
    ".git",
    ".pytest_cache",
    "__pycache__",
    "node_modules",
    "/XF",
    "*.pfx",
    "*.p12",
    "*.pem",
    "*.key"
)
& robocopy @BackupArgs | Out-Host
Test-Robocopy $LASTEXITCODE "Backup"

if (Test-Path $Destino) {
    $Previous = "${Destino}_ANTERIOR_$Timestamp"
    Write-Step "Preservando candidato R9 anterior em $Previous"
    Move-Item -Path $Destino -Destination $Previous
}

Write-Step "Criando candidato R9 isolado"
New-Item -ItemType Directory -Path $Destino -Force | Out-Null
$CopyArgs = @(
    $Origem,
    $Destino,
    "/E",
    "/COPY:DAT",
    "/DCOPY:DAT",
    "/R:2",
    "/W:2",
    "/XD",
    ".venv",
    ".git",
    ".pytest_cache",
    "__pycache__",
    "node_modules",
    "backups",
    "/XF",
    "*.pfx",
    "*.p12",
    "*.pem",
    "*.key"
)
& robocopy @CopyArgs | Out-Host
Test-Robocopy $LASTEXITCODE "Copia do candidato"

$Evidence = Join-Path $Destino "docs\evidence\r9_$Timestamp"
New-Item -ItemType Directory -Path $Evidence -Force | Out-Null
$GateToolSource = Join-Path $PackageRoot "tools\r9_gate.py"
$GateToolDestination = Join-Path $Destino "scripts\r9_gate.py"
New-Item -ItemType Directory -Path (Split-Path -Parent $GateToolDestination) -Force | Out-Null
if (-not (Test-Path $GateToolSource)) { throw "Gate R9 ausente: $GateToolSource" }
Copy-Item -Path $GateToolSource -Destination $GateToolDestination -Force

Write-Step "Aplicando configuracao fail-closed do candidato"
$EnvPath = Join-Path $Destino ".env"
Set-EnvValue $EnvPath "APP_VERSION" "2.0.0-r9-candidate"
Set-EnvValue $EnvPath "TRANSMISSION_MODE" "RESTRICTED"
Set-EnvValue $EnvPath "ESOCIAL_ENVIRONMENT" "2"
Set-EnvValue $EnvPath "ALLOW_REAL_TRANSMISSION" "false"
Set-EnvValue $EnvPath "ALLOW_PRODUCTION_TRANSMISSION" "false"
Set-EnvValue $EnvPath "CERTIFICATE_LOGIN_REQUIRED" "true"
Set-EnvValue $EnvPath "DEMO_SEED_ENABLED" "false"
Set-EnvValue $EnvPath "PLAINTEXT_BACKUP_ENABLED" "false"

Write-Step "Gerando inventario criptografico"
New-Inventory -Root $Destino -Output (Join-Path $Evidence "inventory.csv")

$Python = Find-Python
Write-Host "Python selecionado: $($Python.Command) $($Python.Args -join ' ')" -ForegroundColor Gray

Push-Location $Destino
try {
    Write-Step "Criando ambiente virtual limpo"
    & $Python.Command @($Python.Args) -m venv .venv
    if ($LASTEXITCODE -ne 0) { throw "Falha ao criar ambiente virtual." }
    $VenvPython = Join-Path $Destino ".venv\Scripts\python.exe"
    if (-not (Test-Path $VenvPython)) { throw "Python do ambiente virtual nao encontrado." }

    Invoke-Checked "Atualizando pip" {
        & $VenvPython -m pip install --upgrade pip
    } (Join-Path $Evidence "pip-upgrade.txt")

    Invoke-Checked "Instalando dependencias do produto" {
        & $VenvPython -m pip install -r requirements.txt
    } (Join-Path $Evidence "pip-install.txt")

    Invoke-Checked "Instalando ferramentas de qualidade" {
        & $VenvPython -m pip install pytest ruff bandit pip-audit
    } (Join-Path $Evidence "quality-tools-install.txt")

    Invoke-Checked "Validando dependencias" {
        & $VenvPython -m pip check
    } (Join-Path $Evidence "pip-check.txt")

    Invoke-Checked "Compilando codigo Python" {
        & $VenvPython -m compileall -q app tests scripts
    } (Join-Path $Evidence "compileall.txt")

    Invoke-Checked "Executando testes isolados" {
        $env:PYTHONPATH = $Destino
        & $VenvPython -m pytest -q --import-mode=importlib
    } (Join-Path $Evidence "pytest.txt")

    Invoke-Checked "Executando lint Ruff" {
        & $VenvPython -m ruff check app tests scripts
    } (Join-Path $Evidence "ruff.txt")

    Invoke-Checked "Executando seguranca estatica Bandit" {
        & $VenvPython -m bandit -q -r app -lll
    } (Join-Path $Evidence "bandit.txt")

    Invoke-Checked "Auditando dependencias conhecidas" {
        & $VenvPython -m pip_audit
    } (Join-Path $Evidence "pip-audit.txt")

    Write-Step "Executando gate arquitetural R9"
    $GateReport = Join-Path $Evidence "R9_GATE_REPORT.json"
    & $VenvPython $GateToolDestination --root $Destino --output $GateReport --strict 2>&1 |
        Tee-Object -FilePath (Join-Path $Evidence "r9-gate.txt")
    if ($LASTEXITCODE -ne 0) {
        Write-Warn "O candidato foi preservado, mas o release permanece bloqueado por achados estruturais."
        Write-Warn "Consulte: $GateReport"
        throw "Gate R9 bloqueado. Nenhum ZIP final foi criado."
    }

    Write-Step "Gerando manifesto SHA-256"
    New-Inventory -Root $Destino -Output (Join-Path $Evidence "manifest-final.csv")

    Write-Step "Criando ZIP do candidato aprovado localmente"
    if (Test-Path $ZipCandidate) { Remove-Item -Path $ZipCandidate -Force }
    $Staging = Join-Path $env:TEMP "SAENG_R9_PACKAGE_$Timestamp"
    if (Test-Path $Staging) { Remove-Item -Path $Staging -Recurse -Force }
    New-Item -ItemType Directory -Path $Staging -Force | Out-Null
    $ZipArgs = @(
        $Destino,
        $Staging,
        "/E",
        "/COPY:DAT",
        "/R:1",
        "/W:1",
        "/XD",
        ".venv",
        ".pytest_cache",
        "__pycache__",
        "node_modules",
        "backups",
        "/XF",
        "*.pfx",
        "*.p12",
        "*.pem",
        "*.key"
    )
    & robocopy @ZipArgs | Out-Null
    Test-Robocopy $LASTEXITCODE "Preparacao do ZIP"
    $ZipItems = Get-ChildItem -Path $Staging -Force
    Compress-Archive -Path $ZipItems.FullName -DestinationPath $ZipCandidate -CompressionLevel Optimal
    Remove-Item -Path $Staging -Recurse -Force

    Write-Host ""
    Write-Host "==============================================================" -ForegroundColor DarkBlue
    Write-Host " CANDIDATO R9 APROVADO NOS GATES LOCAIS" -ForegroundColor Green
    Write-Host "==============================================================" -ForegroundColor DarkBlue
    Write-Host "Candidato: $Destino" -ForegroundColor White
    Write-Host "Backup: $Backup" -ForegroundColor White
    Write-Host "ZIP: $ZipCandidate" -ForegroundColor White
    Write-Host "Evidencias: $Evidence" -ForegroundColor White
    Write-Host "Ambiente mantido em RESTRICTED/tpAmb=2; Producao nao foi habilitada." -ForegroundColor Yellow

    if ($Iniciar) {
        $LauncherCandidates = @(
            (Join-Path $Destino "START_SAENG_SST_SILENT.vbs"),
            (Join-Path $Destino "START_SAENG_SST.bat"),
            (Join-Path $Destino "START_SAENG_V2.cmd")
        )
        $Launcher = $LauncherCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
        if ($Launcher) {
            Start-Process -FilePath $Launcher
        } else {
            Write-Warn "Launcher nao localizado; inicie o servidor pelo procedimento documentado."
        }
    }
} finally {
    Pop-Location
}
