@echo off
setlocal
cd /d "%~dp0"
echo ==============================================
echo  SAENG SOFTWARE SST V2 - INSTALACAO
echo ==============================================
echo O ZIP nao possui senha.
echo Se o Windows pedir permissao de administrador,
echo confirme apenas o controle de conta do Windows.
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0INSTALAR_SAENG_V2.ps1" -Iniciar
if errorlevel 1 (
  echo.
  echo A instalacao encontrou uma falha. Copie a mensagem exibida.
  pause
  exit /b 1
)
pause
