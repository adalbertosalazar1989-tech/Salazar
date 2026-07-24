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
$LoginPath = Join-Path $TemplatesDir "login.html"
$FinalCssPath = Join-Path $StaticDir "login-final.css"
$StylePath = Join-Path $StaticDir "style.css"
$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$BackupDir = Join-Path $Root "backup_layout_final_$Timestamp"
$BackupReady = $false
$CssExisted = Test-Path $FinalCssPath

try {
    Write-Host "======================================================" -ForegroundColor DarkBlue
    Write-Host " SAENG SOFTWARE SST V2 - LAYOUT FINAL FUNCIONAL" -ForegroundColor Yellow
    Write-Host "======================================================" -ForegroundColor DarkBlue

    if (-not (Test-Path $Root)) {
        throw "Pasta do projeto nao encontrada: $Root"
    }
    if (-not (Test-Path $LoginPath)) {
        throw "Template de login nao encontrado: $LoginPath"
    }
    if (-not (Test-Path $StaticDir)) {
        New-Item -ItemType Directory -Path $StaticDir -Force | Out-Null
    }

    Write-Step "Encerrando apenas a instancia SAENG que estiver usando a porta 8765"
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
            throw "A porta 8765 esta ocupada por outro processo (PID $PidValue). Feche-o manualmente antes de continuar."
        }
        Stop-Process -Id $PidValue -Force -ErrorAction Stop
        Write-Host "Instancia anterior encerrada. PID: $PidValue" -ForegroundColor Yellow
    }

    Write-Step "Criando backup reversivel"
    New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
    Copy-Item -Path $LoginPath -Destination (Join-Path $BackupDir "login.html") -Force
    if (Test-Path $StylePath) {
        Copy-Item -Path $StylePath -Destination (Join-Path $BackupDir "style.css") -Force
    }
    if (Test-Path $FinalCssPath) {
        Copy-Item -Path $FinalCssPath -Destination (Join-Path $BackupDir "login-final.css") -Force
    }
    $BackupReady = $true
    Write-Ok "Backup criado: $BackupDir"

    Write-Step "Lendo e preservando os formularios reais"
    $CurrentLogin = Get-Content -Path $LoginPath -Raw -Encoding UTF8

    $FormRegex = [regex]::new(
        '<form\b[^>]*>.*?</form>',
        [System.Text.RegularExpressions.RegexOptions]::Singleline -bor
        [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
    )
    $FormMatches = @($FormRegex.Matches($CurrentLogin))
    if ($FormMatches.Count -lt 1) {
        throw "Nenhum formulario foi encontrado em login.html. O arquivo original foi preservado no backup."
    }

    $TypeFilePattern = 'type\s*=\s*["'']file["'']'
    $PasswordPattern = 'type\s*=\s*["'']password["'']'

    $CertificateForm = $null
    foreach ($Match in $FormMatches) {
        $Value = [string]$Match.Value
        if ($Value -match $TypeFilePattern -or $Value -match '(?i)pfx|p12|certificado') {
            $CertificateForm = $Value
            break
        }
    }
    if (-not $CertificateForm) {
        throw "O formulario real do certificado A1 nao foi identificado. Nenhuma substituicao foi mantida."
    }

    $LocalForm = $null
    foreach ($Match in $FormMatches) {
        $Value = [string]$Match.Value
        if ($Value -eq $CertificateForm) {
            continue
        }
        if ($Value -match $PasswordPattern -or $Value -match '(?i)recupera|acesso local|usuario|username') {
            $LocalForm = $Value
            break
        }
    }

    $CertificateAction = [regex]::Match($CertificateForm, '(?i)\baction\s*=\s*["'']([^"'']*)["'']').Groups[1].Value
    $CertificateMethod = [regex]::Match($CertificateForm, '(?i)\bmethod\s*=\s*["'']([^"'']*)["'']').Groups[1].Value
    $OriginalCertificateHash = [Convert]::ToBase64String(
        [Security.Cryptography.SHA256]::Create().ComputeHash(
            [Text.Encoding]::UTF8.GetBytes($CertificateForm)
        )
    )

    Write-Host "Formulario A1 preservado." -ForegroundColor Green
    Write-Host "Action: $CertificateAction"
    Write-Host "Method: $CertificateMethod"
    if ($LocalForm) {
        Write-Host "Formulario de recuperacao local preservado." -ForegroundColor Green
    }
    else {
        Write-Host "Formulario local nao localizado; a tela sera criada sem inventar rota ou credencial." -ForegroundColor Yellow
    }

    $LocalSection = ""
    if ($LocalForm) {
        $LocalSection = @'
<details class="saeng-local-access">
    <summary>
        <span class="saeng-summary-icon" aria-hidden="true">
            <svg viewBox="0 0 24 24"><path d="M12 2a5 5 0 0 0-5 5v3H5a2 2 0 0 0-2 2v8a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-8a2 2 0 0 0-2-2h-2V7a5 5 0 0 0-5-5Zm-3 8V7a3 3 0 0 1 6 0v3H9Z"/></svg>
        </span>
        <span>
            <strong>Acesso local de recuperação</strong>
            <small>Uso administrativo e manutenção local</small>
        </span>
        <span class="saeng-summary-chevron" aria-hidden="true">⌄</span>
    </summary>
    <div class="saeng-local-body">
        __LOCAL_FORM__
    </div>
</details>
'@
        $LocalSection = $LocalSection.Replace('__LOCAL_FORM__', $LocalForm)
    }

    Write-Step "Reconstruindo a tela com HTML real e sem mockup ou splash"
    $NewLogin = @'
<!doctype html>
<html lang="pt-BR">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
    <meta name="color-scheme" content="light">
    <meta name="theme-color" content="#071d35">
    <meta name="robots" content="noindex,nofollow">
    <title>Acesso — SAENG Software SST</title>
    <link rel="icon" href="/static/saeng_software_sst.ico">
    <link rel="stylesheet" href="/static/login-final.css?v=20260724-final">
</head>
<body class="saeng-login-page">
    <main class="saeng-login-shell">
        <section class="saeng-brand-panel" aria-labelledby="saeng-login-title">
            <div class="saeng-brand-glow saeng-brand-glow-one" aria-hidden="true"></div>
            <div class="saeng-brand-glow saeng-brand-glow-two" aria-hidden="true"></div>
            <div class="saeng-brand-line saeng-brand-line-top" aria-hidden="true"></div>
            <div class="saeng-brand-line saeng-brand-line-bottom" aria-hidden="true"></div>

            <div class="saeng-brand-content">
                <header class="saeng-brand-header">
                    <div class="saeng-logo-frame">
                        <img src="/static/logo_abertura_saeng.png" alt="SAENG Software SST">
                    </div>
                    <div class="saeng-company-name">
                        <span>SAENG Engenharia</span>
                        <span>e Consultoria</span>
                    </div>
                </header>

                <div class="saeng-brand-copy">
                    <p class="saeng-eyebrow">Plataforma integrada de gestão ocupacional</p>
                    <h1 id="saeng-login-title">
                        Gestão inteligente de
                        <span>eSocial SST.</span>
                    </h1>
                    <p class="saeng-description">
                        Cadastros multiempresa, documentos técnicos, trabalhadores, riscos ocupacionais,
                        eventos S-2210, S-2220, S-2240 e S-3000, XML, lotes, relatórios e trilha de auditoria.
                    </p>
                </div>

                <div class="saeng-feature-grid" aria-label="Recursos de segurança e operação">
                    <article class="saeng-feature-card">
                        <span class="saeng-feature-icon" aria-hidden="true">
                            <svg viewBox="0 0 24 24"><path d="M12 2 4 5v6c0 5.2 3.4 9.8 8 11 4.6-1.2 8-5.8 8-11V5l-8-3Zm0 3 5 1.9V11c0 3.7-2.2 7-5 8.1C9.2 18 7 14.7 7 11V6.9L12 5Zm-1.2 9.4-2.2-2.2-1.4 1.4 3.6 3.6 6-6-1.4-1.4-4.6 4.6Z"/></svg>
                        </span>
                        <span><strong>Certificado A1</strong><small>Processado somente em memória</small></span>
                    </article>
                    <article class="saeng-feature-card">
                        <span class="saeng-feature-icon" aria-hidden="true">
                            <svg viewBox="0 0 24 24"><path d="M17 8V7a5 5 0 0 0-10 0v1H5a2 2 0 0 0-2 2v10h18V10a2 2 0 0 0-2-2h-2Zm-8 0V7a3 3 0 0 1 6 0v1H9Zm3 8.7a2 2 0 1 1 1-3.7v3.7h-2Z"/></svg>
                        </span>
                        <span><strong>Sem PFX gravado</strong><small>Arquivo e senha não persistem</small></span>
                    </article>
                    <article class="saeng-feature-card">
                        <span class="saeng-feature-icon" aria-hidden="true">
                            <svg viewBox="0 0 24 24"><path d="M3 21V7l6-4v4l6-4v6h6v12H3Zm3-3h3v-3H6v3Zm0-6h3V9H6v3Zm6 6h3v-3h-3v3Zm0-6h3V9h-3v3Zm6 6h1v-6h-1v6Z"/></svg>
                        </span>
                        <span><strong>Multiempresa</strong><small>Estruturas, unidades e procurações</small></span>
                    </article>
                    <article class="saeng-feature-card">
                        <span class="saeng-feature-icon" aria-hidden="true">
                            <svg viewBox="0 0 24 24"><path d="M12 4a8 8 0 0 1 7.4 5H22l-3.5 3.5L15 9h2.2A6 6 0 0 0 6.7 7.3L5.3 5.9A8 8 0 0 1 12 4Zm-7.4 7H2l3.5-3.5L9 11H6.8a6 6 0 0 0 10.5 1.7l1.4 1.4A8 8 0 0 1 4.6 11Z"/></svg>
                        </span>
                        <span><strong>Atualizações oficiais</strong><small>Regras, tabelas e validações</small></span>
                    </article>
                </div>

                <footer class="saeng-brand-footer">
                    <span>SAENG Software SST</span>
                    <span aria-hidden="true">•</span>
                    <span>Ambiente local protegido</span>
                </footer>
            </div>
        </section>

        <section class="saeng-access-panel" aria-label="Autenticação do sistema">
            <div class="saeng-access-decoration" aria-hidden="true"></div>
            <div class="saeng-access-wrap">
                <div class="saeng-mobile-brand">
                    <img src="/static/logo_abertura_saeng.png" alt="">
                    <span>SAENG Software SST</span>
                </div>

                <section class="saeng-auth-card">
                    <header class="saeng-auth-header">
                        <p class="saeng-auth-kicker">Acesso principal</p>
                        <span class="saeng-gold-rule" aria-hidden="true"></span>
                        <h2>Certificado digital A1</h2>
                        <p>Selecione o certificado da empresa autorizada para iniciar uma sessão segura.</p>
                    </header>

                    {% if error %}
                    <div class="saeng-alert saeng-alert-error" role="alert">{{ error }}</div>
                    {% endif %}
                    {% if message %}
                    <div class="saeng-alert saeng-alert-info" role="status">{{ message }}</div>
                    {% endif %}
                    {% if success %}
                    <div class="saeng-alert saeng-alert-success" role="status">{{ success }}</div>
                    {% endif %}

                    <div class="saeng-certificate-form">
                        __CERTIFICATE_FORM__
                    </div>

                    <div class="saeng-security-note">
                        <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M17 10h-1V7a4 4 0 0 0-8 0v3H7a2 2 0 0 0-2 2v8h14v-8a2 2 0 0 0-2-2Zm-7 0V7a2 2 0 0 1 4 0v3h-4Zm2 7a1.5 1.5 0 1 1 0-3 1.5 1.5 0 0 1 0 3Z"/></svg>
                        <p>O PFX/P12 e a senha são mantidos somente na memória do processo. Nada é incluído em banco, backup ou pacote.</p>
                    </div>
                </section>

                __LOCAL_SECTION__

                <p class="saeng-access-footer">Acesso restrito • Operações registradas em trilha de auditoria</p>
            </div>
        </section>
    </main>

    <script>
    (function () {
        "use strict";

        var certificateArea = document.querySelector(".saeng-certificate-form");
        if (certificateArea) {
            var certificateForm = certificateArea.querySelector("form");
            if (certificateForm) {
                certificateForm.classList.add("saeng-form", "saeng-form-certificate");
            }
        }

        var localArea = document.querySelector(".saeng-local-body");
        if (localArea) {
            var localForm = localArea.querySelector("form");
            if (localForm) {
                localForm.classList.add("saeng-form", "saeng-form-local");
            }
        }

        document.querySelectorAll("input").forEach(function (input) {
            input.classList.add("saeng-input");
        });

        document.querySelectorAll('input[type="password"]').forEach(function (input) {
            var host = document.createElement("div");
            host.className = "saeng-password-host";
            input.parentNode.insertBefore(host, input);
            host.appendChild(input);

            var button = document.createElement("button");
            button.type = "button";
            button.className = "saeng-password-toggle";
            button.setAttribute("aria-label", "Mostrar senha");
            button.innerHTML = '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 5c5.5 0 9.7 5.2 10 6l.2.5-.2.5c-.3.8-4.5 6-10 6S2.3 12.8 2 12l-.2-.5L2 11c.3-.8 4.5-6 10-6Zm0 2c-3.8 0-7 3.3-7.9 4.5C5 12.7 8.2 16 12 16s7-3.3 7.9-4.5C19 10.3 15.8 7 12 7Zm0 2.2a2.3 2.3 0 1 1 0 4.6 2.3 2.3 0 0 1 0-4.6Z"/></svg>';
            button.addEventListener("click", function () {
                var visible = input.type === "text";
                input.type = visible ? "password" : "text";
                button.setAttribute("aria-label", visible ? "Mostrar senha" : "Ocultar senha");
                button.classList.toggle("is-visible", !visible);
            });
            host.appendChild(button);
        });

        document.querySelectorAll('input[type="file"]').forEach(function (input) {
            input.addEventListener("change", function () {
                input.classList.toggle("has-file", Boolean(input.files && input.files.length));
            });
        });

        document.querySelectorAll("form").forEach(function (form) {
            form.addEventListener("submit", function () {
                var submit = form.querySelector('button[type="submit"], input[type="submit"]');
                if (!submit) {
                    return;
                }
                submit.classList.add("is-loading");
                submit.setAttribute("aria-busy", "true");
                if (submit.tagName === "BUTTON") {
                    submit.dataset.originalText = submit.textContent;
                    submit.textContent = "Validando acesso...";
                }
            });
        });
    })();
    </script>
</body>
</html>
'@

    $NewLogin = $NewLogin.Replace('__CERTIFICATE_FORM__', $CertificateForm)
    $NewLogin = $NewLogin.Replace('__LOCAL_SECTION__', $LocalSection)

    $FinalCss = @'
:root {
    --saeng-navy-950: #031328;
    --saeng-navy-900: #061a31;
    --saeng-navy-850: #08233f;
    --saeng-navy-800: #0b2d4e;
    --saeng-gold-500: #d7a62d;
    --saeng-gold-400: #e5bd55;
    --saeng-gold-300: #f0d486;
    --saeng-ink: #071a32;
    --saeng-muted: #6d7c91;
    --saeng-line: #dbe3ec;
    --saeng-surface: #ffffff;
    --saeng-soft: #f4f7fb;
    --saeng-danger: #a72727;
    --saeng-success: #166534;
    --saeng-shadow: 0 28px 70px rgba(7, 26, 50, .16);
}

* {
    box-sizing: border-box;
}

html,
body {
    min-height: 100%;
    margin: 0;
}

body.saeng-login-page {
    min-height: 100vh;
    overflow-x: hidden;
    color: var(--saeng-ink);
    background: var(--saeng-soft);
    font-family: Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
    text-rendering: optimizeLegibility;
    -webkit-font-smoothing: antialiased;
}

.saeng-login-shell {
    min-height: 100vh;
    display: grid;
    grid-template-columns: minmax(0, 1.32fr) minmax(440px, .88fr);
}

.saeng-brand-panel {
    position: relative;
    isolation: isolate;
    min-height: 100vh;
    overflow: hidden;
    color: #fff;
    background:
        radial-gradient(circle at 76% 18%, rgba(46, 107, 164, .25), transparent 30%),
        radial-gradient(circle at 6% 92%, rgba(29, 91, 153, .24), transparent 34%),
        linear-gradient(135deg, var(--saeng-navy-950) 0%, var(--saeng-navy-900) 45%, var(--saeng-navy-850) 100%);
}

.saeng-brand-panel::before,
.saeng-brand-panel::after {
    content: "";
    position: absolute;
    z-index: -1;
    border: 1px solid rgba(226, 183, 70, .18);
    transform: rotate(-38deg);
}

.saeng-brand-panel::before {
    width: 620px;
    height: 620px;
    left: -430px;
    bottom: -350px;
}

.saeng-brand-panel::after {
    width: 500px;
    height: 500px;
    right: -370px;
    top: -330px;
}

.saeng-brand-glow {
    position: absolute;
    z-index: -1;
    border-radius: 999px;
    filter: blur(2px);
    opacity: .5;
}

.saeng-brand-glow-one {
    width: 360px;
    height: 360px;
    top: -180px;
    left: -90px;
    background: radial-gradient(circle, rgba(25, 87, 143, .42), transparent 70%);
}

.saeng-brand-glow-two {
    width: 480px;
    height: 480px;
    right: -220px;
    bottom: -240px;
    background: radial-gradient(circle, rgba(20, 74, 128, .35), transparent 70%);
}

.saeng-brand-line {
    position: absolute;
    height: 1px;
    background: linear-gradient(90deg, transparent, rgba(229, 189, 85, .85), transparent);
}

.saeng-brand-line-top {
    width: 58%;
    top: 5.2%;
    right: 5%;
}

.saeng-brand-line-bottom {
    width: 74%;
    bottom: 4.8%;
    left: 5%;
}

.saeng-brand-content {
    width: min(820px, 100%);
    min-height: 100vh;
    margin: 0 auto;
    padding: clamp(38px, 5vw, 78px) clamp(34px, 7vw, 92px) 34px;
    display: flex;
    flex-direction: column;
    justify-content: center;
}

.saeng-brand-header {
    display: flex;
    align-items: center;
    gap: 26px;
    margin-bottom: clamp(42px, 6vh, 76px);
}

.saeng-logo-frame {
    flex: 0 0 auto;
    width: 118px;
    height: 118px;
    display: grid;
    place-items: center;
    overflow: hidden;
    border: 1px solid rgba(231, 192, 91, .48);
    border-radius: 26px;
    background: linear-gradient(145deg, rgba(6, 26, 49, .92), rgba(8, 39, 70, .82));
    box-shadow: 0 18px 42px rgba(0, 0, 0, .24), inset 0 0 0 1px rgba(255,255,255,.035);
}

.saeng-logo-frame img {
    width: 84%;
    height: 84%;
    object-fit: contain;
    display: block;
}

.saeng-company-name {
    min-width: 0;
    padding-left: 26px;
    border-left: 1px solid rgba(229, 189, 85, .55);
    display: grid;
    gap: 5px;
    color: var(--saeng-gold-300);
    font-size: 13px;
    font-weight: 750;
    letter-spacing: .28em;
    line-height: 1.5;
    text-transform: uppercase;
}

.saeng-brand-copy {
    max-width: 710px;
}

.saeng-eyebrow {
    margin: 0 0 14px;
    color: var(--saeng-gold-400);
    font-size: 12px;
    font-weight: 800;
    letter-spacing: .22em;
    text-transform: uppercase;
}

.saeng-brand-copy h1 {
    max-width: 680px;
    margin: 0;
    color: #fff;
    font-size: clamp(44px, 5.1vw, 76px);
    font-weight: 760;
    letter-spacing: -.045em;
    line-height: .99;
}

.saeng-brand-copy h1 span {
    display: block;
    margin-top: 8px;
    color: var(--saeng-gold-400);
}

.saeng-description {
    max-width: 650px;
    margin: 28px 0 0;
    color: rgba(235, 242, 250, .82);
    font-size: clamp(16px, 1.35vw, 19px);
    line-height: 1.68;
}

.saeng-feature-grid {
    display: grid;
    grid-template-columns: repeat(2, minmax(0, 1fr));
    gap: 14px;
    margin-top: clamp(34px, 5vh, 56px);
}

.saeng-feature-card {
    min-height: 82px;
    padding: 16px 18px;
    display: flex;
    align-items: center;
    gap: 14px;
    border: 1px solid rgba(229, 189, 85, .26);
    border-radius: 18px;
    background: linear-gradient(145deg, rgba(255,255,255,.055), rgba(255,255,255,.018));
    box-shadow: inset 0 1px 0 rgba(255,255,255,.035);
    backdrop-filter: blur(10px);
}

.saeng-feature-icon {
    width: 38px;
    height: 38px;
    flex: 0 0 38px;
    display: grid;
    place-items: center;
    border-radius: 12px;
    color: var(--saeng-gold-400);
    background: rgba(229, 189, 85, .09);
}

.saeng-feature-icon svg,
.saeng-security-note svg,
.saeng-summary-icon svg,
.saeng-password-toggle svg {
    width: 22px;
    height: 22px;
    fill: currentColor;
}

.saeng-feature-card > span:last-child {
    min-width: 0;
    display: grid;
    gap: 4px;
}

.saeng-feature-card strong {
    color: #fff;
    font-size: 14px;
    font-weight: 750;
}

.saeng-feature-card small {
    color: rgba(226, 235, 246, .66);
    font-size: 12px;
    line-height: 1.35;
}

.saeng-brand-footer {
    margin-top: auto;
    padding-top: 34px;
    display: flex;
    gap: 10px;
    color: rgba(217, 226, 237, .48);
    font-size: 11px;
    font-weight: 650;
    letter-spacing: .1em;
    text-transform: uppercase;
}

.saeng-access-panel {
    position: relative;
    min-height: 100vh;
    overflow: hidden;
    display: grid;
    place-items: center;
    padding: clamp(34px, 5vw, 72px);
    background:
        radial-gradient(circle at 78% 9%, rgba(255,255,255,.96), transparent 24%),
        linear-gradient(145deg, #f8fafc 0%, #eef3f8 54%, #e8eef5 100%);
}

.saeng-access-decoration {
    position: absolute;
    width: 620px;
    height: 620px;
    right: -390px;
    top: -360px;
    border: 1px solid rgba(7, 38, 70, .08);
    border-radius: 50%;
}

.saeng-access-wrap {
    position: relative;
    z-index: 1;
    width: min(520px, 100%);
}

.saeng-mobile-brand {
    display: none;
}

.saeng-auth-card {
    padding: clamp(32px, 4vw, 50px);
    border: 1px solid rgba(9, 38, 68, .08);
    border-radius: 30px;
    background: rgba(255, 255, 255, .96);
    box-shadow: var(--saeng-shadow), inset 0 1px 0 rgba(255,255,255,.9);
}

.saeng-auth-header {
    margin-bottom: 28px;
}

.saeng-auth-kicker {
    margin: 0;
    color: #a9780c;
    font-size: 12px;
    font-weight: 850;
    letter-spacing: .17em;
    text-transform: uppercase;
}

.saeng-gold-rule {
    width: 44px;
    height: 3px;
    display: block;
    margin: 15px 0 20px;
    border-radius: 999px;
    background: linear-gradient(90deg, var(--saeng-gold-500), var(--saeng-gold-300));
}

.saeng-auth-header h2 {
    margin: 0;
    color: var(--saeng-ink);
    font-size: clamp(28px, 3vw, 38px);
    font-weight: 780;
    letter-spacing: -.035em;
    line-height: 1.08;
}

.saeng-auth-header > p:last-child {
    margin: 14px 0 0;
    color: var(--saeng-muted);
    font-size: 14px;
    line-height: 1.55;
}

.saeng-alert {
    margin-bottom: 18px;
    padding: 13px 15px;
    border: 1px solid;
    border-radius: 13px;
    font-size: 13px;
    line-height: 1.45;
}

.saeng-alert-error {
    color: #852020;
    border-color: #f0b8b8;
    background: #fff1f1;
}

.saeng-alert-info {
    color: #164e75;
    border-color: #bae6fd;
    background: #f0f9ff;
}

.saeng-alert-success {
    color: #166534;
    border-color: #bbf7d0;
    background: #f0fdf4;
}

.saeng-form {
    display: grid;
    gap: 18px;
}

.saeng-form label,
.saeng-certificate-form label,
.saeng-local-body label {
    display: block;
    margin: 0 0 8px;
    color: #263b55;
    font-size: 13px;
    font-weight: 750;
}

.saeng-form input,
.saeng-certificate-form input,
.saeng-local-body input,
.saeng-form select,
.saeng-form textarea {
    width: 100%;
    min-height: 54px;
    margin: 0;
    padding: 13px 15px;
    border: 1px solid #cfd9e5;
    border-radius: 13px;
    outline: none;
    color: var(--saeng-ink);
    background: #fff;
    font: inherit;
    transition: border-color .18s ease, box-shadow .18s ease, background .18s ease;
}

.saeng-form input:hover,
.saeng-certificate-form input:hover,
.saeng-local-body input:hover {
    border-color: #aebdce;
}

.saeng-form input:focus,
.saeng-certificate-form input:focus,
.saeng-local-body input:focus {
    border-color: #c49525;
    box-shadow: 0 0 0 4px rgba(215, 166, 45, .14);
}

.saeng-form input[type="file"],
.saeng-certificate-form input[type="file"] {
    padding: 7px;
    cursor: pointer;
    color: #5f7084;
    background: #fbfcfe;
}

.saeng-form input[type="file"]::file-selector-button,
.saeng-certificate-form input[type="file"]::file-selector-button {
    height: 38px;
    margin-right: 12px;
    padding: 0 15px;
    border: 1px solid #d5dde7;
    border-radius: 9px;
    color: #203550;
    background: #fff;
    font-weight: 750;
    cursor: pointer;
    transition: background .18s ease, border-color .18s ease;
}

.saeng-form input[type="file"]::file-selector-button:hover,
.saeng-certificate-form input[type="file"]::file-selector-button:hover {
    border-color: #c49a34;
    background: #fffaf0;
}

.saeng-password-host {
    position: relative;
}

.saeng-password-host input {
    padding-right: 54px !important;
}

.saeng-password-toggle {
    position: absolute;
    top: 50%;
    right: 10px;
    width: 38px;
    height: 38px;
    padding: 0;
    display: grid;
    place-items: center;
    transform: translateY(-50%);
    border: 0;
    border-radius: 10px;
    color: #708096;
    background: transparent;
    cursor: pointer;
}

.saeng-password-toggle:hover,
.saeng-password-toggle:focus-visible,
.saeng-password-toggle.is-visible {
    color: #9b7217;
    background: #fff8e8;
}

.saeng-form button[type="submit"],
.saeng-certificate-form button[type="submit"],
.saeng-local-body button[type="submit"],
.saeng-form input[type="submit"],
.saeng-certificate-form input[type="submit"],
.saeng-local-body input[type="submit"] {
    width: 100%;
    min-height: 56px;
    margin-top: 4px;
    padding: 13px 20px;
    border: 1px solid #c7921b;
    border-radius: 13px;
    color: #06172b;
    background: linear-gradient(135deg, #e8bf54 0%, #d29c21 58%, #c98f14 100%);
    box-shadow: 0 13px 28px rgba(184, 126, 10, .22), inset 0 1px 0 rgba(255,255,255,.38);
    font: inherit;
    font-size: 15px;
    font-weight: 850;
    cursor: pointer;
    transition: transform .18s ease, filter .18s ease, box-shadow .18s ease;
}

.saeng-form button[type="submit"]:hover,
.saeng-certificate-form button[type="submit"]:hover,
.saeng-local-body button[type="submit"]:hover,
.saeng-form input[type="submit"]:hover,
.saeng-certificate-form input[type="submit"]:hover,
.saeng-local-body input[type="submit"]:hover {
    transform: translateY(-1px);
    filter: brightness(1.025);
    box-shadow: 0 16px 32px rgba(184, 126, 10, .28), inset 0 1px 0 rgba(255,255,255,.42);
}

.saeng-form button[type="submit"].is-loading,
.saeng-certificate-form button[type="submit"].is-loading,
.saeng-local-body button[type="submit"].is-loading {
    cursor: wait;
    opacity: .78;
}

.saeng-security-note {
    margin-top: 22px;
    padding-top: 20px;
    display: flex;
    align-items: flex-start;
    justify-content: center;
    gap: 9px;
    border-top: 1px solid #e6ebf1;
    color: #728198;
}

.saeng-security-note svg {
    width: 17px;
    height: 17px;
    flex: 0 0 17px;
    margin-top: 1px;
    fill: #6b7d93;
}

.saeng-security-note p {
    max-width: 390px;
    margin: 0;
    font-size: 11px;
    line-height: 1.5;
    text-align: center;
}

.saeng-local-access {
    margin-top: 20px;
    overflow: hidden;
    border: 1px solid rgba(8, 38, 68, .1);
    border-radius: 18px;
    background: rgba(255,255,255,.62);
    box-shadow: 0 10px 28px rgba(7, 26, 50, .06);
}

.saeng-local-access summary {
    min-height: 72px;
    padding: 14px 17px;
    display: flex;
    align-items: center;
    gap: 13px;
    list-style: none;
    cursor: pointer;
    color: #263b55;
}

.saeng-local-access summary::-webkit-details-marker {
    display: none;
}

.saeng-summary-icon {
    width: 36px;
    height: 36px;
    flex: 0 0 36px;
    display: grid;
    place-items: center;
    border-radius: 11px;
    color: #9a7218;
    background: #fff6df;
}

.saeng-summary-icon svg {
    width: 19px;
    height: 19px;
}

.saeng-local-access summary > span:nth-child(2) {
    display: grid;
    gap: 3px;
}

.saeng-local-access summary strong {
    font-size: 13px;
}

.saeng-local-access summary small {
    color: #7d899a;
    font-size: 11px;
}

.saeng-summary-chevron {
    margin-left: auto;
    color: #758499;
    font-size: 20px;
    transition: transform .18s ease;
}

.saeng-local-access[open] .saeng-summary-chevron {
    transform: rotate(180deg);
}

.saeng-local-body {
    padding: 0 18px 20px;
}

.saeng-access-footer {
    margin: 18px 0 0;
    color: #8b97a8;
    font-size: 10px;
    font-weight: 650;
    letter-spacing: .08em;
    text-align: center;
    text-transform: uppercase;
}

@media (max-width: 1180px) {
    .saeng-login-shell {
        grid-template-columns: minmax(0, 1.08fr) minmax(410px, .92fr);
    }

    .saeng-brand-content {
        padding-inline: 44px;
    }

    .saeng-brand-copy h1 {
        font-size: clamp(42px, 5vw, 62px);
    }
}

@media (max-width: 920px) {
    body.saeng-login-page {
        overflow: auto;
    }

    .saeng-login-shell {
        min-height: 100vh;
        display: block;
        background: var(--saeng-soft);
    }

    .saeng-brand-panel {
        min-height: auto;
        padding: 0;
    }

    .saeng-brand-content {
        min-height: auto;
        padding: 38px 28px 42px;
    }

    .saeng-brand-header {
        margin-bottom: 30px;
    }

    .saeng-logo-frame {
        width: 86px;
        height: 86px;
        border-radius: 20px;
    }

    .saeng-company-name {
        font-size: 11px;
        letter-spacing: .21em;
    }

    .saeng-brand-copy h1 {
        font-size: clamp(38px, 8vw, 56px);
    }

    .saeng-description {
        font-size: 15px;
    }

    .saeng-feature-grid {
        margin-top: 30px;
    }

    .saeng-brand-footer {
        display: none;
    }

    .saeng-access-panel {
        min-height: auto;
        padding: 30px 20px 48px;
    }

    .saeng-access-wrap {
        width: min(620px, 100%);
    }
}

@media (max-width: 620px) {
    .saeng-brand-content {
        padding: 30px 20px 34px;
    }

    .saeng-brand-header {
        gap: 17px;
    }

    .saeng-logo-frame {
        width: 74px;
        height: 74px;
        border-radius: 17px;
    }

    .saeng-company-name {
        padding-left: 16px;
        font-size: 9px;
        letter-spacing: .16em;
    }

    .saeng-eyebrow {
        font-size: 10px;
    }

    .saeng-brand-copy h1 {
        font-size: clamp(36px, 12vw, 48px);
    }

    .saeng-feature-grid {
        grid-template-columns: 1fr;
    }

    .saeng-feature-card {
        min-height: 72px;
    }

    .saeng-access-panel {
        padding-inline: 14px;
    }

    .saeng-auth-card {
        padding: 28px 20px;
        border-radius: 24px;
    }

    .saeng-auth-header h2 {
        font-size: 29px;
    }
}

@media (min-width: 921px) and (max-height: 800px) {
    .saeng-brand-content {
        padding-top: 34px;
        padding-bottom: 24px;
    }

    .saeng-brand-header {
        margin-bottom: 34px;
    }

    .saeng-logo-frame {
        width: 94px;
        height: 94px;
        border-radius: 21px;
    }

    .saeng-brand-copy h1 {
        font-size: clamp(42px, 4.6vw, 62px);
    }

    .saeng-description {
        margin-top: 20px;
        font-size: 15px;
    }

    .saeng-feature-grid {
        margin-top: 27px;
    }

    .saeng-feature-card {
        min-height: 70px;
        padding-block: 12px;
    }

    .saeng-auth-card {
        padding-top: 32px;
        padding-bottom: 32px;
    }

    .saeng-auth-header {
        margin-bottom: 21px;
    }
}

@media (prefers-reduced-motion: reduce) {
    *,
    *::before,
    *::after {
        scroll-behavior: auto !important;
        transition-duration: .001ms !important;
        animation-duration: .001ms !important;
        animation-iteration-count: 1 !important;
    }
}
'@

    Set-Content -Path $LoginPath -Value $NewLogin -Encoding UTF8
    Set-Content -Path $FinalCssPath -Value $FinalCss -Encoding UTF8

    Write-Step "Validando preservacao das rotas, campos e formularios"
    $SavedLogin = Get-Content -Path $LoginPath -Raw -Encoding UTF8
    if ($SavedLogin -notlike "*$CertificateForm*") {
        throw "O formulario real do certificado nao permaneceu identico no novo template."
    }
    if ($LocalForm -and $SavedLogin -notlike "*$LocalForm*") {
        throw "O formulario real de acesso local nao permaneceu identico no novo template."
    }
    if ($SavedLogin -match '(?i)SAENG_SPLASH_START|splash-saeng\.png|abertura-saeng\.png') {
        throw "Foi detectado resquicio de splash ou mockup no novo login."
    }
    if (-not (Test-Path $FinalCssPath)) {
        throw "O CSS final nao foi criado."
    }

    $SavedCertificateMatch = $FormRegex.Matches($SavedLogin) | Where-Object {
        $_.Value -match $TypeFilePattern -or $_.Value -match '(?i)pfx|p12|certificado'
    } | Select-Object -First 1
    if (-not $SavedCertificateMatch) {
        throw "O formulario A1 nao foi encontrado apos a gravacao."
    }
    $SavedCertificateHash = [Convert]::ToBase64String(
        [Security.Cryptography.SHA256]::Create().ComputeHash(
            [Text.Encoding]::UTF8.GetBytes([string]$SavedCertificateMatch.Value)
        )
    )
    if ($SavedCertificateHash -ne $OriginalCertificateHash) {
        throw "O formulario A1 foi alterado internamente; rollback sera executado."
    }
    Write-Ok "Rotas, method, action, nomes de campos, hidden inputs e CSRF foram preservados pelo reaproveitamento literal do formulario."

    Write-Step "Compilando e executando os testes existentes"
    $Python = Join-Path $Root ".venv\Scripts\python.exe"
    if (-not (Test-Path $Python)) {
        throw "Python do ambiente virtual nao encontrado: $Python"
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
    Write-Ok "Compilacao e testes aprovados."

    $ReportPath = Join-Path $Root "docs\RELATORIO_LAYOUT_FINAL.txt"
    $ReportDir = Split-Path $ReportPath
    if (-not (Test-Path $ReportDir)) {
        New-Item -ItemType Directory -Path $ReportDir -Force | Out-Null
    }
    @"
SAENG SOFTWARE SST V2 - RELATORIO DO LAYOUT FINAL
Data: $(Get-Date -Format "dd/MM/yyyy HH:mm:ss")
Projeto: $Root
Login: $LoginPath
CSS: $FinalCssPath
Backup: $BackupDir
Formulario A1 action: $CertificateAction
Formulario A1 method: $CertificateMethod
Formulario A1 preservado por hash: SIM
Formulario local preservado: $(if ($LocalForm) { "SIM" } else { "NAO LOCALIZADO NO TEMPLATE ORIGINAL" })
Splash/mockup removido: SIM
Compilacao: APROVADA
Testes: APROVADOS
"@ | Set-Content -Path $ReportPath -Encoding UTF8

    Write-Host ""
    Write-Host "======================================================" -ForegroundColor DarkBlue
    Write-Host " LAYOUT FINAL APLICADO E VALIDADO" -ForegroundColor Green
    Write-Host "======================================================" -ForegroundColor DarkBlue
    Write-Host "Backup: $BackupDir" -ForegroundColor Cyan
    Write-Host "Relatorio: $ReportPath" -ForegroundColor White
    Write-Host ""
    Write-Host "O mockup nao foi usado como imagem. A tela foi reconstruida em HTML, CSS e JavaScript reais." -ForegroundColor Green

    if ($StartAfterApply) {
        Write-Step "Iniciando uma unica instancia do SAENG"
        $StartFile = Join-Path $Root "START_SAENG_SST.bat"
        if (-not (Test-Path $StartFile)) {
            throw "Inicializador nao encontrado: $StartFile"
        }
        Start-Process -FilePath $StartFile -WorkingDirectory $Root

        $Online = $false
        for ($Attempt = 1; $Attempt -le 20; $Attempt++) {
            Start-Sleep -Milliseconds 700
            try {
                $Response = Invoke-WebRequest -Uri "http://127.0.0.1:8765/login?v=layout-final" -UseBasicParsing -TimeoutSec 2
                if ($Response.StatusCode -eq 200) {
                    $Online = $true
                    break
                }
            }
            catch {
            }
        }
        if (-not $Online) {
            throw "O servidor nao respondeu em http://127.0.0.1:8765/login. Consulte a janela do servidor."
        }
        Write-Ok "Servidor iniciado e pagina de login respondeu HTTP 200."
        Start-Process "http://127.0.0.1:8765/login?v=layout-final"
    }
}
catch {
    Write-Host ""
    Write-Host "FALHA: $($_.Exception.Message)" -ForegroundColor Red

    if ($BackupReady) {
        Write-Host "Executando rollback automatico..." -ForegroundColor Yellow
        $BackupLogin = Join-Path $BackupDir "login.html"
        $BackupFinalCss = Join-Path $BackupDir "login-final.css"
        if (Test-Path $BackupLogin) {
            Copy-Item -Path $BackupLogin -Destination $LoginPath -Force
        }
        if (Test-Path $BackupFinalCss) {
            Copy-Item -Path $BackupFinalCss -Destination $FinalCssPath -Force
        }
        elseif (-not $CssExisted -and (Test-Path $FinalCssPath)) {
            Remove-Item -Path $FinalCssPath -Force
        }
        Write-Host "Rollback concluido. O login anterior foi restaurado." -ForegroundColor Green
    }
    throw
}
