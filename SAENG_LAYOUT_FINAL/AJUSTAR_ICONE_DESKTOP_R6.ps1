#requires -Version 5.1
[CmdletBinding()]
param(
    [string]$Root = "C:\SAENG_Software_SST_V2"
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

function Get-Median {
    param([int[]]$Values)
    if (-not $Values -or $Values.Count -eq 0) { return 0 }
    $Sorted = $Values | Sort-Object
    $Middle = [int][Math]::Floor($Sorted.Count / 2)
    if (($Sorted.Count % 2) -eq 0) {
        return [int][Math]::Round(($Sorted[$Middle - 1] + $Sorted[$Middle]) / 2.0)
    }
    return [int]$Sorted[$Middle]
}

$Desktop = [Environment]::GetFolderPath("Desktop")
$ShortcutPath = Join-Path $Desktop "SAENG Software SST.lnk"
$Pythonw = Join-Path $Root ".venv\Scripts\pythonw.exe"
$Launcher = Join-Path $Root "launcher\SAENG_Software_SST.pyw"
$StaticDir = Join-Path $Root "app\static"
$TargetPng = Join-Path $StaticDir "saeng_desktop_icon_r6.png"
$TargetIco = Join-Path $StaticDir "saeng_desktop_icon_r6.ico"
$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$BackupDir = Join-Path $Root "backup_icone_r6_$Timestamp"
$ReportPath = Join-Path $Root "docs\RELATORIO_ICONE_R6.txt"
$BackupReady = $false

$SourceCandidates = @(
    "C:\SAENG_TEMP\AREA-DE-TRABALHO.png",
    "C:\SAENG_TEMP\AREA-DE-TRABALHO.png.png",
    (Join-Path $Root "SAENG_IMAGENS_FINAIS\AREA-DE-TRABALHO.png"),
    (Join-Path $Root "app\static\AREA-DE-TRABALHO.png"),
    (Join-Path $Root "app\static\area-de-trabalho.png")
)

try {
    Write-Host "======================================================" -ForegroundColor DarkBlue
    Write-Host " SAENG SOFTWARE SST V2 - ICONE DE DESKTOP R6" -ForegroundColor Yellow
    Write-Host "======================================================" -ForegroundColor DarkBlue

    if (-not (Test-Path $Root)) {
        throw "Pasta do projeto nao encontrada: $Root"
    }
    if (-not (Test-Path $StaticDir)) {
        throw "Pasta static nao encontrada: $StaticDir"
    }
    if (-not (Test-Path $Pythonw)) {
        throw "pythonw.exe nao encontrado: $Pythonw"
    }
    if (-not (Test-Path $Launcher)) {
        throw "Launcher silencioso nao encontrado: $Launcher"
    }

    Write-Step "Localizando o arquivo AREA-DE-TRABALHO.png existente"
    $Source = $SourceCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1

    if (-not $Source) {
        $SearchRoots = @(
            $Desktop,
            (Join-Path $env:USERPROFILE "Pictures"),
            (Join-Path $env:USERPROFILE "Downloads")
        ) | Where-Object { Test-Path $_ }

        $Source = Get-ChildItem -Path $SearchRoots -Recurse -File -ErrorAction SilentlyContinue |
            Where-Object {
                $_.Name -match '^AREA-DE-TRABALHO.*\.png$'
            } |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1 -ExpandProperty FullName
    }

    if (-not $Source) {
        throw "O arquivo AREA-DE-TRABALHO.png nao foi localizado."
    }

    Write-Host "Fonte usada: $Source" -ForegroundColor White

    Write-Step "Criando backup reversivel"
    New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
    if (Test-Path $ShortcutPath) {
        Copy-Item $ShortcutPath (Join-Path $BackupDir "SAENG Software SST.lnk") -Force
    }
    if (Test-Path $TargetPng) {
        Copy-Item $TargetPng (Join-Path $BackupDir "saeng_desktop_icon_r6.png") -Force
    }
    if (Test-Path $TargetIco) {
        Copy-Item $TargetIco (Join-Path $BackupDir "saeng_desktop_icon_r6.ico") -Force
    }
    $BackupReady = $true
    Write-Ok "Backup criado: $BackupDir"

    Write-Step "Uniformizando as bordas e removendo pontas brancas"
    Add-Type -AssemblyName System.Drawing

    $SourceBitmap = [System.Drawing.Bitmap]::FromFile($Source)
    try {
        $SampleR = New-Object System.Collections.Generic.List[int]
        $SampleG = New-Object System.Collections.Generic.List[int]
        $SampleB = New-Object System.Collections.Generic.List[int]

        $StepX = [Math]::Max(1, [int]($SourceBitmap.Width / 80))
        $StepY = [Math]::Max(1, [int]($SourceBitmap.Height / 80))

        for ($Y = 0; $Y -lt $SourceBitmap.Height; $Y += $StepY) {
            for ($X = 0; $X -lt $SourceBitmap.Width; $X += $StepX) {
                $Pixel = $SourceBitmap.GetPixel($X, $Y)
                $Brightness = ([int]$Pixel.R + [int]$Pixel.G + [int]$Pixel.B) / 3
                $LooksNavy = (
                    $Pixel.A -ge 180 -and
                    $Brightness -lt 95 -and
                    $Pixel.B -ge $Pixel.R -and
                    $Pixel.B -ge ($Pixel.G - 18)
                )
                if ($LooksNavy) {
                    $SampleR.Add([int]$Pixel.R)
                    $SampleG.Add([int]$Pixel.G)
                    $SampleB.Add([int]$Pixel.B)
                }
            }
        }

        if ($SampleR.Count -ge 20) {
            $BgR = Get-Median -Values $SampleR.ToArray()
            $BgG = Get-Median -Values $SampleG.ToArray()
            $BgB = Get-Median -Values $SampleB.ToArray()
        }
        else {
            $BgR = 4
            $BgG = 24
            $BgB = 48
        }

        $Background = [System.Drawing.Color]::FromArgb(255, $BgR, $BgG, $BgB)
        Write-Host ("Azul uniforme aplicado: RGB({0},{1},{2})" -f $BgR, $BgG, $BgB) -ForegroundColor White

        $MasterSize = 1024
        $Master = New-Object System.Drawing.Bitmap $MasterSize, $MasterSize, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $Graphics = [System.Drawing.Graphics]::FromImage($Master)
        try {
            $Graphics.Clear($Background)
            $Graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceOver
            $Graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
            $Graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $Graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
            $Graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

            $Scale = [Math]::Min(
                $MasterSize / [double]$SourceBitmap.Width,
                $MasterSize / [double]$SourceBitmap.Height
            )
            $DrawWidth = [int][Math]::Round($SourceBitmap.Width * $Scale)
            $DrawHeight = [int][Math]::Round($SourceBitmap.Height * $Scale)
            $DrawX = [int](($MasterSize - $DrawWidth) / 2)
            $DrawY = [int](($MasterSize - $DrawHeight) / 2)
            $Graphics.DrawImage($SourceBitmap, $DrawX, $DrawY, $DrawWidth, $DrawHeight)
        }
        finally {
            $Graphics.Dispose()
        }

        $Edge = [int]($MasterSize * 0.11)
        for ($Y = 0; $Y -lt $MasterSize; $Y++) {
            for ($X = 0; $X -lt $MasterSize; $X++) {
                $NearEdge = (
                    $X -lt $Edge -or
                    $Y -lt $Edge -or
                    $X -ge ($MasterSize - $Edge) -or
                    $Y -ge ($MasterSize - $Edge)
                )
                if (-not $NearEdge) { continue }

                $Pixel = $Master.GetPixel($X, $Y)
                $NearWhite = (
                    $Pixel.A -lt 180 -or
                    ($Pixel.R -ge 220 -and $Pixel.G -ge 220 -and $Pixel.B -ge 220)
                )
                if ($NearWhite) {
                    $Master.SetPixel($X, $Y, $Background)
                }
            }
        }

        $Master.Save($TargetPng, [System.Drawing.Imaging.ImageFormat]::Png)

        Write-Step "Criando ICO multirresolucao com alta nitidez"
        $Sizes = @(256, 128, 64, 48, 32, 24, 16)
        $PngStreams = New-Object System.Collections.Generic.List[byte[]]

        foreach ($Size in $Sizes) {
            $Bitmap = New-Object System.Drawing.Bitmap $Size, $Size, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
            $G = [System.Drawing.Graphics]::FromImage($Bitmap)
            try {
                $G.Clear($Background)
                $G.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceOver
                $G.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
                $G.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
                $G.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
                $G.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
                $G.DrawImage($Master, 0, 0, $Size, $Size)
            }
            finally {
                $G.Dispose()
            }

            $Memory = New-Object System.IO.MemoryStream
            try {
                $Bitmap.Save($Memory, [System.Drawing.Imaging.ImageFormat]::Png)
                $PngStreams.Add($Memory.ToArray())
            }
            finally {
                $Bitmap.Dispose()
                $Memory.Dispose()
            }
        }

        $FileStream = [System.IO.File]::Open($TargetIco, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write)
        $Writer = New-Object System.IO.BinaryWriter $FileStream
        try {
            $Writer.Write([uint16]0)
            $Writer.Write([uint16]1)
            $Writer.Write([uint16]$Sizes.Count)

            $Offset = 6 + (16 * $Sizes.Count)
            for ($Index = 0; $Index -lt $Sizes.Count; $Index++) {
                $Size = [int]$Sizes[$Index]
                $Data = $PngStreams[$Index]
                $Writer.Write([byte](if ($Size -eq 256) { 0 } else { $Size }))
                $Writer.Write([byte](if ($Size -eq 256) { 0 } else { $Size }))
                $Writer.Write([byte]0)
                $Writer.Write([byte]0)
                $Writer.Write([uint16]1)
                $Writer.Write([uint16]32)
                $Writer.Write([uint32]$Data.Length)
                $Writer.Write([uint32]$Offset)
                $Offset += $Data.Length
            }

            foreach ($Data in $PngStreams) {
                $Writer.Write($Data)
            }
        }
        finally {
            $Writer.Dispose()
            $FileStream.Dispose()
        }

        $Master.Dispose()
    }
    finally {
        $SourceBitmap.Dispose()
    }

    if (-not (Test-Path $TargetPng)) {
        throw "O PNG uniforme nao foi criado."
    }
    if (-not (Test-Path $TargetIco)) {
        throw "O ICO uniforme nao foi criado."
    }

    $IconValidation = New-Object System.Drawing.Icon $TargetIco
    try {
        if ($IconValidation.Width -lt 16 -or $IconValidation.Height -lt 16) {
            throw "O arquivo ICO criado e invalido."
        }
    }
    finally {
        $IconValidation.Dispose()
    }

    Write-Ok "Icone uniforme criado: $TargetIco"

    Write-Step "Atualizando o atalho da Area de Trabalho"
    $Shell = New-Object -ComObject WScript.Shell

    if (Test-Path $ShortcutPath) {
        Remove-Item $ShortcutPath -Force
    }

    $Shortcut = $Shell.CreateShortcut($ShortcutPath)
    $Shortcut.TargetPath = $Pythonw
    $Shortcut.Arguments = "`"$Launcher`""
    $Shortcut.WorkingDirectory = $Root
    $Shortcut.IconLocation = "$TargetIco,0"
    $Shortcut.Description = "SAENG Software SST - Gestao eSocial e SST"
    $Shortcut.WindowStyle = 7
    $Shortcut.Save()
    Unblock-File -Path $ShortcutPath -ErrorAction SilentlyContinue

    if (-not (Test-Path $ShortcutPath)) {
        throw "O atalho nao foi recriado."
    }

    $ShortcutCheck = $Shell.CreateShortcut($ShortcutPath)
    if ($ShortcutCheck.IconLocation -notlike "*$TargetIco*") {
        throw "O atalho nao recebeu o novo icone."
    }

    Write-Step "Atualizando o cache de icones do Windows"
    Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class SaengShellRefresh {
    [DllImport("shell32.dll")]
    public static extern void SHChangeNotify(
        uint wEventId,
        uint uFlags,
        IntPtr dwItem1,
        IntPtr dwItem2
    );
}
"@
    [SaengShellRefresh]::SHChangeNotify(0x08000000, 0x0000, [IntPtr]::Zero, [IntPtr]::Zero)

    $Ie4uinit = Join-Path $env:WINDIR "System32\ie4uinit.exe"
    if (Test-Path $Ie4uinit) {
        Start-Process -FilePath $Ie4uinit -ArgumentList "-show" -WindowStyle Hidden -Wait -ErrorAction SilentlyContinue
    }

    @"
SAENG SOFTWARE SST V2 - RELATORIO DO ICONE R6
Data: $(Get-Date -Format "dd/MM/yyyy HH:mm:ss")
Projeto: $Root
Fonte original: $Source
PNG uniforme: $TargetPng
ICO multirresolucao: $TargetIco
Atalho: $ShortcutPath
Pontas brancas removidas: SIM
Cor das bordas uniformizada: SIM
Resolucao ICO: 256, 128, 64, 48, 32, 24 e 16 px
Launcher silencioso preservado: SIM
Backup: $BackupDir
"@ | Set-Content -Path $ReportPath -Encoding UTF8

    Write-Host ""
    Write-Host "======================================================" -ForegroundColor DarkBlue
    Write-Host " ICONE DE DESKTOP R6 APLICADO E VALIDADO" -ForegroundColor Green
    Write-Host "======================================================" -ForegroundColor DarkBlue
    Write-Host "Fonte: $Source" -ForegroundColor White
    Write-Host "Icone: $TargetIco" -ForegroundColor White
    Write-Host "Atalho: $ShortcutPath" -ForegroundColor White
    Write-Host "Backup: $BackupDir" -ForegroundColor Cyan
    Write-Host "Relatorio: $ReportPath" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "O ajuste reutilizou o arquivo AREA-DE-TRABALHO.png existente." -ForegroundColor Green
    Write-Host "Nenhuma nova imagem ou logomarca foi criada." -ForegroundColor Green
}
catch {
    Write-Host ""
    Write-Host "FALHA: $($_.Exception.Message)" -ForegroundColor Red
    if ($BackupReady) {
        Write-Host "Backup preservado em: $BackupDir" -ForegroundColor Yellow
    }
    throw
}
