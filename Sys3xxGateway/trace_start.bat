@echo off
rem 
rem 	Create a new trace session with specific parameters.
rem
rem WARNING:  
rem	Before running this, ETWTraceViewer.exe must be closed.
rem     After running this script, ETWTraceViewer will use the
rem     new settings defined here.
rem

rem Max file size in MegaBytes:
SET MAXSIZE=1024

rem Provider Flags (leave empty for default, else must be enclosed in quotes)
SET PROFLAGS=(0xFFFF)
rem SET PROFLAGS=

rem Provider Log Level (leave empty for default)
rem 0=None, 1=Critical, 2=Fatal, 3=Error, 4=Warning, 5=Info, 6=Verbose, 7=Debug
SET PROLEVEL=7
rem SET LOGLEVEL=

logman create trace heEventLogSession_1 -o HE_KE300dll.etl -ets -p {DD61CD53-BB41-4b3f-A881-BA7D75DE22E9} %PROFLAGS% %PROLEVEL% -f bincirc -nb 16 256 -bs 64 -max %MAXSIZE%

rem SET prm=%1
rem if prm==1 (
rem echo Press any key to abort...
rem pause 2>&1 > nul 
rem )
