@echo off
rem 
rem 	Show information about a trace session
rem
rem WARNING:  
rem	Before running this, a trace session must exist.
rem     Run either ETWTraceViewer.exe or run trace_start.bat
rem

logman query heEventLogSession_1 -ets

echo Press any key to abort...
pause 2>&1 > nul

