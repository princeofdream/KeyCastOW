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
    Delete the build and output directories and exit.

.PARAMETER Package
    After building, create the portable zip and the NSIS installer in
    output/package. Always uses the Release configuration.

.PARAMETER Version
    Version string used for the package file names and installer metadata.

.EXAMPLE
    .\build.ps1

.EXAMPLE
    .\build.ps1 -Configuration Debug

.EXAMPLE
    .\build.ps1 -Package -Version 1.0.1
#>
[CmdletBinding()]
param(
    [ValidateSet('Debug', 'Release')]
    [string]$Configuration = 'Release',

    [switch]$Clean,

    [switch]$Package,

    [string]$Version = '1.0.0'
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

if ($Package -and $Configuration -ne 'Release') {
    Write-Host 'Packaging uses the Release build; ignoring -Configuration Debug.' -ForegroundColor Yellow
    $Configuration = 'Release'
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

function Get-MakensisPath {
    $command = Get-Command makensis.exe -ErrorAction SilentlyContinue
    if ($command) { return $command.Source }

    $candidates = @(
        (Join-Path ${env:ProgramFiles(x86)} 'NSIS\makensis.exe'),
        (Join-Path $env:ProgramFiles 'NSIS\makensis.exe'),
        (Join-Path $env:LOCALAPPDATA 'Programs\NSIS\makensis.exe'),
        (Join-Path $env:LOCALAPPDATA 'tauri\NSIS\Bin\makensis.exe'),
        (Join-Path $env:LOCALAPPDATA 'tauri\NSIS\makensis.exe')
    )
    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate) { return $candidate }
    }

    throw 'makensis.exe not found. Install NSIS (winget install NSIS.NSIS) to build the installer.'
}

function Get-FourPartVersion([string]$Value) {
    $parts = @($Value -split '[^\d]+' | Where-Object { $_ -ne '' })
    while ($parts.Count -lt 4) { $parts += '0' }
    return ($parts[0..3] -join '.')
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

if ($Package) {
    $packageDir = Join-Path $Root 'output\package'
    New-Item -ItemType Directory -Force -Path $packageDir | Out-Null

    Write-Step 'Creating portable zip'
    $stageDir = Join-Path $packageDir "KeyCastOW-$Version"
    if (Test-Path -LiteralPath $stageDir) {
        Remove-Item -LiteralPath $stageDir -Recurse -Force
    }
    New-Item -ItemType Directory -Force -Path $stageDir | Out-Null
    Copy-Item -LiteralPath $exe -Destination $stageDir
    Copy-Item -LiteralPath (Join-Path $Root 'README.md') -Destination $stageDir

    $zipPath = Join-Path $packageDir "KeyCastOW-$Version-portable.zip"
    if (Test-Path -LiteralPath $zipPath) {
        Remove-Item -LiteralPath $zipPath -Force
    }
    Compress-Archive -Path (Join-Path $stageDir '*') -DestinationPath $zipPath
    Remove-Item -LiteralPath $stageDir -Recurse -Force

    Write-Step 'Building installer'
    $makensis = Get-MakensisPath
    $version4 = Get-FourPartVersion $Version
    $exeDir = Split-Path -Parent $exe
    $nsi = Join-Path $Root 'installer\keycastow.nsi'
    & $makensis /V2 `
        "/DAPP_VERSION=$Version" `
        "/DAPP_VERSION4=$version4" `
        "/DSOURCE_DIR=$exeDir" `
        "/DOUTPUT_DIR=$packageDir" `
        "/DPROJECT_DIR=$Root" `
        $nsi
    if ($LASTEXITCODE -ne 0) { throw 'NSIS packaging failed.' }

    Write-Host 'Packages:'
    Get-ChildItem -LiteralPath $packageDir -File | Sort-Object Name | ForEach-Object {
        Write-Host ("  {0} ({1:N0} bytes)" -f $_.FullName, $_.Length) -ForegroundColor Green
    }
}
