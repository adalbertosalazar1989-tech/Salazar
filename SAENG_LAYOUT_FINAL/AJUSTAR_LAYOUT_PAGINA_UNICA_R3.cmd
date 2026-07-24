@echo off
setlocal
cd /d "%~dp0"
echo ======================================================
echo  SAENG SOFTWARE SST V2 - PAGINA UNICA R3
echo ======================================================
echo.
echo Este processo eleva o painel de acesso, remove duplicidades,
echo ajusta proporcoes e elimina a rolagem no desktop.
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0AJUSTAR_LAYOUT_PAGINA_UNICA_R3.ps1" -StartAfterApply
if errorlevel 1 (
  echo.
  echo O ajuste encontrou uma falha. O rollback automatico foi executado.
  pause
  exit /b 1
)
echo.
echo Pagina unica R3 aplicada e validada.
pause
