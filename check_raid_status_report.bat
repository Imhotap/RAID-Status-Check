@echo off
cd /d "%~dp0"
if exist "%~dp0check_raid_status_report.py" (
  where python >nul 2>&1 && python "%~dp0check_raid_status_report.py" && exit /b %ERRORLEVEL%
  where py >nul 2>&1 && py "%~dp0check_raid_status_report.py" && exit /b %ERRORLEVEL%
  echo Neither python nor py was found on the PATH.
  exit /b 1
) else (
  echo Python script not found in %~dp0
  exit /b 2
)
