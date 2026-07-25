@echo off
setlocal
cd /d "%~dp0"
echo ======================================================
echo  SAENG SOFTWARE SST V2 - IDENTIDADE INTERNA R4
echo ======================================================
echo.
echo Este processo cria a logo transparente a partir da
marca atual ja instalada, substitui as logos antigas,
cria backup, executa os testes e inicia o sistema.
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0ATUALIZAR_IDENTIDADE_INTERNA_R4.ps1" -StartAfterApply
if errorlevel 1 (
  echo.
  echo A atualizacao encontrou uma falha. O rollback automatico foi executado.
  pause
  exit /b 1
)
echo.
echo Identidade interna R4 aplicada e validada.
pause
