@ECHO OFF
CLS
SET date=
REM date /t >%date%
SET year=%date:~-4%
SET daymon=%date:~0,5%
REM ** SET daymon=%date:~4,5%
SET mon=%daymon:~-2%
REM ** SET mon=%daymon:~0,2%
SET day=%date:~0,2%
REM ** SET day=%daymon:~-2%
SET BackupDate=%day%-%mon%-%year%
GOTO OLDSERVER
GOTO END

:OLDSERVER
SET OldServer=
ECHO.
ECHO -------------------------------------------------------
ECHO.
SET /P OldServer=Enter Name of Old Server (eg SRV-01) :  
IF '%OldServer%'=='' GOTO INVALIDOLDSERVER
ECHO.
ECHO -------------------------------------------------------
ECHO.
%SystemRoot%\system32\ping.exe -n 1 %OldServer% >nul
IF ERRORLEVEL 1 (GOTO INVALIDOLDSERVER) else (GOTO VALIDOLDSERVER) 
GOTO OLDSERVER

:INVALIDOLDSERVER
Echo "%OldServer%" is not valid. Please try again.
GOTO OLDSERVER

:VALIDOLDSERVER
CLS
ECHO.
ECHO -------------------------------------------------------
ECHO.
ECHO "%OldServer%" is valid. Processing.
SET OLDSERVERIP=
FOR /f "tokens=*" %%a in ('ping %OldServer% -4 ^| find "Pinging"') do @SET OLDSERVERIP=%%a
FOR /f "tokens=1-5 delims=[" %%a in ('echo %OLDSERVERIP%') do ( SET OLDSERVERIP=%%b)
FOR /f "tokens=1-5 delims=]" %%a in ('echo %OLDSERVERIP%') do ( SET OLDSERVERIP=%%a)
GOTO NEWSERVER

:NEWSERVER
SET NewServer=
ECHO.
ECHO -------------------------------------------------------
ECHO.
SET /P NewServer=Enter Name of New Server (eg SRV-02) :  
IF '%NewServer%'=='' GOTO INVALIDOLDSERVER
ECHO.
ECHO -------------------------------------------------------
ECHO.
%SystemRoot%\system32\ping.exe -n 1 %NewServer% >nul
IF ERRORLEVEL 1 (GOTO INVALIDNEWSERVER) else (GOTO VALIDNEWSERVER) 
GOTO NEWSERVER

:INVALIDNEWSERVER
Echo "%NewServer%" is not valid. Please try again.
GOTO NEWSERVER

:VALIDNEWSERVER
CLS
ECHO.
ECHO -------------------------------------------------------
ECHO.
ECHO "%NewServer%" is valid. Processing.
SET NEWSERVERIP=
FOR /f "tokens=*" %%a in ('ping %NewServer% -4 ^| find "Pinging"') do @SET NEWSERVERIP=%%a
FOR /f "tokens=1-5 delims=[" %%a in ('echo %NEWSERVERIP%') do ( SET NEWSERVERIP=%%b)
FOR /f "tokens=1-5 delims=]" %%a in ('echo %NEWSERVERIP%') do ( SET NEWSERVERIP=%%a)
GOTO LIST

:LIST

SET ZoneList=
ECHO.
ECHO -------------------------------------------------------
ECHO.
SET /P ZoneList=Enter full path to .CSV Export of Zone List (eg C:\TEST\DNS.csv) :  
IF '%ZoneList%'=='' GOTO INVALIDPATH
ECHO.
ECHO -------------------------------------------------------
ECHO.
IF NOT EXIST %ZoneList% (GOTO INVALIDPATH) else (GOTO VALIDPATH)
GOTO LIST

:INVALIDPATH
ECHO. "%ZoneList%" is not valid. Please try again.
GOTO LIST

:VALIDPATH
CLS
ECHO.
ECHO -------------------------------------------------------
ECHO.
ECHO "%ZoneList%" is valid. Processing.
ECHO.
ECHO -------------------------------------------------------
ECHO.
GOTO CHOICE

:CHOICE
ECHO Using List "%ZoneList%"
ECHO To Migrate from Server "%OldServer%" (%OLDSERVERIP%)
ECHO To New Server "%NewServer%" (%NEWSERVERIP%)
ECHO.
SET Choice=
SET /P Choice=Is This Correct ?  
IF NOT '%Choice%'=='' SET Choice=%Choice:~0,1%
IF /I '%Choice%'=='Y' GOTO CSVREAD
IF /I '%Choice%'=='y' GOTO CSVREAD
IF /I '%Choice%'=='N' GOTO END
IF /I '%Choice%'=='n' GOTO END
ECHO.
ECHO -------------------------------------------------------
ECHO.
ECHO "%Choice%" is not valid. Please try again.
ECHO.
ECHO -------------------------------------------------------
ECHO.
GOTO CHOICE

:CSVREAD
CLS
ECHO Using List "%ZoneList%"
ECHO to Migrate from Server "%OldServer%" to "%NewServer%"
IF NOT EXIST %WINDIR%\System32\dns\Backup\%BackupDate% (ECHO Creating %WINDIR%\System32\dns\Backup\%BackupDate%&&MKDIR %WINDIR%\System32\dns\Backup\%BackupDate%)
IF NOT EXIST \\%NewServer%\C$\Windows\System32\dns\Backup\%BackupDate% (ECHO.&&ECHO Creating \\%NewServer%\C$\Windows\System32\dns\Backup\%BackupDate%&&MKDIR \\%NewServer%\C$\Windows\System32\dns\Backup\%BackupDate%)
ECHO.
ECHO -------------------------------------------------------
ECHO.
FOR /f "usebackq tokens=1-2 delims=," %%a in ("%ZoneList%") do (
      IF NOT "%%a" == "Name" SET ZONE=%%a&&SET TYPE=%%b&&CALL :PROCESS)
GOTO END

:PROCESS
ECHO Processing Zone %ZONE%
ECHO As %TYPE%
IF "%TYPE%"=="Standard Primary" SET TYPE=Primary
IF "%TYPE%"=="Secondary" CALL :SECOND
IF EXIST %WINDIR%\System32\dns\Backup\%BackupDate%\%ZONE%.dns.bak (REN %WINDIR%\System32\dns\Backup\%BackupDate%\%ZONE%.dns.bak DUPLICATE_%ZONE%.dns.bak)
DNSCMD %OldServer% /zoneexport %ZONE% Backup\%BackupDate%\%ZONE%.dns.bak
IF EXIST \\%NewServer%\C$\Windows\System32\dns\%ZONE%.dns (ECHO Backing Up \\%NewServer%\C$\Windows\System32\dns\%ZONE%.dns&&MOVE /Y \\%NewServer%\C$\Windows\System32\dns\%ZONE%.dns \\%NewServer%\C$\Windows\System32\dns\Backup\%BackupDate%\%ZONE%.dns)
ECHO Moving \\%OldServer%\C$\Windows\System32\dns\Backup\%BackupDate%\%ZONE%.dns.bak
ECHO to \\%NewServer%\C$\Windows\System32\dns\%ZONE%.dns
MOVE /Y \\%OldServer%\C$\Windows\System32\dns\Backup\%BackupDate%\%ZONE%.dns.bak \\%NewServer%\C$\Windows\System32\dns\%ZONE%.dns
ECHO "dnscmd %NewServer% /zoneadd %ZONE% /%TYPE% /file %ZONE%.dns /load"
DNSCMD %NewServer% /zoneadd %ZONE% /%TYPE% /file %ZONE%.dns /load
ECHO %TYPE% | FIND "Secondary" >nul
IF NOT ERRORLEVEL 1 (SET TYPE=Secondary)
IF "%TYPE%"=="Secondary" (DNSCMD %NewServer% /ZoneResetMasters %ZONE% %OLDSERVERIP% /load)
IF "%TYPE%"=="Secondary" (DNSCMD %NewServer% /ZoneResetMasters %ZONE% %MASTER%)
IF "%TYPE%"=="Primary" CALL :NOTIFY
ECHO "DNSCMD %NewServer% /zoneresetsecondaries %ZONE% /securelist %SECARRAY% /notifylist %SECARRAY%"
DNSCMD %NewServer% /zoneresetsecondaries %ZONE% /securelist %SECARRAY% /notifylist %SECARRAY%
DNSCMD %OLDSERVER% /zoneresetsecondaries %ZONE% /securelist %SECARRAY% /notifylist
ECHO.
ECHO -------------------------------------------------------
ECHO.
EXIT /b
GOTO END

:NOTIFY

SET SECARRAY=
ECHO ON
@FOR /f "tokens=*" %%a in ('dnscmd /zoneinfo %ZONE% ^| find "Secondary["') do @SET SECOND=%%a&&CALL :PROC
@ECHO OFF
EXIT /b
GOTO END

:SECOND

SET SECARRAY=
ECHO ON
@FOR /f "tokens=*" %%a in ('dnscmd /zoneinfo %ZONE% ^| find "Secondary["') do @SET SECOND=%%a&&CALL :PROC
@FOR /f "tokens=*" %%a in ('dnscmd /zoneinfo %ZONE% ^| find "Master[0]"') do @set MASTER=%%a
@ECHO OFF
FOR /f "tokens=1-5 delims=," %%a in ('echo "%MASTER%"') do SET MASTER=%%e
SET MASTER=%MASTER:~6%
SET MASTER=%MASTER:~0,-1%
SET TYPE=Secondary %MASTER%
DNSCMD %OLDSERVER% /zoneresetsecondaries %ZONE% /securelist %NEWSERVERIP%%SECARRAY% /notifylist
ECHO Outputting Commands to run on Master Server
ECHO DNSCMD %MASTER% /zoneresetsecondaries %ZONE% /securelist %NEWSERVERIP% /notifylist %NEWSERVERIP% >> \\%OldServer%\C$\Windows\System32\dns\Backup\%BackupDate%\%MASTER%-ZoneReset.cmd
EXIT /b
GOTO END

:PROC

@FOR /f "tokens=1-5 delims=," %%a in ('ECHO "%SECOND%"') do @SET SECOND=%%e
@SET SECOND=%SECOND:~6%
@SET SECOND=%SECOND:~0,-1%
@SET SECARRAY=%SECARRAY% %SECOND%
@EXIT /b
GOTO END

:END
ECHO ENDING
ECHO.
ECHO -------------------------------------------------------
ECHO.
