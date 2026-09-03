@echo off
setlocal EnableExtensions
set "SCRIPT_DIR=%~dp0"
if "%COMSOL_ROOT%"=="" set "COMSOL_ROOT=C:\Program Files\COMSOL\COMSOL62\Multiphysics_copy1"
if "%COMSOLROOT%"=="" set "COMSOLROOT=%COMSOL_ROOT%"
if "%COMSOL_MCP_HOME%"=="" set "COMSOL_MCP_HOME=%SCRIPT_DIR%..\COMSOL_Multiphysics_MCP"
set "PATH=%COMSOL_ROOT%\bin\win64;%PATH%"

where py >nul 2>&1
if %ERRORLEVEL%==0 (
  py -3 "%SCRIPT_DIR%run_comsol_mcp.py" %*
  exit /b %ERRORLEVEL%
)
where python >nul 2>&1
if %ERRORLEVEL%==0 (
  python "%SCRIPT_DIR%run_comsol_mcp.py" %*
  exit /b %ERRORLEVEL%
)
where python3 >nul 2>&1
if %ERRORLEVEL%==0 (
  python3 "%SCRIPT_DIR%run_comsol_mcp.py" %*
  exit /b %ERRORLEVEL%
)

echo Python 3.10+ is required to run COMSOL MCP. Install Python and retry. >&2
exit /b 1
