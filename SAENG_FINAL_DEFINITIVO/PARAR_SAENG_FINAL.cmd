@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$connections=@(Get-NetTCPConnection -LocalPort 8765 -State Listen -ErrorAction SilentlyContinue); foreach($connection in $connections){$process=Get-CimInstance Win32_Process -Filter ('ProcessId='+$connection.OwningProcess) -ErrorAction SilentlyContinue; if($process.CommandLine -match 'SAENG_Software_SST_FINAL|uvicorn'){Stop-Process -Id $connection.OwningProcess -Force}}"
exit /b 0
