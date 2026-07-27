@echo off
setlocal EnableExtensions
set "ROOT=C:\SAENG_Software_SST_FINAL"
set "PY=%ROOT%\.venv\Scripts\python.exe"

if not exist "%PY%" (
  echo ERRO: ambiente virtual nao encontrado em %ROOT%.
  pause
  exit /b 1
)

cd /d "%ROOT%"
"%PY%" -m compileall -q app tests launcher
if errorlevel 1 (
  echo ERRO: compilacao falhou.
  pause
  exit /b 1
)

"%PY%" -m pytest -q
if errorlevel 1 (
  echo ERRO: testes falharam.
  pause
  exit /b 1
)

echo.
echo VALIDACAO LOCAL APROVADA
echo Producao oficial continua condicionada a Producao Restrita,
echo protocolo oficial, processamento concluido e recibo individual.
pause
exit /b 0
