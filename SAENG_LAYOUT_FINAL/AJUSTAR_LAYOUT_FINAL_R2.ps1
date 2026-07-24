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
$BackupDir = Join-Path $Root "backup_layout_r2_$Timestamp"
$BackupReady = $false

try {
    Write-Host "======================================================" -ForegroundColor DarkBlue
    Write-Host " SAENG SOFTWARE SST V2 - POLIMENTO VISUAL R2" -ForegroundColor Yellow
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

    Write-Step "Removendo titulos e avisos duplicados do formulario reaproveitado"
    $Login = Get-Content $LoginPath -Raw -Encoding UTF8

    $Login = [regex]::Replace(
        $Login,
        '(?is)<!-- SAENG_LAYOUT_POLIMENTO_R2_START -->.*?<!-- SAENG_LAYOUT_POLIMENTO_R2_END -->',
        ''
    )

    $Login = [regex]::Replace(
        $Login,
        '/static/login-final\.css\?v=[^"'']+',
        '/static/login-final.css?v=20260724-r2'
    )

    $Patch = @'
<!-- SAENG_LAYOUT_POLIMENTO_R2_START -->
<style id="saeng-layout-polimento-r2">
    .saeng-auth-card {
        max-height: calc(100vh - 38px);
        overflow-y: auto;
        overscroll-behavior: contain;
        scrollbar-width: thin;
    }

    .saeng-certificate-form form {
        margin: 0 !important;
    }

    .saeng-certificate-form form > :first-child {
        margin-top: 0 !important;
    }

    .saeng-certificate-form .saeng-r2-empty {
        display: none !important;
    }

    @media (min-width: 921px) {
        .saeng-access-panel {
            padding: 18px 26px;
        }

        .saeng-access-wrap {
            width: min(560px, 100%);
        }

        .saeng-auth-card {
            padding: clamp(30px, 4vh, 42px) clamp(30px, 3.4vw, 44px);
        }

        .saeng-auth-header {
            margin-bottom: 18px;
        }
    }

    @media (max-height: 820px) and (min-width: 921px) {
        .saeng-auth-card {
            max-height: calc(100vh - 24px);
            padding-top: 26px;
            padding-bottom: 26px;
        }

        .saeng-auth-header h2 {
            font-size: 34px;
        }

        .saeng-auth-header p {
            margin-bottom: 0;
        }
    }
</style>
<script id="saeng-layout-polimento-r2-script">
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

    var exactDuplicates = [
        "acesso principal",
        "certificado digital a1"
    ];

    var candidates = host.querySelectorAll(
        "h1,h2,h3,h4,h5,h6,p,small,legend,strong,span,div,section,header"
    );

    Array.prototype.forEach.call(candidates, function (element) {
        if (element.querySelector("input,button,select,textarea,label,form")) {
            return;
        }

        var text = normalizeText(element.textContent);
        var duplicateTitle = exactDuplicates.indexOf(text) !== -1;
        var duplicateSecurity = text.indexOf(
            "o pfx e a senha são mantidos somente na memória do processo"
        ) === 0;

        if (duplicateTitle || duplicateSecurity) {
            element.remove();
        }
    });

    var removable = host.querySelectorAll("div,section,header,p,small");
    Array.prototype.forEach.call(Array.prototype.slice.call(removable).reverse(), function (element) {
        if (element.querySelector("input,button,select,textarea,label,form")) {
            return;
        }
        if (!normalizeText(element.textContent) && element.children.length === 0) {
            element.classList.add("saeng-r2-empty");
        }
    });
})();
</script>
<!-- SAENG_LAYOUT_POLIMENTO_R2_END -->
'@

    if ($Login -notmatch '(?i)</body>') {
        throw "A tag de fechamento BODY nao foi encontrada."
    }

    $Login = [regex]::Replace($Login, '(?i)</body>', ($Patch + "`r`n</body>"), 1)
    Set-Content $LoginPath $Login -Encoding UTF8

    Write-Step "Validando o polimento aplicado"
    $Saved = Get-Content $LoginPath -Raw -Encoding UTF8
    if ($Saved -notmatch 'SAENG_LAYOUT_POLIMENTO_R2_START') {
        throw "O marcador do polimento R2 nao foi gravado."
    }
    if ($Saved -match 'splash-saeng\.png|abertura-saeng\.png') {
        throw "Ainda existe referencia ao mockup ou splash no login."
    }
    if ($Saved -notmatch '/static/login-final\.css\?v=20260724-r2') {
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

    $Report = Join-Path $Root "docs\RELATORIO_LAYOUT_R2.txt"
    @"
SAENG SOFTWARE SST V2 - RELATORIO DE POLIMENTO R2
Data: $(Get-Date -Format "dd/MM/yyyy HH:mm:ss")
Projeto: $Root
Backup: $BackupDir
Titulos duplicados removidos em tempo de execucao: SIM
Aviso de seguranca duplicado removido: SIM
Cartao ajustado para a altura da tela: SIM
Mockup e splash ausentes: SIM
Compilacao: APROVADA
Testes: APROVADOS
"@ | Set-Content $Report -Encoding UTF8

    Write-Host ""
    Write-Host "======================================================" -ForegroundColor DarkBlue
    Write-Host " POLIMENTO VISUAL R2 APLICADO E VALIDADO" -ForegroundColor Green
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
                $Response = Invoke-WebRequest -Uri "http://127.0.0.1:8765/login?v=layout-r2" -UseBasicParsing -TimeoutSec 2
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
        Start-Process "http://127.0.0.1:8765/login?v=layout-r2"
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
