@echo off
setlocal
cd /d "%~dp0"
echo ======================================================
echo  SAENG SOFTWARE SST V2 - LAYOUT FINAL FUNCIONAL
echo ======================================================
echo.
echo Este processo cria backup, preserva os formularios reais,
echo aplica o novo layout, executa os testes e inicia o sistema.
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0APLICAR_LAYOUT_FINAL.ps1" -StartAfterApply
if errorlevel 1 (
  echo.
  echo A aplicacao encontrou uma falha. O rollback automatico foi executado.
  echo Copie a mensagem exibida para diagnostico.
  pause
  exit /b 1
)
echo.
echo Layout final aplicado e validado.
pause
