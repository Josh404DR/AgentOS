@echo off
setlocal

:: Strategy 1: User-defined environment variable
if not "%FAN_CONTROL_PYTHON%"=="" (
    set "PYTHON_EXE=%FAN_CONTROL_PYTHON%"
    goto :run_custom
)

:: Strategy 2: Python Launcher (py -3.13)
py -3.13 --version >nul 2>&1
if %errorlevel% equ 0 (
    py -3.13 "%~dp0main.py" %*
    exit /b %errorlevel%
)

:: Strategy 3: Generic Python Launcher (py)
py --version >nul 2>&1
if %errorlevel% equ 0 (
    py "%~dp0main.py" %*
    exit /b %errorlevel%
)

:: Failure Case: No usable Python found
echo STATUS=ERROR
echo ACTION=RUNNER_INIT
echo TEMPERATURE=UNKNOWN
echo MESSAGE=No usable Python interpreter found. Please set FAN_CONTROL_PYTHON environment variable to the full path of your python.exe.
exit /b 1

:run_custom
"%PYTHON_EXE%" "%~dp0main.py" %*
exit /b %errorlevel%
