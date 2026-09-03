# Launch COMSOL MCP on Windows with the 6.2 Multiphysics_copy1 install on PATH.
param()
$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $env:COMSOL_ROOT) {
    $env:COMSOL_ROOT = "C:\Program Files\COMSOL\COMSOL62\Multiphysics_copy1"
}
$env:COMSOLROOT = $env:COMSOL_ROOT
$env:Path = "$(Join-Path $env:COMSOL_ROOT 'bin\win64');$env:Path"

$launcher = Join-Path $ScriptDir "run_comsol_mcp.py"
$py = Get-Command py -ErrorAction SilentlyContinue
if ($py) {
    & $py.Source -3 $launcher @args
    exit $LASTEXITCODE
}
$python = Get-Command python -ErrorAction SilentlyContinue
if ($python) {
    & $python.Source $launcher @args
    exit $LASTEXITCODE
}
Write-Error "Python 3.10+ is required to run COMSOL MCP."
exit 1
