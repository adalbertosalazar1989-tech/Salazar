param(
    [string]$OrigemAtual = "C:\SAENG_Software_SST",
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

function Aviso([string]$Texto) {
    Write-Host "AVISO: $Texto" -ForegroundColor Yellow
}

function Encontrar-Python {
    $candidatos = @(
        @{Comando="py"; Args=@("-3.11")},
        @{Comando="py"; Args=@("-3")},
        @{Comando="python"; Args=@()}
    )
    foreach ($item in $candidatos) {
        try {
            & $item.Comando @($item.Args) --version *> $null
            if ($LASTEXITCODE -eq 0) { return $item }
        } catch {}
    }
    throw "Python 3.11 ou superior nao encontrado. Instale o Python e marque Add Python to PATH."
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
        } else {
            $linha
        }
    }
    if (-not $encontrou) { $novas += "$Nome=$Valor" }
    Set-Content -Path $Arquivo -Value $novas -Encoding UTF8
}

function Garantir-Pasta([string]$Caminho) {
    New-Item -ItemType Directory -Path $Caminho -Force | Out-Null
    $itens = @(Get-ChildItem -Path $Caminho -Force -ErrorAction SilentlyContinue)
    if ($itens.Count -eq 0) {
        Set-Content -Path (Join-Path $Caminho ".keep") -Value "Diretorio operacional preservado pelo SAENG Software SST V2." -Encoding UTF8
    }
}

function Copiar-Referencias([string[]]$Raizes, [string]$PastaDestino) {
    $extensoes = @("*.xlsx", "*.xlsm", "*.pdf", "*.txt", "*.md", "*.png", "*.jpg", "*.jpeg", "*.webp")
    $copiados = 0
    foreach ($raiz in $Raizes | Select-Object -Unique) {
        if (-not (Test-Path $raiz)) { continue }
        foreach ($filtro in $extensoes) {
            Get-ChildItem -Path $raiz -Filter $filtro -File -ErrorAction SilentlyContinue | ForEach-Object {
                $nome = $_.Name
                if ($nome -match "(?i)senha|password|secret") {
                    Aviso "Arquivo ignorado por conter indicacao de segredo no nome: $nome"
                    return
                }
                Copy-Item $_.FullName (Join-Path $PastaDestino $nome) -Force
                $copiados++
            }
        }
        Get-ChildItem -Path $raiz -Include *.pfx,*.p12,*.pem,*.key -File -ErrorAction SilentlyContinue | ForEach-Object {
            Aviso "Certificado/chave NAO copiado para a V2: $($_.Name)"
        }
    }
    return $copiados
}

function Aplicar-Correcao-Autenticacao([string]$MainPy) {
    if (-not (Test-Path $MainPy)) { throw "app\main.py nao encontrado na instalacao copiada." }
    $texto = Get-Content $MainPy -Raw -Encoding UTF8
    $blocoAntigo = @'
def require_login(request: Request) -> str:
    user = current_user(request)
    if not user:
        raise HTTPException(status_code=401)
    if settings.certificate_login_required and not current_certificate(request):
        raise HTTPException(status_code=401)
    return user
'@
    $blocoNovo = @'
def require_login(request: Request) -> str:
    """Exige uma sessao autenticada, sem transformar o A1 em requisito global.

    O certificado permanece obrigatorio apenas nas rotinas de assinatura,
    prontidao e transmissao que realmente dependem dele.
    """
    user = current_user(request)
    if not user:
        raise HTTPException(status_code=401)
    return user
'@
    if ($texto.Contains($blocoAntigo)) {
        $texto = $texto.Replace($blocoAntigo, $blocoNovo)
        Set-Content $MainPy -Value $texto -Encoding UTF8
        Write-Host "Correcao de autenticacao aplicada." -ForegroundColor Green
    } elseif ($texto -match "def require_login" -and $texto -notmatch "certificate_login_required") {
        Write-Host "Correcao de autenticacao ja estava aplicada." -ForegroundColor Green
    } else {
        Aviso "O bloco exato de require_login nao foi localizado. A instalacao sera interrompida para evitar patch inseguro."
        throw "Nao foi possivel aplicar a correcao de autenticacao com seguranca."
    }
}

function Integrar-Extensao-V2([string]$MainPy, [string]$ExtensaoOrigem, [string]$ExtensaoDestino) {
    if (-not (Test-Path $ExtensaoOrigem)) { throw "v2_extensions.py ausente no pacote do instalador." }
    Copy-Item $ExtensaoOrigem $ExtensaoDestino -Force
    $texto = Get-Content $MainPy -Raw -Encoding UTF8
    $marcador = "# SAENG_V2_EXTENSION_REGISTERED"
    if ($texto -notmatch [regex]::Escape($marcador)) {
        $registro = @'

# SAENG_V2_EXTENSION_REGISTERED
try:
    from .v2_extensions import router as v2_router
    app.include_router(v2_router)
except Exception as exc:
    import logging
    logging.getLogger("saeng.v2").exception("Falha ao carregar extensao V2: %s", exc)
'@
        Add-Content -Path $MainPy -Value $registro -Encoding UTF8
    }
}

function Aplicar-Identidade([string]$DestinoRaiz, [string[]]$Raizes) {
    $static = Join-Path $DestinoRaiz "app\static"
    Garantir-Pasta $static
    $logoCandidatos = @(
        "AREA-DE-TRABALHO.png(2).png", "AREA-DE-TRABALHO.png", "AREA-DE-TRABALHO.png(1).png", "AREA-DE-TRABALHO.png.png",
        "png(2).png", "logo_elegante_em_dourado_e_navy.png"
    )
    $aberturaCandidatos = @(
        "ABERTURA.png", "ABERTURA.png(1).png", "ABERTURA.png.png", "interface_de_login_saas_com_luxo.png"
    )
    $logo = $null
    $abertura = $null
    foreach ($raiz in $Raizes | Select-Object -Unique) {
        if (-not (Test-Path $raiz)) { continue }
        foreach ($nome in $logoCandidatos) {
            $p = Join-Path $raiz $nome
            if (-not $logo -and (Test-Path $p)) { $logo = $p }
        }
        foreach ($nome in $aberturaCandidatos) {
            $p = Join-Path $raiz $nome
            if (-not $abertura -and (Test-Path $p)) { $abertura = $p }
        }
    }
    if ($logo) {
        Copy-Item $logo (Join-Path $static "logo-saeng.png") -Force
        Write-Host "Logo aplicada: $logo" -ForegroundColor Green
    } else { Aviso "Logo PNG nao encontrada; o fallback existente sera mantido." }
    if ($abertura) {
        Copy-Item $abertura (Join-Path $static "abertura-saeng.png") -Force
        Write-Host "Imagem de abertura aplicada: $abertura" -ForegroundColor Green
    } else { Aviso "Imagem de abertura nao encontrada; o layout existente sera mantido." }

    $login = Join-Path $DestinoRaiz "app\templates\login.html"
    if (Test-Path $login) {
        $html = Get-Content $login -Raw -Encoding UTF8
        $html = $html.Replace('<div class="login-logo">SS</div>', '<img class="login-logo-image" src="/static/logo-saeng.png" alt="SAENG Software SST">')
        Set-Content $login -Value $html -Encoding UTF8
    }
    $cssFile = Join-Path $static "style.css"
    if (Test-Path $cssFile) {
        $css = Get-Content $cssFile -Raw -Encoding UTF8
        if ($css -notmatch "SAENG V2 PREMIUM IDENTITY") {
            Add-Content $cssFile -Encoding UTF8 -Value @'

/* SAENG V2 PREMIUM IDENTITY */
.login-logo-image{width:min(270px,72%);height:auto;display:block;filter:drop-shadow(0 18px 32px rgba(0,0,0,.28));margin-bottom:18px}
.brand img,.sidebar-logo{max-width:54px;height:auto;object-fit:contain}
.login-hero{background-image:linear-gradient(135deg,rgba(3,19,38,.97),rgba(7,43,78,.94)),url('/static/abertura-saeng.png');background-size:cover;background-position:center}
.login-panel{background:linear-gradient(145deg,#f8fafc,#eef3f8)}
.auth-card{border:1px solid rgba(8,34,63,.12);box-shadow:0 28px 70px rgba(3,19,38,.18)}
.btn.primary{background:linear-gradient(135deg,#dcb448,#b8871f);color:#081a30;box-shadow:0 10px 24px rgba(190,143,34,.24)}
.nav-item:hover,.nav-item.active{border-color:#cfa43d;background:rgba(207,164,61,.12)}
'@
        }
    }
}

Write-Host "======================================================" -ForegroundColor DarkBlue
Write-Host " SAENG SOFTWARE SST V2 - RECONSTRUCAO CONTROLADA" -ForegroundColor Yellow
Write-Host "======================================================" -ForegroundColor DarkBlue
Write-Host "O instalador e o ZIP final nao utilizam senha." -ForegroundColor Green
Write-Host "PFX/P12, senha e chave privada nao serao copiados." -ForegroundColor Green

$Pacote = Split-Path -Parent $MyInvocation.MyCommand.Path
$Data = Get-Date -Format "yyyyMMdd_HHmmss"
$BackupAtual = "C:\SAENG_Software_SST_BACKUP_V2_$Data"
$ZipFinal = "C:\SAENG_Software_SST_V2_FINAL.zip"
$Desktop = [Environment]::GetFolderPath("Desktop")
$Downloads = Join-Path $env:USERPROFILE "Downloads"
$RaizesReferencia = @(
    (Join-Path $Pacote "REFERENCIAS"),
    "C:\SAENG_TEMP",
    (Join-Path $Desktop "SAENG_TEMP"),
    $Pacote
)

Etapa "Validando a instalacao 0.3.2 existente"
$ObrigatoriosOrigem = @(
    "app\main.py", "app\config.py", "app\models.py", "app\database.py",
    "requirements.txt", "START_SAENG_SST.bat", "EXECUTAR_TESTES.bat", "tests"
)
if (-not (Test-Path $OrigemAtual)) {
    throw "A instalacao completa nao foi encontrada em $OrigemAtual. Nao exclua a versao antiga antes desta migracao."
}
foreach ($relativo in $ObrigatoriosOrigem) {
    if (-not (Test-Path (Join-Path $OrigemAtual $relativo))) {
        throw "Arquivo/pasta obrigatorio ausente na versao atual: $relativo"
    }
}

Etapa "Criando backup integral e reversivel"
New-Item -ItemType Directory -Path $BackupAtual -Force | Out-Null
$backupArgs = @($OrigemAtual, $BackupAtual, "/E", "/COPY:DAT", "/DCOPY:DAT", "/R:2", "/W:2", "/XD", ".venv", ".pytest_cache", "__pycache__", "/XF", "*.pfx", "*.p12", "*.pem", "*.key")
& robocopy @backupArgs | Out-Host
if ($LASTEXITCODE -gt 7) { throw "Falha ao criar backup com Robocopy. Codigo: $LASTEXITCODE" }

if (Test-Path $Destino) {
    $DestinoAnterior = "${Destino}_ANTERIOR_$Data"
    Etapa "Preservando V2 anterior em $DestinoAnterior"
    Move-Item $Destino $DestinoAnterior
}

Etapa "Copiando o nucleo completo da versao atual para a V2"
New-Item -ItemType Directory -Path $Destino -Force | Out-Null
$copyArgs = @($OrigemAtual, $Destino, "/E", "/COPY:DAT", "/DCOPY:DAT", "/R:2", "/W:2", "/XD", ".venv", ".pytest_cache", "__pycache__", "/XF", "*.pfx", "*.p12", "*.pem", "*.key")
& robocopy @copyArgs | Out-Host
if ($LASTEXITCODE -gt 7) { throw "Falha ao copiar o nucleo completo. Codigo: $LASTEXITCODE" }

Etapa "Aplicando correcoes de autenticacao e extensao V2"
$MainPy = Join-Path $Destino "app\main.py"
Aplicar-Correcao-Autenticacao $MainPy
Integrar-Extensao-V2 $MainPy (Join-Path $Pacote "v2_extensions.py") (Join-Path $Destino "app\v2_extensions.py")

Etapa "Configurando ambiente seguro por padrao"
$EnvFile = Join-Path $Destino ".env"
Definir-Env $EnvFile "APP_VERSION" "2.0.0-rc1"
Definir-Env $EnvFile "CERTIFICATE_LOGIN_REQUIRED" "false"
Definir-Env $EnvFile "TRANSMISSION_MODE" "MOCK"
Definir-Env $EnvFile "ALLOW_REAL_TRANSMISSION" "false"
Definir-Env $EnvFile "ALLOW_PRODUCTION_TRANSMISSION" "false"
Definir-Env $EnvFile "ESOCIAL_ENVIRONMENT" "2"
Definir-Env $EnvFile "CHECK_UPDATES_ON_START" "true"

Etapa "Criando a estrutura completa sem pastas vazias"
$Pastas = @(
    "imports\references", "storage\documents", "storage\uploads", "storage\xml", "storage\reports",
    "storage\backups", "storage\logs", "storage\temp", "docs\evidencias", "docs\manuais", "scripts"
)
foreach ($relativo in $Pastas) { Garantir-Pasta (Join-Path $Destino $relativo) }

Etapa "Copiando planilhas, manuais, imagens e evidencias locais"
$ReferenciaDestino = Join-Path $Destino "imports\references"
$Quantidade = Copiar-Referencias $RaizesReferencia $ReferenciaDestino
Write-Host "$Quantidade arquivo(s) de referencia copiado(s)." -ForegroundColor Green
Aplicar-Identidade $Destino $RaizesReferencia

Etapa "Copiando dossie e ferramentas de auditoria"
foreach ($arquivo in @("DOSSIE_COMPLETO_V2.md", "AUDITAR_PASTAS_V2.ps1", "build_icon.py")) {
    $origem = Join-Path $Pacote $arquivo
    if (-not (Test-Path $origem)) { throw "Arquivo do instalador ausente: $arquivo" }
}
Copy-Item (Join-Path $Pacote "DOSSIE_COMPLETO_V2.md") (Join-Path $Destino "docs\DOSSIE_COMPLETO_V2.md") -Force
Copy-Item (Join-Path $Pacote "AUDITAR_PASTAS_V2.ps1") (Join-Path $Destino "scripts\AUDITAR_PASTAS_V2.ps1") -Force
Copy-Item (Join-Path $Pacote "build_icon.py") (Join-Path $Destino "scripts\build_icon.py") -Force

Etapa "Localizando Python 3.11"
$Py = Encontrar-Python
Write-Host "Python selecionado: $($Py.Comando) $($Py.Args -join ' ')" -ForegroundColor Gray

Push-Location $Destino
try {
    Etapa "Criando ambiente virtual novo"
    & $Py.Comando @($Py.Args) -m venv .venv
    if ($LASTEXITCODE -ne 0) { throw "Falha ao criar ambiente virtual." }
    $PythonVenv = Join-Path $Destino ".venv\Scripts\python.exe"
    if (-not (Test-Path $PythonVenv)) { throw "Python do ambiente virtual nao encontrado." }

    Etapa "Instalando dependencias do nucleo completo"
    & $PythonVenv -m pip install --upgrade pip
    if ($LASTEXITCODE -ne 0) { throw "Falha ao atualizar pip." }
    & $PythonVenv -m pip install -r requirements.txt
    if ($LASTEXITCODE -ne 0) { throw "Falha ao instalar requirements.txt." }
    & $PythonVenv -m pip install "pypdf>=5,<7" "Pillow>=11,<13"
    if ($LASTEXITCODE -ne 0) { throw "Falha ao instalar complementos V2." }
    & $PythonVenv -m pip check
    if ($LASTEXITCODE -ne 0) { throw "Dependencias inconsistentes segundo pip check." }

    Etapa "Gerando icone do aplicativo"
    & $PythonVenv (Join-Path $Destino "scripts\build_icon.py") --root $Destino
    if ($LASTEXITCODE -ne 0) { Aviso "Nao foi possivel gerar o ICO; a aplicacao continuara com o icone padrao." }

    Etapa "Compilando todo o codigo Python"
    & $PythonVenv -m compileall -q app tests
    if ($LASTEXITCODE -ne 0) { throw "Falha de compilacao Python." }

    Etapa "Executando todos os testes automatizados"
    $RelatorioTestes = Join-Path $Destino "docs\RELATORIO_TESTES_V2.txt"
    & $PythonVenv -m pytest -q 2>&1 | Tee-Object -FilePath $RelatorioTestes
    if ($LASTEXITCODE -ne 0) {
        throw "Os testes falharam. O ZIP final nao sera criado. Consulte $RelatorioTestes"
    }

    Etapa "Indexando as referencias locais"
    $env:SAENG_V2_ROOT = $Destino
    & $PythonVenv -c "from app.v2_extensions import scan_reference_folder; print(scan_reference_folder())"
    if ($LASTEXITCODE -ne 0) { throw "Falha ao indexar planilhas e documentos locais." }

    Etapa "Auditando pasta por pasta e bloqueando segredos"
    powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Destino "scripts\AUDITAR_PASTAS_V2.ps1") -Root $Destino
    if ($LASTEXITCODE -ne 0) { throw "A auditoria estrutural encontrou falha impeditiva." }

    Etapa "Criando atalho na Area de Trabalho"
    $ShortcutPath = Join-Path $Desktop "SAENG Software SST V2.lnk"
    $Shell = New-Object -ComObject WScript.Shell
    $Shortcut = $Shell.CreateShortcut($ShortcutPath)
    $Shortcut.TargetPath = Join-Path $Destino "START_SAENG_SST.bat"
    $Shortcut.WorkingDirectory = $Destino
    $Shortcut.Description = "SAENG Software SST V2"
    $Icone = Join-Path $Destino "app\static\saeng.ico"
    if (Test-Path $Icone) { $Shortcut.IconLocation = "$Icone,0" }
    $Shortcut.Save()

    Etapa "Gerando ZIP local final sem senha"
    if (Test-Path $ZipFinal) { Remove-Item $ZipFinal -Force }
    $Staging = Join-Path $env:TEMP "SAENG_SST_V2_PACKAGE_$Data"
    if (Test-Path $Staging) { Remove-Item $Staging -Recurse -Force }
    New-Item -ItemType Directory -Path $Staging -Force | Out-Null
    $zipArgs = @($Destino, $Staging, "/E", "/COPY:DAT", "/R:1", "/W:1", "/XD", ".venv", ".pytest_cache", "__pycache__", "/XF", "*.pfx", "*.p12", "*.pem", "*.key")
    & robocopy @zipArgs | Out-Null
    if ($LASTEXITCODE -gt 7) { throw "Falha ao preparar o ZIP. Codigo: $LASTEXITCODE" }
    $ItensZip = Get-ChildItem $Staging -Force
    Compress-Archive -Path $ItensZip.FullName -DestinationPath $ZipFinal -CompressionLevel Optimal
    Remove-Item $Staging -Recurse -Force

    Write-Host ""
    Write-Host "======================================================" -ForegroundColor DarkBlue
    Write-Host " INSTALACAO V2 CONCLUIDA E TESTADA LOCALMENTE" -ForegroundColor Green
    Write-Host "======================================================" -ForegroundColor DarkBlue
    Write-Host "Pasta V2: $Destino" -ForegroundColor White
    Write-Host "Backup da versao atual: $BackupAtual" -ForegroundColor White
    Write-Host "ZIP sem senha: $ZipFinal" -ForegroundColor White
    Write-Host "Atalho: $ShortcutPath" -ForegroundColor White
    Write-Host "Endereco local: http://127.0.0.1:8765" -ForegroundColor White
    Write-Host "Modo inicial seguro: MOCK / tpAmb=2 / envio real bloqueado" -ForegroundColor Yellow
    Write-Host "A validacao oficial depende de Producao Restrita e recibo individual." -ForegroundColor Yellow

    if ($Iniciar) { Start-Process (Join-Path $Destino "START_SAENG_SST.bat") }
} finally {
    Pop-Location
}
