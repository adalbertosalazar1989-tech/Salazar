@echo off
setlocal EnableExtensions
cd /d "%~dp0"

net session >nul 2>&1
if not "%errorlevel%"=="0" (
  echo Solicitando permissao de administrador...
  powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b
)

echo ======================================================
echo  SAENG SOFTWARE SST - FINALIZADOR DEFINITIVO
echo ======================================================
echo.

set "PYEXE="
where py >nul 2>&1 && set "PYEXE=py -3.11"
if not defined PYEXE (
  where python >nul 2>&1 && set "PYEXE=python"
)
if not defined PYEXE (
  echo ERRO: Python 3.11 nao foi encontrado.
  pause
  exit /b 1
)

%PYEXE% "%~dp0finalizar_saeng.py" --source "C:\SAENG_Software_SST_V2" --target "C:\SAENG_Software_SST_FINAL" --start
set "RC=%errorlevel%"

echo.
if not "%RC%"=="0" (
  echo A instalacao foi interrompida. A versao atual permaneceu preservada.
  echo Consulte o log tecnico indicado na tela.
  pause
  exit /b %RC%
)

echo Instalacao concluida.
pause
exit /b 0
