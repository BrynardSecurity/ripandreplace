:: ESET Rip & Replace Logon Script
::Author: Ralph Brynard
@echo off
setlocal EnableDelayedExpansion EnableExtensions

@rem ---- [Variables] ----
::Specify the UNC path to your Rip&Replace package below. EG: \\server\path\to\package.exe
set pkgdir=\\pdc01-hq.joe-burg.com\ITAdmins\Scripts\RipReplace\package.exe

@rem ---- [Logging] ----
for /f "usebackq" %%i in (`hostname`) do set targetcomp=%%i
set logfile=%~dp0%targetcomp%-%DATE:~-4%-%DATE:~4,2%-%DATE:~7,2%.log

call :Resume > %logfile%
goto %current%
goto :eof

:one

if not exist %~dp0.temp.%targetcomp% (
	goto :perm_check
	echo %~dp0.temp.%targetcomp% >> %~dp0.filestodel
	echo %~dp0.filestodel >> %~dp0.filestodel
) else (
	goto :check_eset
)

@rem ---- [
@rem | Phase 1 Overview
@rem | > Check to see if ESET is installed. If ESET is installed, the script exits gracefully. 
@rem | > Checks to see if Sophos is installed. 
@rem | > If both previous checks pass, the script continues with Rip & Replace. 
@rem | >
@rem ] ----
:perm_check
echo Phase 1: Permission Check >> %logfile%
reg add HKCU\Software\Microsoft\Windows\CurrentVersion\Run /v %~n0 /d %~dpnx0 /f
echo two >%~dp0current.txt
echo %~dp0current.txt >> %~dp0.filestodel

net session >nul 2>&1
if %errorlevel% equ 0 (
    echo Administrator PRIVILEGES Detected! >> %logfile%
	type nul > %~dp0.temp.%targetcomp%
	goto :check_eset
) else (
   echo ######## ########  ########   #######  ########  
   echo ##       ##     ## ##     ## ##     ## ##     ## 
   echo ##       ##     ## ##     ## ##     ## ##     ## 
   echo ######   ########  ########  ##     ## ########  
   echo ##       ##   ##   ##   ##   ##     ## ##   ##   
   echo ##       ##    ##  ##    ##  ##     ## ##    ##  
   echo ######## ##     ## ##     ##  #######  ##     ## 
   echo.
   echo.
   echo ####### ERROR: ADMINISTRATOR PRIVILEGES REQUIRED #########
   echo This script must be run as administrator to work properly!  
   echo If you're seeing this after clicking on a start menu icon, then right click on the shortcut and select "Run As Administrator".
   echo ##########################################################
   echo.
   pause
   goto :four
   goto :eof
   exit /B 1   
)

:check_eset
echo Phase 1: Check if ESET is installed >> %logfile%
:check_eset
@rem ---- [Check if ESET is installed. If ESET is installed, script will exit gracefully. ] ----
for /f "tokens=1,2 delims={,}" %%a in ('wmic product where "name = 'ESET Endpoint Antivirus' or name = 'ESET Endpoint Security'"') do (
	if %errorlevel% == 1 (
		echo ESET is installed! Exiting!
		exit /b
		goto :four
		goto eof
	) else (
		echo ESET is not installed! Proceeding with Rip and Replace....
		goto :start
		goto eof
	)
)

:start
echo Phase 1: Check if Sophos Anti Tamper is enabled. >> %logfile%
@rem ---- [The script will first check to see if Anti-Tamper is enabled. If so, the user will receive a prompt asking them if they would like to reboot into Safe Mode.] ----
for /f "tokens=3" %%i in ('reg query "HKLM\SYSTEM\CurrentControlSet\Services\Sophos Endpoint Defense\TamperProtection\Config" /v "SEDEnabled" ^| findstr /i "REG_DWORD"') do (set sedstatus=%%i)
if %sedstatus% == 0x1 (
	goto :disable_sed
) else if %sedstatus% == 0x0 (
	goto :three
)

:disable_sed
echo Phase 1: Attempting to disable Anti Tamper in normal boot mode. >> %logfile%
@rem ---- [Script will attempt to set SEDDisabled Registry Key in normal boot mode. Otherwise, the script will boot the machine into safe-mode and execute auto-login with a temporary user account.] ----
reg add "HKLM\SYSTEM\CurrentControlSet\Services\Sophos Endpoint Defense\TamperProtection\Config" /v "SEDEnabled" /t "REG_DWORD" /d 0 /f
if %errorlevel% == 1 ( 
	goto :safe_boot
	goto :eof
) else if %errorlevel% == 0 (
	goto :three
	goto :eof
)

:safe_boot
@rem ---- [This section of the script will configure Windows to boot into Safe Mode with Networking. Once rebooted and the user logs in, the script will resume with disabling Antitamper via the registry. ] ----
call :msgbox "Sophos Antitamper is enabled and will need to be disabled in Safe Mode. Would you like to continue?"  "VBYesNo+VBQuestion" "ESET Rip & Replace - Boot to safemode"
if errorlevel 7 (
	echo NO - Reboot will not be attempted. >> %logfile%
	goto :clean_exit
	goto :eof
	) else if errorlevel 6 (
		echo YES - Rebooting to safe-mode >> %logfile%
		call :enter_creds
		goto :eof
)

exit /b

:enter_creds
call :msgbox "Once you click yes, you will be prompted to enter your windows username and password to configure automatic login after rebooting to Safe Mode. Click yes to continue, or click no to cancel the script and exit." "VBYesNo+VBQuestion" "ESET Rip & Replace - Boot to safemode"
if errorlevel 7 (
	echo NO - Reboot will not be attempted. >> %logfile%
	goto :clean_exit
	goto :eof
	) else if errorlevel 6 (
		echo YES - Rebooting to safe-mode >> %logfile%
		call :get_creds
		goto :eof
)

:get_creds
echo Phase 1: Getting user credentials to configure automatic logon >> %logfile%
@rem ---- [The script will prompt the user to enter the windows username and password to setup automatic logon] ----
for /f "tokens=1 delims=\" %%i in ('whoami') do (
	set domain=%%i
)

set /P user= "Enter the domain or local administrator account username:"
set /P "=Enter the password for the domain or local administrator account:" < Nul
Call :PasswordInput

Goto :autologon

:PasswordInput

Set "pwd="
Set "INTRO=" &For /F "skip=1" %%# in (
'"Echo(|Replace.exe ? . /U /W"'
) Do If Not Defined INTRO Set "INTRO=%%#"
For /F %%# In (
'"Prompt $H &For %%_ In (_) Do Rem"') Do Set "BKSPACE=%%#"
:_PasswordInput_Kbd
Set "Excl="
Set "CHR=" &For /F skip^=1^ delims^=^ eol^= %%# in (
'Replace.exe ? . /U /W') Do If Not Defined CHR (
Set "CHR=%%#" &If "%%#"=="!" Set "Excl=yes")
If "!INTRO!"=="!CHR!" Echo(&Goto :Eof
If "!BKSPACE!"=="!CHR!" (If Defined pwd (
Set "pwd=!pwd:~0,-1!"
Set /P "=!BKSPACE! !BKSPACE!" <Nul)
Goto :_PasswordInput_Kbd
) Else If Not Defined Excl (
Set "pwd=!pwd!!CHR:~0,1!"
) Else Set "pwd=!pwd!^!"
Set /P "=*" <Nul
Goto :_PasswordInput_Kbd

:autologon
reg add "HKLM\Software\Microsoft\Windows NT\CurrentVersion\Winlogon" /v AutoAdminLogon /t REG_SZ /d 1 /f
reg add "HKLM\Software\Microsoft\Windows NT\CurrentVersion\Winlogon" /v DefaultUserName /t REG_SZ /d %domain%\%user% /f
reg add "HKLM\SOftware\Microsoft\Windows NT\CurrentVersion\Winlogon" /v DefaultDomain /t REG_SZ /d %domain% /f
reg add "HKLM\Software\Microsoft\Windows NT\CurrentVersion\Winlogon" /v DefaultPassword /t REG_SZ /d !pwd! /f
::Adding key to resume script after booting to safemode
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce" /v "*%~n0" /d %~dpnx0 /f


:vercheck
echo Phase 1: Reboot into SafeMode >> %logfile%
@rem ---- [This section of the script will check to determine which Windows build version we are running on. Once the version is determined, the appropriate configuration changes will be made to reboot into safe mode.] ----
for /f "tokens=4-5 delims=. " %%a in ('ver') do (set version=%%a)
if %version% == 5 (
	goto ver_nt5x
) else if %version% == 6 (
	goto ver_nt6x
) else if %version% == 10 (
	goto ver_nt7x
) else goto warn_and_exit

:ver_nt5x
::Run Windows 2000/XP specific commands here
echo ver_nt5x >> %logfile%
bootcfg /raw /a /safeboot:network /id 1
reg add HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce /v "*UndoSB" /t REG_SZ /d "bootcfg /raw /fastdetect /id 1" /f
echo Your computer will restart in 10 seconds...
shutdown -r -f -t 10
goto :eof
		
:ver_nt6x
echo ver_nt6x >> %logfile%
::Run Windows Vista/7 specific commands here
bcdedit /set {current} safeboot network
reg add echo Your computer will restart in 10 seconds...
shutdown -r -f -t 10
goto :eof
		
:ver_nt7x
echo ver_nt7x >> %logfile%
::Run Windows 10 specific commands here
bcdedit /set {current} safeboot network
::Remove key to reboot into normal mode.
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce" /v "*UndoSB" /t REG_SZ /d "bcdedit /deletevalue {current} safeboot" /f
echo Your computer will restart in 10 seconds...
shutdown -r -f -t 10
goto :eof

:warn_and_exit
echo Machine OS cannot be determined. >> %logfile%

:msgbox prompt type title
setlocal enableextensions
set "tempFile=%temp%\%~nx0.%random%%random%%random%vbs.tmp"
>"%tempFile%" echo(WScript.Quit msgBox("%~1",%~2,"%~3") & cscript //nologo //e:vbscript "%tempFile%"
set "exitCode=%errorlevel%" & del "%tempFile%" >nul 2>nul
endlocal & exit /b %exitCode%

:two
echo three >%~dp0current.txt
echo Phase 2: Setting registry key to disable Anti Tamper >> %logfile%
@rem ---- [Script will set registry key value for AntiTamper to 0 to disable AntiTamper] ----
reg add "HKLM\System\CurrentControlSet\Services\Sophos Endpoint Defense\TamperProtection\Config" /v "SEDEnabled" /t "REG_DWORD" /d 0 /f
::Check to ensure anti-tamper is disabled
for /f "tokens=3" %%i in ('reg query "HKLM\SYSTEM\CurrentControlSet\Services\Sophos Endpoint Defense\TamperProtection\Config" /v "SEDEnabled" ^| findstr /i "REG_DWORD"') do (set sedstatus=%%i)
if %sedstatus% == 0x1 (
	echo Anti-Tamper is still enabled!
	echo four >%~dp0current.txt
	echo Script was unable to disable AntiTamper! Please try disabling manually.
	shutdown -f -r -t 30
) else if %sedstatus% == 0x0 (
	echo Anti-Tamper is disabled!
)
shutdown -r -t 30
goto :eof

:three
echo four >%~dp0current.txt
echo Phase 3: Copying Rip & Replace package >> %logfile%

if not exist %~dp0package.exe (
	copy %pkgdir% %~dp0package.exe
	start /wait "" "%~dp0package.exe
) else (
	start /wait "" "%~dp0package.exe"
)

goto :four
goto :eof



:four
echo Phase 4: Cleanup >> %logfile%
for /f %%i in (%~dp0.filestodel) do (
	del /Q /S %%i
	del /Q /S %~dp0current.txt
	del /Q /S %~dp0.filestodel
	goto :reg_cleanup
) 

:reg_cleanup
set regkeys="HKCU\Software\Microsoft\Windows\CurrentVersion\Run\%~n0"^
^ "HKLM\Software\Microsoft\Windows NT\CurrentVersion\Winlogon\AutoAdminLogon"^
^ "HKLM\Software\Microsoft\Windows NT\CurrentVersion\Winlogon\DefaultUserName"^
^ "HKLM\Software\Microsoft\Windows NT\CurrentVersion\Winlogon\DefaultPassword"^
^ "HKLM\Software\Microsoft\Windows NT\CurrentVersion\Winlogon\DefaultDomain"^
^ "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce\*UndoSB"^
^ "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce\*%~n0"

Echo.
ECHO                 **************************************
ECHO                        Please wait..........
ECHO                 **************************************


for %%k in (%regkeys%) do call :check_key %%k %logfile%
cmd /U /C type %logfile% >> %logfile%
start "" %logfile%
exit /b
::********************************************
:check_Key
reg query %1 >nul 2>&1
(
    if %errorlevel% equ 0 ( reg QUERY %1 /s
        ) else ( echo %1 ===^> Not found
    )
) >>%2 2>&1
::********************************************

:Resume
if exist %~dp0current.txt (
    set /p current=<%~dp0current.txt
) else (
    set current=one
)
