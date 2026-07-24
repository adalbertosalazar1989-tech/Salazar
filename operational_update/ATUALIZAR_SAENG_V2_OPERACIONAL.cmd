@echo off
setlocal
cd /d "%~dp0"
echo ======================================================
echo  SAENG SOFTWARE SST V2 - ATUALIZACAO OPERACIONAL
echo ======================================================
echo O pacote nao possui senha.
echo A transmissao real permanecera bloqueada por padrao.
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0ATUALIZAR_SAENG_V2_OPERACIONAL.ps1" -Iniciar
if errorlevel 1 (
  echo.
  echo A atualizacao encontrou uma falha. Copie a mensagem exibida.
  pause
  exit /b 1
)
echo.
pause
