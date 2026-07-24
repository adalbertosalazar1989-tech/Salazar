@echo off
setlocal
cd /d "%~dp0"
if not exist ".venv\Scripts\python.exe" (
  echo Ambiente Python nao encontrado.
  echo Execute primeiro INSTALAR_SAENG_V2.ps1.
  pause
  exit /b 1
)
".venv\Scripts\python.exe" -m compileall -q app.py tests
if errorlevel 1 goto erro
".venv\Scripts\python.exe" -m pytest -q
if errorlevel 1 goto erro
echo.
echo TESTES APROVADOS.
pause
exit /b 0
:erro
echo.
echo TESTES COM FALHA.
pause
exit /b 1
