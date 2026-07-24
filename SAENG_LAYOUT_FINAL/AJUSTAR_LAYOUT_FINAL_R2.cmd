@echo off
setlocal
cd /d "%~dp0"
echo ======================================================
echo  SAENG SOFTWARE SST V2 - POLIMENTO VISUAL R2
echo ======================================================
echo.
echo Este processo remove titulos e avisos duplicados,
echo ajusta o cartao a altura da tela, executa os testes
echo e inicia uma unica instancia do sistema.
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0AJUSTAR_LAYOUT_FINAL_R2.ps1" -StartAfterApply
if errorlevel 1 (
  echo.
  echo O ajuste encontrou uma falha. O rollback automatico foi executado.
  pause
  exit /b 1
)
echo.
echo Polimento R2 aplicado e validado.
pause
