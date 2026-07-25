@echo off
setlocal
cd /d "%~dp0"
echo ======================================================
echo  SAENG SOFTWARE SST V2 - ICONE DE DESKTOP R6
echo ======================================================
echo.
echo Este processo reutiliza AREA-DE-TRABALHO.png,
echo remove pontas brancas, uniformiza o azul,
echo gera um ICO multirresolucao e atualiza o atalho.
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0AJUSTAR_ICONE_DESKTOP_R6.ps1"
if errorlevel 1 (
  echo.
  echo O ajuste encontrou uma falha. Consulte a mensagem acima.
  pause
  exit /b 1
)
echo.
echo Icone R6 aplicado e validado.
pause
