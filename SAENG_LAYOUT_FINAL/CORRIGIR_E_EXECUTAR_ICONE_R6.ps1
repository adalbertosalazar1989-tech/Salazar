#requires -Version 5.1
[CmdletBinding()]
param(
    [string]$Root = "C:\SAENG_Software_SST_V2"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$Desktop = [Environment]::GetFolderPath("Desktop")
$WorkDir = Join-Path $Desktop "SAENG_ICONE_R6_CORRIGIDO"
$OriginalUrl = "https://raw.githubusercontent.com/adalbertosalazar1989-tech/Salazar/main/SAENG_LAYOUT_FINAL/AJUSTAR_ICONE_DESKTOP_R6.ps1"
$OriginalPath = Join-Path $WorkDir "AJUSTAR_ICONE_DESKTOP_R6_ORIGINAL.ps1"
$FixedPath = Join-Path $WorkDir "AJUSTAR_ICONE_DESKTOP_R6_CORRIGIDO.ps1"

Write-Host "======================================================" -ForegroundColor DarkBlue
Write-Host " SAENG SOFTWARE SST V2 - CORRECAO DO ICONE R6" -ForegroundColor Yellow
Write-Host "======================================================" -ForegroundColor DarkBlue

New-Item -ItemType Directory -Path $WorkDir -Force | Out-Null

Write-Host ""
Write-Host "==> Baixando o script R6 original" -ForegroundColor Cyan
Invoke-WebRequest -UseBasicParsing $OriginalUrl -OutFile $OriginalPath
Unblock-File $OriginalPath -ErrorAction SilentlyContinue

$Content = Get-Content $OriginalPath -Raw -Encoding UTF8

$BrokenBlock = @'
                $Writer.Write([byte](if ($Size -eq 256) { 0 } else { $Size }))
                $Writer.Write([byte](if ($Size -eq 256) { 0 } else { $Size }))
'@

$FixedBlock = @'
                $DimensionByte = if ($Size -eq 256) { [byte]0 } else { [byte]$Size }
                $Writer.Write($DimensionByte)
                $Writer.Write($DimensionByte)
'@

if (-not $Content.Contains($BrokenBlock)) {
    throw "O bloco de sintaxe incorreta nao foi localizado no script R6."
}

$Content = $Content.Replace($BrokenBlock, $FixedBlock)
Set-Content -Path $FixedPath -Value $Content -Encoding UTF8
Unblock-File $FixedPath -ErrorAction SilentlyContinue

Write-Host "==> Validando a sintaxe PowerShell antes da execucao" -ForegroundColor Cyan
$Tokens = $null
$Errors = $null
[void][System.Management.Automation.Language.Parser]::ParseFile(
    $FixedPath,
    [ref]$Tokens,
    [ref]$Errors
)

if ($Errors.Count -gt 0) {
    $Message = ($Errors | ForEach-Object { $_.Message }) -join " | "
    throw "O script corrigido ainda possui erro de sintaxe: $Message"
}

Write-Host "Sintaxe validada." -ForegroundColor Green
Write-Host ""
Write-Host "==> Executando o ajuste do icone" -ForegroundColor Cyan
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $FixedPath -Root $Root

if ($LASTEXITCODE -ne 0) {
    throw "O ajuste do icone terminou com codigo $LASTEXITCODE."
}

$TargetIco = Join-Path $Root "app\static\saeng_desktop_icon_r6.ico"
$Shortcut = Join-Path $Desktop "SAENG Software SST.lnk"

if (-not (Test-Path $TargetIco)) {
    throw "O arquivo ICO final nao foi criado: $TargetIco"
}
if (-not (Test-Path $Shortcut)) {
    throw "O atalho final nao foi encontrado: $Shortcut"
}

Write-Host ""
Write-Host "======================================================" -ForegroundColor DarkBlue
Write-Host " CORRECAO R6 CONCLUIDA" -ForegroundColor Green
Write-Host "======================================================" -ForegroundColor DarkBlue
Write-Host "Icone: $TargetIco" -ForegroundColor White
Write-Host "Atalho: $Shortcut" -ForegroundColor White
Write-Host "Script corrigido: $FixedPath" -ForegroundColor Cyan
