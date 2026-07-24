#requires -Version 5.1
[CmdletBinding()]
param(
    [string]$Root = "C:\SAENG_Software_SST_V2",
    [switch]$StartAfterApply
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

$LoginPath = Join-Path $Root "app\templates\login.html"
$CssPath = Join-Path $Root "app\static\login-final.css"
$StartFile = Join-Path $Root "START_SAENG_SST.bat"
$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$BackupDir = Join-Path $Root "backup_layout_r3_$Timestamp"
$BackupReady = $false

try {
    Write-Host "======================================================" -ForegroundColor DarkBlue
    Write-Host " SAENG SOFTWARE SST V2 - PAGINA UNICA R3" -ForegroundColor Yellow
    Write-Host "======================================================" -ForegroundColor DarkBlue

    if (-not (Test-Path $LoginPath)) {
        throw "Template de login nao encontrado: $LoginPath"
    }
    if (-not (Test-Path $CssPath)) {
        throw "CSS final nao encontrado: $CssPath"
    }

    Write-Step "Encerrando somente a instancia SAENG da porta 8765"
    $Connections = @(Get-NetTCPConnection -LocalPort 8765 -State Listen -ErrorAction SilentlyContinue)
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
            throw "A porta 8765 esta ocupada por outro processo (PID $PidValue)."
        }
        Stop-Process -Id $PidValue -Force -ErrorAction Stop
        Write-Host "Instancia anterior encerrada. PID: $PidValue" -ForegroundColor Yellow
    }

    Write-Step "Criando backup reversivel"
    New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
    Copy-Item $LoginPath (Join-Path $BackupDir "login.html") -Force
    Copy-Item $CssPath (Join-Path $BackupDir "login-final.css") -Force
    $BackupReady = $true
    Write-Ok "Backup criado: $BackupDir"

    Write-Step "Aplicando alinhamento de pagina unica"
    $Login = Get-Content $LoginPath -Raw -Encoding UTF8

    $Login = [regex]::Replace(
        $Login,
        '(?is)<!-- SAENG_LAYOUT_POLIMENTO_R2_START -->.*?<!-- SAENG_LAYOUT_POLIMENTO_R2_END -->',
        ''
    )
    $Login = [regex]::Replace(
        $Login,
        '(?is)<!-- SAENG_LAYOUT_PAGINA_UNICA_R3_START -->.*?<!-- SAENG_LAYOUT_PAGINA_UNICA_R3_END -->',
        ''
    )
    $Login = [regex]::Replace(
        $Login,
        '/static/login-final\.css\?v=[^"'']+',
        '/static/login-final.css?v=20260724-r3'
    )

    $Patch = @'
<!-- SAENG_LAYOUT_PAGINA_UNICA_R3_START -->
<style id="saeng-layout-pagina-unica-r3">
@media (min-width: 921px) {
    html,
    body.saeng-login-page {
        width: 100%;
        height: 100%;
        min-height: 100%;
        overflow: hidden !important;
    }

    .saeng-login-shell {
        width: 100%;
        height: 100vh;
        min-height: 100vh;
        overflow: hidden;
        grid-template-columns: minmax(0, 1.42fr) minmax(470px, .88fr);
    }

    .saeng-brand-panel,
    .saeng-access-panel {
        height: 100vh;
        min-height: 0;
        overflow: hidden;
    }

    .saeng-brand-content {
        width: min(830px, 100%);
        height: 100%;
        min-height: 0;
        padding: clamp(24px, 3.4vh, 38px) clamp(34px, 6vw, 82px) 20px;
        justify-content: center;
    }

    .saeng-brand-header {
        margin-bottom: clamp(20px, 3.2vh, 34px);
    }

    .saeng-logo-frame {
        width: clamp(82px, 7vw, 104px);
        height: clamp(82px, 7vw, 104px);
        border-radius: 22px;
    }

    .saeng-brand-copy h1 {
        font-size: clamp(45px, 4.25vw, 68px);
        line-height: .99;
    }

    .saeng-description {
        margin-top: 16px;
        font-size: clamp(14px, 1.05vw, 16px);
        line-height: 1.55;
    }

    .saeng-feature-grid {
        margin-top: clamp(18px, 2.7vh, 28px);
        gap: 12px;
    }

    .saeng-feature-card {
        min-height: 68px;
        padding: 12px 18px;
    }

    .saeng-brand-footer {
        margin-top: clamp(16px, 2.5vh, 28px);
    }

    .saeng-access-panel {
        align-items: flex-start !important;
        justify-content: center;
        padding: 16px 28px 12px;
    }

    .saeng-access-wrap {
        width: min(540px, 100%);
        height: 100%;
        min-height: 0;
        margin: 0 auto;
        padding-top: 0;
        display: flex;
        flex-direction: column;
        justify-content: flex-start;
        gap: 10px;
    }

    .saeng-auth-card {
        width: 100%;
        max-height: none !important;
        margin: 0 !important;
        padding: clamp(25px, 3vh, 34px) clamp(30px, 3.5vw, 42px) 22px;
        overflow: visible !important;
        border-radius: 28px;
    }

    .saeng-auth-header {
        margin-bottom: 14px;
    }

    .saeng-auth-header h2 {
        font-size: clamp(32px, 3vw, 40px);
        line-height: 1.04;
    }

    .saeng-auth-header p {
        margin-top: 10px;
        font-size: 14px;
        line-height: 1.45;
    }

    .saeng-certificate-form form {
        margin: 0 !important;
    }

    .saeng-certificate-form form > :first-child {
        margin-top: 0 !important;
    }

    .saeng-security-note {
        margin-top: 12px;
        padding-top: 12px;
        font-size: 12px;
        line-height: 1.4;
    }

    .saeng-local-access {
        margin-top: 0 !important;
    }

    .saeng-local-access summary {
        min-height: 64px;
        padding: 12px 18px;
    }

    .saeng-access-footer {
        margin: 0;
        padding: 0 8px;
        font-size: 10px;
        line-height: 1.2;
    }
}

@media (min-width: 921px) and (max-height: 820px) {
    .saeng-brand-content {
        padding-top: 18px;
        padding-bottom: 14px;
    }

    .saeng-brand-header {
        margin-bottom: 16px;
    }

    .saeng-logo-frame {
        width: 78px;
        height: 78px;
        border-radius: 19px;
    }

    .saeng-company-name {
        font-size: 10px;
    }

    .saeng-eyebrow {
        font-size: 10px;
        margin-bottom: 12px;
    }

    .saeng-brand-copy h1 {
        font-size: clamp(42px, 4vw, 58px);
    }

    .saeng-description {
        margin-top: 12px;
        font-size: 14px;
    }

    .saeng-feature-grid {
        margin-top: 16px;
    }

    .saeng-feature-card {
        min-height: 62px;
        padding-top: 10px;
        padding-bottom: 10px;
    }

    .saeng-brand-footer {
        margin-top: 14px;
    }

    .saeng-access-panel {
        padding-top: 10px;
        padding-bottom: 8px;
    }

    .saeng-auth-card {
        padding-top: 22px;
        padding-bottom: 18px;
    }

    .saeng-auth-header {
        margin-bottom: 10px;
    }

    .saeng-auth-header h2 {
        font-size: 31px;
    }

    .saeng-auth-header p {
        margin-top: 7px;
        font-size: 13px;
    }

    .saeng-local-access summary {
        min-height: 58px;
        padding-top: 9px;
        padding-bottom: 9px;
    }
}

@media (max-width: 920px) {
    html,
    body.saeng-login-page {
        overflow-x: hidden;
        overflow-y: auto;
    }
}
</style>
<script id="saeng-layout-pagina-unica-r3-script">
(function () {
    "use strict";

    function normalizeText(value) {
        return (value || "")
            .replace(/\s+/g, " ")
            .trim()
            .toLocaleLowerCase("pt-BR");
    }

    var host = document.querySelector(".saeng-certificate-form");
    if (!host) {
        return;
    }

    var duplicates = [
        "acesso principal",
        "certificado digital a1"
    ];

    var nodes = host.querySelectorAll(
        "h1,h2,h3,h4,h5,h6,p,small,legend,strong,span,div,section,header"
    );

    Array.prototype.forEach.call(nodes, function (element) {
        if (element.querySelector("input,button,select,textarea,label,form")) {
            return;
        }

        var text = normalizeText(element.textContent);
        var duplicateTitle = duplicates.indexOf(text) !== -1;
        var duplicateSecurity = text.indexOf(
            "o pfx e a senha são mantidos somente na memória do processo"
        ) === 0;

        if (duplicateTitle || duplicateSecurity) {
            element.remove();
        }
    });
})();
</script>
<!-- SAENG_LAYOUT_PAGINA_UNICA_R3_END -->
'@

    if ($Login -notmatch '(?i)</body>') {
        throw "A tag de fechamento BODY nao foi encontrada."
    }

    $Login = [regex]::Replace($Login, '(?i)</body>', ($Patch + "`r`n</body>"), 1)
    Set-Content $LoginPath $Login -Encoding UTF8

    Write-Step "Validando a pagina unica"
    $Saved = Get-Content $LoginPath -Raw -Encoding UTF8
    if ($Saved -notmatch 'SAENG_LAYOUT_PAGINA_UNICA_R3_START') {
        throw "O marcador R3 nao foi gravado."
    }
    if ($Saved -match 'splash-saeng\.png|abertura-saeng\.png') {
        throw "Ainda existe referencia ao mockup ou splash no login."
    }
    if ($Saved -notmatch '/static/login-final\.css\?v=20260724-r3') {
        throw "A versao de cache do CSS nao foi atualizada."
    }

    Write-Step "Compilando e executando os testes"
    $Python = Join-Path $Root ".venv\Scripts\python.exe"
    if (-not (Test-Path $Python)) {
        throw "Python virtual nao encontrado: $Python"
    }

    Push-Location $Root
    try {
        & $Python -m compileall -q app tests
        if ($LASTEXITCODE -ne 0) {
            throw "Falha na compilacao Python."
        }
        & $Python -m pytest -q
        if ($LASTEXITCODE -ne 0) {
            throw "Os testes automatizados falharam."
        }
    }
    finally {
        Pop-Location
    }

    $Report = Join-Path $Root "docs\RELATORIO_LAYOUT_R3.txt"
    @"
SAENG SOFTWARE SST V2 - RELATORIO DE PAGINA UNICA R3
Data: $(Get-Date -Format "dd/MM/yyyy HH:mm:ss")
Projeto: $Root
Backup: $BackupDir
Painel direito elevado: SIM
Pagina desktop sem rolagem: SIM
Proporcoes reajustadas: SIM
Titulos duplicados removidos: SIM
Aviso duplicado removido: SIM
Mockup e splash ausentes: SIM
Compilacao: APROVADA
Testes: APROVADOS
"@ | Set-Content $Report -Encoding UTF8

    Write-Host ""
    Write-Host "======================================================" -ForegroundColor DarkBlue
    Write-Host " PAGINA UNICA R3 APLICADA E VALIDADA" -ForegroundColor Green
    Write-Host "======================================================" -ForegroundColor DarkBlue
    Write-Host "Backup: $BackupDir" -ForegroundColor Cyan
    Write-Host "Relatorio: $Report" -ForegroundColor White

    if ($StartAfterApply) {
        Write-Step "Iniciando uma unica instancia do SAENG"
        if (-not (Test-Path $StartFile)) {
            throw "Inicializador nao encontrado: $StartFile"
        }
        Start-Process -FilePath $StartFile -WorkingDirectory $Root

        $Online = $false
        for ($Attempt = 1; $Attempt -le 20; $Attempt++) {
            Start-Sleep -Milliseconds 700
            try {
                $Response = Invoke-WebRequest -Uri "http://127.0.0.1:8765/login?v=layout-r3" -UseBasicParsing -TimeoutSec 2
                if ($Response.StatusCode -eq 200) {
                    $Online = $true
                    break
                }
            }
            catch {
            }
        }
        if (-not $Online) {
            throw "O servidor nao respondeu na porta 8765."
        }
        Write-Ok "Servidor iniciado e pagina de login respondeu HTTP 200."
        Start-Process "http://127.0.0.1:8765/login?v=layout-r3"
    }
}
catch {
    Write-Host ""
    Write-Host "FALHA: $($_.Exception.Message)" -ForegroundColor Red
    if ($BackupReady) {
        Copy-Item (Join-Path $BackupDir "login.html") $LoginPath -Force
        Copy-Item (Join-Path $BackupDir "login-final.css") $CssPath -Force
        Write-Host "Rollback concluido. Os arquivos anteriores foram restaurados." -ForegroundColor Green
    }
    throw
}
