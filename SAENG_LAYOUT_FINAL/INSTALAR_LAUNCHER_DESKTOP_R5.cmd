@echo off
setlocal
cd /d "%~dp0"
echo ======================================================
echo  SAENG SOFTWARE SST V2 - LAUNCHER SILENCIOSO R5
echo ======================================================
echo.
echo Este processo substitui o atalho antigo por um iniciador
echo profissional: sem aviso do arquivo BAT, sem janela preta,
echo sem servidor duplicado e com o icone oficial SAENG.
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0INSTALAR_LAUNCHER_DESKTOP_R5.ps1" -StartAfterInstall
if errorlevel 1 (
  echo.
  echo A instalacao encontrou uma falha. Consulte a mensagem acima.
  pause
  exit /b 1
)
echo.
echo Launcher silencioso R5 instalado e validado.
pause
