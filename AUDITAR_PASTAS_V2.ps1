param(
    [Parameter(Mandatory=$true)]
    [string]$Root
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = (Resolve-Path $Root).Path
$Docs = Join-Path $Root "docs"
New-Item -ItemType Directory -Path $Docs -Force | Out-Null
$Report = Join-Path $Docs "RELATORIO_AUDITORIA_PASTAS_V2.txt"
$Manifest = Join-Path $Root "MANIFEST_SHA256_V2.txt"

$RequiredFiles = @(
    "app\main.py",
    "app\config.py",
    "app\database.py",
    "app\models.py",
    "app\v2_extensions.py",
    "requirements.txt",
    "START_SAENG_SST.bat",
    "EXECUTAR_TESTES.bat",
    "scripts\AUDITAR_PASTAS_V2.ps1",
    "docs\DOSSIE_COMPLETO_V2.md"
)

$RequiredDirectories = @(
    "app",
    "app\templates",
    "app\static",
    "app\esocial",
    "schemas",
    "storage",
    "storage\documents",
    "storage\uploads",
    "storage\xml",
    "storage\reports",
    "storage\backups",
    "storage\logs",
    "storage\temp",
    "imports\references",
    "docs",
    "docs\evidencias",
    "docs\manuais",
    "scripts",
    "tests"
)

$MissingFiles = @()
$MissingDirectories = @()
$EmptyFixed = @()
$Forbidden = @()
$Warnings = @()

foreach ($Relative in $RequiredDirectories) {
    $Path = Join-Path $Root $Relative
    if (-not (Test-Path $Path -PathType Container)) {
        $MissingDirectories += $Relative
        continue
    }
    $Children = @(Get-ChildItem $Path -Force -ErrorAction SilentlyContinue)
    if ($Children.Count -eq 0) {
        Set-Content -Path (Join-Path $Path ".keep") -Value "Diretorio operacional preservado pelo SAENG Software SST V2." -Encoding UTF8
        $EmptyFixed += $Relative
    }
}

foreach ($Relative in $RequiredFiles) {
    if (-not (Test-Path (Join-Path $Root $Relative) -PathType Leaf)) {
        $MissingFiles += $Relative
    }
}

Get-ChildItem $Root -Recurse -Force -File -ErrorAction SilentlyContinue | ForEach-Object {
    if ($_.FullName -match "\\.venv\\" -or $_.FullName -match "\\.git\\") { return }
    if ($_.Extension.ToLowerInvariant() -in @(".pfx", ".p12", ".pem", ".key")) {
        $Forbidden += $_.FullName.Substring($Root.Length).TrimStart("\\")
    }
    if ($_.Name -match "(?i)senha.*\.txt$|password.*\.txt$|secret.*\.txt$") {
        $Warnings += "Possivel arquivo de segredo: " + $_.FullName.Substring($Root.Length).TrimStart("\\")
    }
}

$ManifestLines = @()
Get-ChildItem $Root -Recurse -Force -File -ErrorAction SilentlyContinue |
    Where-Object {
        $_.FullName -notmatch "\\.venv\\" -and
        $_.FullName -notmatch "\\.git\\" -and
        $_.FullName -notmatch "\\__pycache__\\" -and
        $_.FullName -notmatch "\\.pytest_cache\\" -and
        $_.FullName -ne $Manifest
    } |
    Sort-Object FullName |
    ForEach-Object {
        $Hash = (Get-FileHash $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        $Relative = $_.FullName.Substring($Root.Length).TrimStart("\\")
        $ManifestLines += "$Hash  $Relative"
    }
Set-Content -Path $Manifest -Value $ManifestLines -Encoding UTF8

$Lines = @()
$Lines += "SAENG SOFTWARE SST V2 - RELATORIO DE AUDITORIA ESTRUTURAL"
$Lines += "Data: $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')"
$Lines += "Raiz: $Root"
$Lines += ""
$Lines += "ARQUIVOS OBRIGATORIOS AUSENTES: $($MissingFiles.Count)"
$Lines += ($MissingFiles | ForEach-Object { "- $_" })
$Lines += ""
$Lines += "DIRETORIOS OBRIGATORIOS AUSENTES: $($MissingDirectories.Count)"
$Lines += ($MissingDirectories | ForEach-Object { "- $_" })
$Lines += ""
$Lines += "DIRETORIOS VAZIOS CORRIGIDOS COM .keep: $($EmptyFixed.Count)"
$Lines += ($EmptyFixed | ForEach-Object { "- $_" })
$Lines += ""
$Lines += "ARQUIVOS SECRETOS PROIBIDOS ENCONTRADOS: $($Forbidden.Count)"
$Lines += ($Forbidden | ForEach-Object { "- $_" })
$Lines += ""
$Lines += "AVISOS: $($Warnings.Count)"
$Lines += ($Warnings | ForEach-Object { "- $_" })
$Lines += ""
$Lines += "MANIFESTO SHA-256: $Manifest"
$Lines += "TOTAL DE ARQUIVOS NO MANIFESTO: $($ManifestLines.Count)"

$Ok = $MissingFiles.Count -eq 0 -and $MissingDirectories.Count -eq 0 -and $Forbidden.Count -eq 0
$Lines += ""
$Lines += if ($Ok) { "RESULTADO: APROVADO" } else { "RESULTADO: REPROVADO" }
Set-Content -Path $Report -Value $Lines -Encoding UTF8

Write-Host ($Lines -join [Environment]::NewLine)
if (-not $Ok) { exit 1 }
exit 0
