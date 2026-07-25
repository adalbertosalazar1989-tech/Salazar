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

$AppDir = Join-Path $Root "app"
$TemplatesDir = Join-Path $AppDir "templates"
$StaticDir = Join-Path $AppDir "static"
$TargetLogo = Join-Path $StaticDir "logo_saeng_transparente.png"
$BrandCss = Join-Path $StaticDir "brand-final.css"
$BrandJs = Join-Path $StaticDir "brand-final.js"
$StartFile = Join-Path $Root "START_SAENG_SST.bat"
$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$BackupDir = Join-Path $Root "backup_identidade_r4_$Timestamp"
$BackupReady = $false

try {
    Write-Host "======================================================" -ForegroundColor DarkBlue
    Write-Host " SAENG SOFTWARE SST V2 - IDENTIDADE INTERNA R4" -ForegroundColor Yellow
    Write-Host "======================================================" -ForegroundColor DarkBlue

    if (-not (Test-Path $Root)) {
        throw "Pasta do projeto nao encontrada: $Root"
    }
    if (-not (Test-Path $TemplatesDir)) {
        throw "Pasta de templates nao encontrada: $TemplatesDir"
    }
    if (-not (Test-Path $StaticDir)) {
        New-Item -ItemType Directory -Path $StaticDir -Force | Out-Null
    }

    Write-Step "Encerrando somente a instancia SAENG na porta 8765"
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
    Copy-Item $TemplatesDir (Join-Path $BackupDir "templates") -Recurse -Force
    if (Test-Path $BrandCss) { Copy-Item $BrandCss (Join-Path $BackupDir "brand-final.css") -Force }
    if (Test-Path $BrandJs) { Copy-Item $BrandJs (Join-Path $BackupDir "brand-final.js") -Force }
    if (Test-Path $TargetLogo) { Copy-Item $TargetLogo (Join-Path $BackupDir "logo_saeng_transparente.png") -Force }
    $BackupReady = $true
    Write-Ok "Backup criado: $BackupDir"

    Write-Step "Localizando a marca atual ja existente no projeto"
    $Candidates = @(
        (Join-Path $StaticDir "logo_abertura_saeng.png"),
        (Join-Path $StaticDir "logo_saeng.png"),
        (Join-Path $StaticDir "saeng_logo.png"),
        "C:\SAENG_TEMP\AREA-DE-TRABALHO.png",
        "C:\SAENG_TEMP\AREA-DE-TRABALHO.png.png"
    )

    $SourceLogo = $Candidates | Where-Object { Test-Path $_ } | Select-Object -First 1

    if (-not $SourceLogo) {
        $SourceLogo = Get-ChildItem -Path "$env:USERPROFILE\Desktop", "$env:USERPROFILE\Pictures" -Recurse -File -ErrorAction SilentlyContinue |
            Where-Object {
                $_.Extension -match '^\.(png|jpg|jpeg)$' -and
                $_.Name -match '(?i)logo.*saeng|saeng.*logo|area-de-trabalho'
            } |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1 -ExpandProperty FullName
    }

    if (-not $SourceLogo) {
        throw "Nenhuma imagem da marca SAENG foi localizada."
    }

    Write-Host "Fonte selecionada: $SourceLogo" -ForegroundColor White

    Write-Step "Criando PNG com fundo transparente e somente o monograma dourado"
    Add-Type -AssemblyName System.Drawing

    $SourceBitmap = [System.Drawing.Bitmap]::FromFile($SourceLogo)
    try {
        $Working = New-Object System.Drawing.Bitmap $SourceBitmap.Width, $SourceBitmap.Height, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $Graphics = [System.Drawing.Graphics]::FromImage($Working)
        try {
            $Graphics.DrawImage($SourceBitmap, 0, 0, $SourceBitmap.Width, $SourceBitmap.Height)
        }
        finally {
            $Graphics.Dispose()
        }

        $MinX = $Working.Width
        $MinY = $Working.Height
        $MaxX = -1
        $MaxY = -1

        for ($Y = 0; $Y -lt $Working.Height; $Y++) {
            for ($X = 0; $X -lt $Working.Width; $X++) {
                $Pixel = $Working.GetPixel($X, $Y)
                $R = [int]$Pixel.R
                $G = [int]$Pixel.G
                $B = [int]$Pixel.B

                $IsGold = (
                    $R -ge 70 -and
                    $R -gt ($B + 28) -and
                    $G -gt ($B + 6) -and
                    $R -ge $G
                )

                if ($IsGold) {
                    $Brightness = [Math]::Min(255, [Math]::Max(80, [int](($R + $G) / 2)))
                    $Working.SetPixel($X, $Y, [System.Drawing.Color]::FromArgb($Brightness, $R, $G, $B))
                    if ($X -lt $MinX) { $MinX = $X }
                    if ($Y -lt $MinY) { $MinY = $Y }
                    if ($X -gt $MaxX) { $MaxX = $X }
                    if ($Y -gt $MaxY) { $MaxY = $Y }
                }
                else {
                    $Working.SetPixel($X, $Y, [System.Drawing.Color]::Transparent)
                }
            }
        }

        if ($MaxX -lt $MinX -or $MaxY -lt $MinY) {
            throw "Nao foi possivel isolar o monograma dourado da imagem fonte."
        }

        $CropWidth = $MaxX - $MinX + 1
        $CropHeight = $MaxY - $MinY + 1
        $CropRect = New-Object System.Drawing.Rectangle $MinX, $MinY, $CropWidth, $CropHeight
        $Cropped = $Working.Clone($CropRect, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        try {
            $CanvasSize = 512
            $Padding = 40
            $Canvas = New-Object System.Drawing.Bitmap $CanvasSize, $CanvasSize, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
            $Canvas.SetResolution(96, 96)
            $CanvasGraphics = [System.Drawing.Graphics]::FromImage($Canvas)
            try {
                $CanvasGraphics.Clear([System.Drawing.Color]::Transparent)
                $CanvasGraphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceOver
                $CanvasGraphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
                $CanvasGraphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
                $CanvasGraphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
                $CanvasGraphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

                $MaxSide = $CanvasSize - (2 * $Padding)
                $Scale = [Math]::Min($MaxSide / [double]$Cropped.Width, $MaxSide / [double]$Cropped.Height)
                $DrawWidth = [int][Math]::Round($Cropped.Width * $Scale)
                $DrawHeight = [int][Math]::Round($Cropped.Height * $Scale)
                $DrawX = [int](($CanvasSize - $DrawWidth) / 2)
                $DrawY = [int](($CanvasSize - $DrawHeight) / 2)
                $CanvasGraphics.DrawImage($Cropped, $DrawX, $DrawY, $DrawWidth, $DrawHeight)
            }
            finally {
                $CanvasGraphics.Dispose()
            }

            $Canvas.Save($TargetLogo, [System.Drawing.Imaging.ImageFormat]::Png)
            $Canvas.Dispose()
        }
        finally {
            $Cropped.Dispose()
        }
    }
    finally {
        if ($Working) { $Working.Dispose() }
        $SourceBitmap.Dispose()
    }

    if (-not (Test-Path $TargetLogo)) {
        throw "A logo transparente nao foi criada."
    }
    Write-Ok "Logo transparente criada: $TargetLogo"

    Write-Step "Criando padrao visual interno da marca"
    $Css = @'
/* SAENG IDENTIDADE INTERNA R4 */
:root {
    --saeng-brand-gold: #d8a928;
    --saeng-brand-navy: #071d35;
}

.saeng-brand-logo,
.saeng-sidebar-logo,
.sidebar-brand-logo,
.app-brand-logo,
.navbar-brand-logo,
.brand-logo,
.logo-mark,
.brand-mark,
.sidebar-logo {
    background: transparent !important;
    border: 0 !important;
    box-shadow: none !important;
}

.saeng-brand-logo img,
.saeng-sidebar-logo img,
.sidebar-brand-logo img,
.app-brand-logo img,
.navbar-brand-logo img,
.brand-logo img,
.logo-mark img,
.brand-mark img,
.sidebar-logo img,
img[data-saeng-brand="current"] {
    display: block !important;
    width: 100% !important;
    height: 100% !important;
    object-fit: contain !important;
    object-position: center !important;
    background: transparent !important;
    border: 0 !important;
    box-shadow: none !important;
}

.saeng-runtime-brand-logo {
    display: inline-flex !important;
    align-items: center !important;
    justify-content: center !important;
    width: 54px !important;
    height: 54px !important;
    min-width: 54px !important;
    background: transparent !important;
    border: 0 !important;
    box-shadow: none !important;
    overflow: visible !important;
}

.saeng-runtime-brand-logo img {
    width: 100% !important;
    height: 100% !important;
    object-fit: contain !important;
    background: transparent !important;
}

@media (max-width: 900px) {
    .saeng-runtime-brand-logo {
        width: 46px !important;
        height: 46px !important;
        min-width: 46px !important;
    }
}
'@
    Set-Content $BrandCss $Css -Encoding UTF8

    $Js = @'
(function () {
    "use strict";

    var CURRENT_LOGO = "/static/logo_saeng_transparente.png?v=20260724-r4";
    var LEGACY_PATTERN = /(logo|brand|saeng|software[-_ ]?sst|mark)/i;

    function normalize(value) {
        return (value || "").replace(/\s+/g, " ").trim();
    }

    function replaceImage(image) {
        var signature = [
            image.getAttribute("src") || "",
            image.getAttribute("alt") || "",
            image.id || "",
            image.className || ""
        ].join(" ");

        if (!LEGACY_PATTERN.test(signature)) {
            return;
        }
        if (/favicon|certificate|certificado|worker|avatar|user/i.test(signature)) {
            return;
        }

        image.src = CURRENT_LOGO;
        image.setAttribute("data-saeng-brand", "current");
        image.alt = "SAENG Software SST";
    }

    function replaceExactSS(element) {
        if (normalize(element.textContent) !== "SS") {
            return;
        }

        var scope = element.closest(
            "[class*='brand'],[class*='logo'],[class*='sidebar'],[class*='nav'],header,[id*='brand'],[id*='logo']"
        );
        if (!scope) {
            return;
        }

        element.classList.add("saeng-runtime-brand-logo");
        element.innerHTML = '<img src="' + CURRENT_LOGO + '" alt="SAENG Software SST">';
    }

    function replaceBackground(element) {
        var style = window.getComputedStyle(element);
        var background = style.backgroundImage || "";
        if (background === "none" || !LEGACY_PATTERN.test(background)) {
            return;
        }
        if (/certificate|certificado|avatar|user/i.test(background)) {
            return;
        }
        element.style.backgroundImage = 'url("' + CURRENT_LOGO + '")';
        element.style.backgroundColor = "transparent";
        element.style.backgroundSize = "contain";
        element.style.backgroundRepeat = "no-repeat";
        element.style.backgroundPosition = "center";
    }

    function applyBrand() {
        Array.prototype.forEach.call(document.images, replaceImage);

        var candidates = document.querySelectorAll(
            "span,div,a,strong,b,i,[class*='brand'],[class*='logo'],[class*='sidebar']"
        );
        Array.prototype.forEach.call(candidates, function (element) {
            replaceExactSS(element);
            replaceBackground(element);
        });

        var favicon = document.querySelector('link[rel~="icon"]');
        if (!favicon) {
            favicon = document.createElement("link");
            favicon.rel = "icon";
            document.head.appendChild(favicon);
        }
        favicon.type = "image/png";
        favicon.href = CURRENT_LOGO;
    }

    applyBrand();

    var observer = new MutationObserver(function () {
        applyBrand();
    });
    observer.observe(document.documentElement, {
        childList: true,
        subtree: true,
        attributes: true,
        attributeFilter: ["src", "class", "style"]
    });
})();
'@
    Set-Content $BrandJs $Js -Encoding UTF8

    Write-Step "Integrando a identidade em todos os templates"
    $HtmlFiles = @(Get-ChildItem $TemplatesDir -Recurse -File -Filter "*.html")
    $ChangedFiles = New-Object System.Collections.Generic.List[string]

    foreach ($File in $HtmlFiles) {
        $Original = Get-Content $File.FullName -Raw -Encoding UTF8
        $Updated = $Original

        $Updated = [regex]::Replace(
            $Updated,
            '(?is)<!-- SAENG_IDENTIDADE_R4_START -->.*?<!-- SAENG_IDENTIDADE_R4_END -->',
            ''
        )

        $HeadPatch = @'
<!-- SAENG_IDENTIDADE_R4_START -->
<link rel="icon" type="image/png" href="/static/logo_saeng_transparente.png?v=20260724-r4">
<link rel="stylesheet" href="/static/brand-final.css?v=20260724-r4">
<!-- SAENG_IDENTIDADE_R4_END -->
'@

        $BodyPatch = @'
<!-- SAENG_IDENTIDADE_R4_START -->
<script defer src="/static/brand-final.js?v=20260724-r4"></script>
<!-- SAENG_IDENTIDADE_R4_END -->
'@

        if ($Updated -match '(?i)</head>') {
            $Updated = [regex]::Replace($Updated, '(?i)</head>', ($HeadPatch + "`r`n</head>"), 1)
        }
        if ($Updated -match '(?i)</body>') {
            $Updated = [regex]::Replace($Updated, '(?i)</body>', ($BodyPatch + "`r`n</body>"), 1)
        }

        if ($Updated -ne $Original) {
            Set-Content $File.FullName $Updated -Encoding UTF8
            [void]$ChangedFiles.Add($File.FullName)
        }
    }

    Write-Step "Validando arquivos e executando testes"
    if (-not (Test-Path $BrandCss) -or -not (Test-Path $BrandJs) -or -not (Test-Path $TargetLogo)) {
        throw "Os arquivos da identidade R4 nao foram criados corretamente."
    }

    $Python = Join-Path $Root ".venv\Scripts\python.exe"
    if (-not (Test-Path $Python)) {
        throw "Python virtual nao encontrado: $Python"
    }

    Push-Location $Root
    try {
        & $Python -m compileall -q app tests
        if ($LASTEXITCODE -ne 0) { throw "Falha na compilacao Python." }
        & $Python -m pytest -q
        if ($LASTEXITCODE -ne 0) { throw "Os testes automatizados falharam." }
    }
    finally {
        Pop-Location
    }

    $Report = Join-Path $Root "docs\RELATORIO_IDENTIDADE_R4.txt"
    @"
SAENG SOFTWARE SST V2 - RELATORIO IDENTIDADE INTERNA R4
Data: $(Get-Date -Format "dd/MM/yyyy HH:mm:ss")
Projeto: $Root
Backup: $BackupDir
Logo fonte: $SourceLogo
Logo transparente: $TargetLogo
Templates integrados: $($ChangedFiles.Count)
CSS de marca: $BrandCss
JS de marca: $BrandJs
Compilacao: APROVADA
Testes: APROVADOS
"@ | Set-Content $Report -Encoding UTF8

    Write-Host ""
    Write-Host "======================================================" -ForegroundColor DarkBlue
    Write-Host " IDENTIDADE INTERNA R4 APLICADA E VALIDADA" -ForegroundColor Green
    Write-Host "======================================================" -ForegroundColor DarkBlue
    Write-Host "Logo transparente: $TargetLogo" -ForegroundColor White
    Write-Host "Templates atualizados: $($ChangedFiles.Count)" -ForegroundColor White
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
                $Response = Invoke-WebRequest -Uri "http://127.0.0.1:8765/login?v=identidade-r4" -UseBasicParsing -TimeoutSec 2
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
        Write-Ok "Servidor iniciado e pagina respondeu HTTP 200."
        Start-Process "http://127.0.0.1:8765/login?v=identidade-r4"
    }
}
catch {
    Write-Host ""
    Write-Host "FALHA: $($_.Exception.Message)" -ForegroundColor Red
    if ($BackupReady) {
        if (Test-Path (Join-Path $BackupDir "templates")) {
            Remove-Item $TemplatesDir -Recurse -Force
            Copy-Item (Join-Path $BackupDir "templates") $TemplatesDir -Recurse -Force
        }
        if (Test-Path (Join-Path $BackupDir "brand-final.css")) {
            Copy-Item (Join-Path $BackupDir "brand-final.css") $BrandCss -Force
        }
        if (Test-Path (Join-Path $BackupDir "brand-final.js")) {
            Copy-Item (Join-Path $BackupDir "brand-final.js") $BrandJs -Force
        }
        if (Test-Path (Join-Path $BackupDir "logo_saeng_transparente.png")) {
            Copy-Item (Join-Path $BackupDir "logo_saeng_transparente.png") $TargetLogo -Force
        }
        Write-Host "Rollback concluido. Os arquivos anteriores foram restaurados." -ForegroundColor Green
    }
    throw
}
