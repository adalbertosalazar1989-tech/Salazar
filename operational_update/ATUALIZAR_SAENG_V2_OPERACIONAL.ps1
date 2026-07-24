param(
    [string]$Destino = "C:\SAENG_Software_SST_V2",
    [switch]$Iniciar
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

function Etapa([string]$Texto) {
    Write-Host ""
    Write-Host "==> $Texto" -ForegroundColor Cyan
}

function Definir-Env([string]$Arquivo, [string]$Nome, [string]$Valor) {
    $linhas = @()
    if (Test-Path $Arquivo) { $linhas = @(Get-Content $Arquivo -Encoding UTF8) }
    $padrao = "^" + [regex]::Escape($Nome) + "="
    $encontrou = $false
    $novas = foreach ($linha in $linhas) {
        if ($linha -match $padrao) {
            $encontrou = $true
            "$Nome=$Valor"
        } else { $linha }
    }
    if (-not $encontrou) { $novas += "$Nome=$Valor" }
    Set-Content -Path $Arquivo -Value $novas -Encoding UTF8
}

Write-Host "======================================================" -ForegroundColor DarkBlue
Write-Host " SAENG SOFTWARE SST V2 - ATUALIZACAO OPERACIONAL" -ForegroundColor Yellow
Write-Host "======================================================" -ForegroundColor DarkBlue
Write-Host "Esta atualizacao nao pede senha e nao copia PFX/P12." -ForegroundColor Green
Write-Host "A transmissao real continuara bloqueada por padrao." -ForegroundColor Green

$Pacote = Split-Path -Parent $MyInvocation.MyCommand.Path
$Data = Get-Date -Format "yyyyMMdd_HHmmss"
$Backup = "${Destino}_BACKUP_OPERACIONAL_$Data"
$ModuloOrigem = Join-Path $Pacote "v2_operational.py"
$ModuloDestino = Join-Path $Destino "app\operational_v2.py"
$MainPy = Join-Path $Destino "app\main.py"
$BaseHtml = Join-Path $Destino "app\templates\base.html"
$EnvFile = Join-Path $Destino ".env"
$Python = Join-Path $Destino ".venv\Scripts\python.exe"

Etapa "Validando a instalacao V2 existente"
foreach ($item in @($Destino, $MainPy, $BaseHtml, $Python, $ModuloOrigem)) {
    if (-not (Test-Path $item)) { throw "Arquivo ou pasta obrigatoria ausente: $item" }
}

Etapa "Criando backup reversivel da V2"
$ArgsBackup = @($Destino, $Backup, "/E", "/COPY:DAT", "/DCOPY:DAT", "/R:2", "/W:2", "/XD", ".venv", ".pytest_cache", "__pycache__", "/XF", "*.pfx", "*.p12", "*.pem", "*.key")
& robocopy @ArgsBackup | Out-Host
if ($LASTEXITCODE -gt 7) { throw "Falha no backup. Codigo Robocopy: $LASTEXITCODE" }

Etapa "Instalando o banco e motor operacional integrado"
Copy-Item $ModuloOrigem $ModuloDestino -Force

$Main = Get-Content $MainPy -Raw -Encoding UTF8
$Marcador = "# SAENG_V2_OPERATIONAL_ROUTER"
if ($Main -notmatch [regex]::Escape($Marcador)) {
    $Registro = @'

# SAENG_V2_OPERATIONAL_ROUTER
try:
    from .operational_v2 import router as operational_v2_router
    app.include_router(operational_v2_router)
except Exception as exc:
    import logging
    logging.getLogger("saeng.operacional").exception("Falha ao carregar modulo operacional V2: %s", exc)
'@
    Add-Content -Path $MainPy -Value $Registro -Encoding UTF8
}

Etapa "Integrando a central operacional ao menu principal"
$Base = Get-Content $BaseHtml -Raw -Encoding UTF8
if ($Base -notmatch 'href="/operacional"') {
    $Alvo = '<a class="nav-item" href="/events">⇄ <span>Eventos eSocial</span></a>'
    $Novo = '<a class="nav-item" href="/operacional">◆ <span>Central operacional V2</span></a>' + "`r`n      " + $Alvo
    if (-not $Base.Contains($Alvo)) { throw "Ponto seguro do menu nao localizado em base.html" }
    $Base = $Base.Replace($Alvo, $Novo)
    Set-Content -Path $BaseHtml -Value $Base -Encoding UTF8
}

Etapa "Mantendo configuracao segura"
Definir-Env $EnvFile "APP_VERSION" "2.1.0-rc2"
Definir-Env $EnvFile "CERTIFICATE_LOGIN_REQUIRED" "false"
Definir-Env $EnvFile "TRANSMISSION_MODE" "MOCK"
Definir-Env $EnvFile "ALLOW_REAL_TRANSMISSION" "false"
Definir-Env $EnvFile "ALLOW_PRODUCTION_TRANSMISSION" "false"
Definir-Env $EnvFile "ESOCIAL_ENVIRONMENT" "2"

New-Item -ItemType Directory -Path (Join-Path $Destino "imports\operacional") -Force | Out-Null

Push-Location $Destino
try {
    Etapa "Verificando dependencias"
    & $Python -m pip check
    if ($LASTEXITCODE -ne 0) { throw "pip check encontrou dependencia inconsistente." }

    Etapa "Compilando todo o sistema"
    & $Python -m compileall -q app tests
    if ($LASTEXITCODE -ne 0) { throw "Falha de compilacao." }

    Etapa "Executando testes existentes"
    $Relatorio = Join-Path $Destino "docs\RELATORIO_TESTES_OPERACIONAL_V2.txt"
    & $Python -m pytest -q 2>&1 | Tee-Object -FilePath $Relatorio
    if ($LASTEXITCODE -ne 0) { throw "Os testes falharam. Consulte $Relatorio" }

    Etapa "Executando smoke test do novo modulo"
    & $Python -c "from app.main import app; paths={r.path for r in app.routes}; required={'/operacional','/operacional/riscos','/operacional/importacao','/operacional/homologacao'}; missing=required-paths; assert not missing, missing; print('Rotas operacionais registradas:', sorted(required))"
    if ($LASTEXITCODE -ne 0) { throw "Smoke test das rotas operacionais falhou." }

    Etapa "Verificando ausencia de certificados e chaves"
    $Segredos = @(Get-ChildItem -Path $Destino -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -match '^\.(pfx|p12|pem|key)$' })
    if ($Segredos.Count -gt 0) {
        $Segredos | ForEach-Object { Write-Host $_.FullName -ForegroundColor Red }
        throw "Certificado ou chave encontrado na pasta do software. Remova antes de continuar."
    }

    Write-Host ""
    Write-Host "======================================================" -ForegroundColor DarkBlue
    Write-Host " ATUALIZACAO OPERACIONAL CONCLUIDA" -ForegroundColor Green
    Write-Host "======================================================" -ForegroundColor DarkBlue
    Write-Host "Sistema: $Destino" -ForegroundColor White
    Write-Host "Backup: $Backup" -ForegroundColor White
    Write-Host "Central: http://127.0.0.1:8765/operacional" -ForegroundColor White
    Write-Host "Relatorio: $Relatorio" -ForegroundColor White

    if ($Iniciar) {
        Etapa "Iniciando o SAENG Software SST"
        Start-Process -FilePath (Join-Path $Destino "START_SAENG_SST.bat") -WorkingDirectory $Destino
    }
}
finally {
    Pop-Location
}
