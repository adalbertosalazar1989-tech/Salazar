@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0FINALIZAR_SAENG_R9.ps1" -Iniciar
set "EXITCODE=%ERRORLEVEL%"
echo.
if not "%EXITCODE%"=="0" (
  echo FINALIZACAO R9 INTERROMPIDA. Consulte os relatorios em docs\evidence.
) else (
  echo FINALIZACAO R9 CONCLUIDA NOS GATES LOCAIS.
)
pause
exit /b %EXITCODE%
