@echo off
title Windows Network Fix Script
echo ==========================================
echo    Windows Network Fix Script
echo ==========================================
echo.

:: Check for administrator privileges
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [ERROR] Please run as Administrator!
    echo Right-click cmd and select "Run as administrator"
    pause
    exit /b 1
)

echo [1/10] Releasing IP addresses...
ipconfig /release
timeout /t 2 /nobreak >nul

echo [2/10] Renewing IP addresses...
ipconfig /renew
timeout /t 3 /nobreak >nul

echo [3/10] Flushing DNS cache...
ipconfig /flushdns
timeout /t 2 /nobreak >nul

echo [4/10] Registering DNS...
ipconfig /registerdns
timeout /t 2 /nobreak >nul

echo [5/10] Resetting Winsock Catalog...
netsh winsock reset
timeout /t 2 /nobreak >nul

echo [6/10] Resetting TCP/IP stack...
netsh int ip reset
timeout /t 2 /nobreak >nul

echo [7/10] Clearing firewall rules...
netsh advfirewall reset
timeout /t 2 /nobreak >nul

echo [8/10] Resetting network adapters...
netsh int reset all
timeout /t 2 /nobreak >nul

echo [9/10] Setting DNS to Google and Cloudflare...
netsh interface ip set dns "Local Area Connection" static 8.8.8.8
netsh interface ip add dns "Local Area Connection" 1.1.1.1 index=2
timeout /t 2 /nobreak >nul

echo [10/10] Restarting network services...
net stop "Dhcp" >nul 2>&1
net start "Dhcp" >nul 2>&1
net stop "Dnscache" >nul 2>&1
net start "Dnscache" >nul 2>&1

echo.
echo ==========================================
echo        Running Diagnostics
echo ==========================================
echo.

echo Testing basic connectivity...
ping -n 4 8.8.8.8

echo Testing DNS resolution...
nslookup google.com

echo Testing HTTP connectivity...
powershell -command "try { (Invoke-WebRequest -Uri 'https://www.google.com' -TimeoutSec 10).StatusCode } catch { Write-Host 'HTTP test failed' }"

echo.
echo ==========================================
echo              Final Status
echo ==========================================
echo.

ping -n 2 google.com >nul 2>&1
if %errorLevel% equ 0 (
    echo ✅ NETWORK FIXED! You can now browse the web.
) else (
    echo ❌ Some issues remain. Try rebooting your computer.
)

echo.
echo If problems persist, please reboot your system.
echo Script completed at: %time%
pause
