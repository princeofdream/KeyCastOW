#Requires -Version 5.1
<#
.SYNOPSIS
    Build KeyCastOW with CMake.

.DESCRIPTION
    Locates a Visual C++ toolchain (vcvars32.bat), configures the project with
    CMake and builds it. Ninja is used when available, otherwise NMake Makefiles.

.PARAMETER Configuration
    Build configuration: Release (default) or Debug.

.PARAMETER Clean
    Delete the build directory and exit.

.EXAMPLE
    .\build.ps1

.EXAMPLE
    .\build.ps1 -Configuration Debug
#>
[CmdletBinding()]
param(
    [ValidateSet('Debug', 'Release')]
    [string]$Configuration = 'Release',

    [switch]$Clean
)

$ErrorActionPreference = 'Stop'

$Root = $PSScriptRoot
$BuildDir = Join-Path $Root 'build'
$OutputDir = Join-Path $Root 'output\target'

function Write-Step([string]$Message) {
    Write-Host "==> $Message" -ForegroundColor Cyan
}

if ($Clean) {
    Write-Step "Cleaning '$BuildDir' and '$OutputDir'"
    Remove-Item -LiteralPath $BuildDir -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath (Join-Path $Root 'output') -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host 'Done.'
    exit 0
}

function Get-CMakePath {
    $command = Get-Command cmake.exe -ErrorAction SilentlyContinue
    if ($command) { return $command.Source }

    $candidates = @(
        (Join-Path $env:ProgramFiles 'CMake\bin\cmake.exe'),
        (Join-Path ${env:ProgramFiles(x86)} 'CMake\bin\cmake.exe'),
        (Join-Path $env:LOCALAPPDATA 'Programs\CMake\bin\cmake.exe')
    )
    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate) { return $candidate }
    }

    throw 'cmake.exe not found. Install CMake 3.20 or newer and make sure it is on PATH.'
}

function Find-VcVars32 {
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    $candidates = @()

    if (Test-Path -LiteralPath $vswhere) {
        $installs = & $vswhere -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath 2>$null
        foreach ($install in $installs) {
            $candidates += Join-Path $install 'VC\Auxiliary\Build\vcvars32.bat'
        }
    }

    # Fallback: scan common Visual Studio / Build Tools locations, newest first.
    $roots = @(
        (Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio'),
        (Join-Path $env:ProgramFiles 'Microsoft Visual Studio')
    )
    foreach ($root in $roots) {
        if (-not (Test-Path -LiteralPath $root)) { continue }
        $versions = Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue |
            Sort-Object Name -Descending
        foreach ($version in $versions) {
            $editions = Get-ChildItem -LiteralPath $version.FullName -Directory -ErrorAction SilentlyContinue
            foreach ($edition in $editions) {
                $candidates += Join-Path $edition.FullName 'VC\Auxiliary\Build\vcvars32.bat'
            }
        }
    }

    foreach ($candidate in ($candidates | Select-Object -Unique)) {
        if (Test-Path -LiteralPath $candidate) { return $candidate }
    }

    return $null
}

function Import-VcEnvironment([string]$VcVars) {
    Write-Step "Using toolchain: $VcVars"

    $lines = & cmd.exe /c "`"$VcVars`" >nul 2>&1 && set"
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to initialize the Visual C++ environment: $VcVars"
    }

    foreach ($line in $lines) {
        if ($line -match '^([^=]+)=(.*)$') {
            Set-Item -Path ("env:" + $matches[1]) -Value $matches[2]
        }
    }
}

$vcvars = Find-VcVars32
if (-not $vcvars) {
    throw 'Visual C++ build tools not found (vcvars32.bat). Install Visual Studio Build Tools with the C++ workload.'
}
Import-VcEnvironment $vcvars

$cmake = Get-CMakePath

if (Get-Command ninja.exe -ErrorAction SilentlyContinue) {
    $generator = 'Ninja'
}
else {
    $generator = 'NMake Makefiles'
    Write-Host 'Ninja not found, falling back to NMake Makefiles.' -ForegroundColor Yellow
}

Write-Step "Configuring ($generator, $Configuration)"
& $cmake -S $Root -B $BuildDir -G $generator "-DCMAKE_BUILD_TYPE=$Configuration"
if ($LASTEXITCODE -ne 0) { throw 'CMake configuration failed.' }

Write-Step 'Building'
& $cmake --build $BuildDir --config $Configuration
if ($LASTEXITCODE -ne 0) { throw 'Build failed.' }

$exe = Join-Path $OutputDir $Configuration\keycastow.exe
if (-not (Test-Path -LiteralPath $exe)) {
    throw "Build finished but '$exe' was not found."
}

$size = (Get-Item -LiteralPath $exe).Length
Write-Host ("Built {0} ({1:N0} bytes)" -f $exe, $size) -ForegroundColor Green
