#requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$NoStart
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$Destination = Join-Path $env:USERPROFILE "Desktop\SAENG_FINAL_DEFINITIVO"
$BaseUrl = "https://raw.githubusercontent.com/adalbertosalazar1989-tech/Salazar/main/SAENG_FINAL_DEFINITIVO"
$Files = @(
    "README_PRIMEIRO.txt",
    "INSTALAR_SAENG_FINAL_DEFINITIVO.cmd",
    "finalizar_saeng.py",
    "DOSSIE_ERROS_E_SOLUCOES.md",
    "BASE_OFICIAL_ESOCIAL_2026.md",
    "CHECKLIST_HOMOLOGACAO_E_PRODUCAO.md"
)

if (Test-Path $Destination) {
    $Old = $Destination + "_ANTERIOR_" + (Get-Date -Format "yyyyMMdd_HHmmss")
    Move-Item -Path $Destination -Destination $Old -Force
}
New-Item -ItemType Directory -Path $Destination -Force | Out-Null

foreach ($File in $Files) {
    $Url = "$BaseUrl/$File"
    $Out = Join-Path $Destination $File
    Invoke-WebRequest -UseBasicParsing -Uri $Url -OutFile $Out
    Unblock-File -Path $Out -ErrorAction SilentlyContinue
}

$Required = @(
    "INSTALAR_SAENG_FINAL_DEFINITIVO.cmd",
    "finalizar_saeng.py"
)
foreach ($File in $Required) {
    if (-not (Test-Path (Join-Path $Destination $File))) {
        throw "Arquivo obrigatório não foi baixado: $File"
    }
}

Write-Host ""
Write-Host "PACOTE DEFINITIVO BAIXADO" -ForegroundColor Green
Write-Host "Pasta: $Destination" -ForegroundColor Cyan

if (-not $NoStart) {
    Start-Process -FilePath (Join-Path $Destination "INSTALAR_SAENG_FINAL_DEFINITIVO.cmd") -Verb RunAs
}
