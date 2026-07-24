param(
    [string]$Destino = "C:\SAENG_Software_SST_V2",
    [switch]$Iniciar
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Etapa([string]$Texto) {
    Write-Host ""
    Write-Host "==> $Texto" -ForegroundColor Cyan
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
    throw "Python 3 nao encontrado. Instale o Python 3.11 ou superior e marque Add Python to PATH."
}

Write-Host "==============================================" -ForegroundColor DarkBlue
Write-Host " SAENG SOFTWARE SST V2 - INSTALADOR LOCAL" -ForegroundColor Yellow
Write-Host "==============================================" -ForegroundColor DarkBlue
Write-Host "Este instalador e o ZIP do GitHub nao usam senha." -ForegroundColor Green

$Origem = Split-Path -Parent $MyInvocation.MyCommand.Path
$Data = Get-Date -Format "yyyyMMdd_HHmmss"

Etapa "Validando arquivos do pacote"
$Obrigatorios = @("app.py", "requirements.txt", "START_SAENG_V2.cmd", "TESTAR_SAENG_V2.cmd")
foreach ($arquivo in $Obrigatorios) {
    if (-not (Test-Path (Join-Path $Origem $arquivo))) {
        throw "Arquivo obrigatorio ausente: $arquivo"
    }
}

if (Test-Path $Destino) {
    $Backup = "${Destino}_BACKUP_$Data"
    Etapa "Preservando instalacao anterior em $Backup"
    Move-Item -Path $Destino -Destination $Backup
}

Etapa "Criando pasta final em $Destino"
New-Item -ItemType Directory -Path $Destino -Force | Out-Null
Get-ChildItem -Path $Origem -Force |
    Where-Object { $_.Name -notin @(".git", ".venv", "data", "__pycache__") } |
    Copy-Item -Destination $Destino -Recurse -Force
New-Item -ItemType Directory -Path (Join-Path $Destino "data") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $Destino "static") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $Destino "imports") -Force | Out-Null

Etapa "Copiando identidade visual e planilha, quando existentes"
$Temp = "C:\SAENG_TEMP"
if (Test-Path $Temp) {
    $mapa = @(
        @{Nomes=@("AREA-DE-TRABALHO.png", "AREA-DE-TRABALHO.png(1).png", "AREA-DE-TRABALHO.png.png"); Saida="logo-saeng.png"},
        @{Nomes=@("ABERTURA.png", "ABERTURA.png(1).png", "ABERTURA.png.png"); Saida="abertura.png"},
        @{Nomes=@("5. Planilha Mestra Riscos Ocupacionais SST - 2026.xlsx"); Saida="Planilha_Mestra_Riscos_2026.xlsx"},
        @{Nomes=@("MANUAL DE ORIENTACAO E-SOCIAL - COMPLETO 2026.pdf", "MANUAL DE ORIENTAÇÃO E-SOCIAL - COMPLETO 2026.pdf"); Saida="Manual_eSocial_2026.pdf"},
        @{Nomes=@("Texto colado(55).txt"); Saida="Tabelas_eSocial_S1.3_2026.txt"}
    )
    foreach ($grupo in $mapa) {
        foreach ($nome in $grupo.Nomes) {
            $origemItem = Join-Path $Temp $nome
            if (Test-Path $origemItem) {
                $pastaSaida = if ($grupo.Saida -match "\.(png)$") { "static" } else { "imports" }
                Copy-Item $origemItem (Join-Path (Join-Path $Destino $pastaSaida) $grupo.Saida) -Force
                break
            }
        }
    }
} else {
    Write-Host "C:\SAENG_TEMP nao localizada. A aplicacao funcionara sem os arquivos opcionais." -ForegroundColor Yellow
}

Etapa "Localizando Python"
$Py = Encontrar-Python
Write-Host "Comando selecionado: $($Py.Comando) $($Py.Args -join ' ')" -ForegroundColor Gray

Etapa "Criando ambiente virtual"
Push-Location $Destino
try {
    & $Py.Comando @($Py.Args) -m venv .venv
    if ($LASTEXITCODE -ne 0) { throw "Falha ao criar ambiente virtual." }

    $PythonVenv = Join-Path $Destino ".venv\Scripts\python.exe"
    if (-not (Test-Path $PythonVenv)) { throw "Python do ambiente virtual nao foi criado." }

    Etapa "Instalando dependencias"
    & $PythonVenv -m pip install --upgrade pip
    if ($LASTEXITCODE -ne 0) { throw "Falha ao atualizar pip." }
    & $PythonVenv -m pip install -r requirements.txt
    if ($LASTEXITCODE -ne 0) { throw "Falha ao instalar dependencias." }

    Etapa "Compilando codigo"
    & $PythonVenv -m compileall -q app.py tests
    if ($LASTEXITCODE -ne 0) { throw "Falha de compilacao." }

    Etapa "Executando testes"
    & $PythonVenv -m pytest -q
    $Teste = $LASTEXITCODE
    if ($Teste -ne 0) {
        throw "Os testes falharam. A pasta foi criada, mas nao deve ser usada ate a correcao."
    }

    Etapa "Criando atalho na Area de Trabalho"
    $Desktop = [Environment]::GetFolderPath("Desktop")
    $ShortcutPath = Join-Path $Desktop "SAENG Software SST V2.lnk"
    $Shell = New-Object -ComObject WScript.Shell
    $Shortcut = $Shell.CreateShortcut($ShortcutPath)
    $Shortcut.TargetPath = Join-Path $Destino "START_SAENG_V2.cmd"
    $Shortcut.WorkingDirectory = $Destino
    $Shortcut.Description = "SAENG Software SST V2"
    $Icone = Join-Path $Destino "static\logo-saeng.png"
    if (Test-Path $Icone) { $Shortcut.IconLocation = "$env:SystemRoot\System32\shell32.dll,14" }
    $Shortcut.Save()

    Etapa "Gerando ZIP final sem senha"
    $ZipFinal = "C:\SAENG_Software_SST_V2_FINAL.zip"
    if (Test-Path $ZipFinal) { Remove-Item $ZipFinal -Force }
    $ItensZip = Get-ChildItem $Destino -Force | Where-Object { $_.Name -ne ".venv" }
    Compress-Archive -Path $ItensZip.FullName -DestinationPath $ZipFinal -CompressionLevel Optimal

    Write-Host ""
    Write-Host "INSTALACAO CONCLUIDA" -ForegroundColor Green
    Write-Host "Pasta: $Destino" -ForegroundColor White
    Write-Host "ZIP sem senha: $ZipFinal" -ForegroundColor White
    Write-Host "Atalho: $ShortcutPath" -ForegroundColor White
    Write-Host "Endereco: http://127.0.0.1:8765" -ForegroundColor White

    if ($Iniciar) {
        Start-Process (Join-Path $Destino "START_SAENG_V2.cmd")
    }
} finally {
    Pop-Location
}
