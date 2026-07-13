[CmdletBinding()]
param(
    [string]$Suite = '',
    [string]$RunnerScript = 'res://tests/test_runner.gd',
    [string]$GodotPath = ''
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (Test-Path Variable:PSNativeCommandUseErrorActionPreference) {
    $PSNativeCommandUseErrorActionPreference = $false
}

$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

if ([string]::IsNullOrWhiteSpace($GodotPath)) {
    $candidates = @(
        $env:GODOT_BIN,
        (Join-Path $env:LOCALAPPDATA 'Programs\Godot\4.7\godot_console.exe')
    )
    foreach ($candidate in $candidates) {
        if (-not [string]::IsNullOrWhiteSpace($candidate) -and (Test-Path -LiteralPath $candidate -PathType Leaf)) {
            $GodotPath = $candidate
            break
        }
    }
}

if ([string]::IsNullOrWhiteSpace($GodotPath) -or -not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
    [Console]::Error.WriteLine('Godot 4.7 console executable was not found. Set GODOT_BIN or pass -GodotPath.')
    exit 1
}

$arguments = @(
    '--headless',
    '--path',
    $repositoryRoot,
    '--script',
    $RunnerScript,
    '--quit-after',
    '5'
)
if (-not [string]::IsNullOrWhiteSpace($Suite)) {
    $arguments += '--'
    $arguments += "--test-suite=$Suite"
}

$captureDirectory = Join-Path ([System.IO.Path]::GetTempPath()) ("zodiakos-tests-{0}" -f [guid]::NewGuid())
$stdoutPath = Join-Path $captureDirectory 'stdout.txt'
$stderrPath = Join-Path $captureDirectory 'stderr.txt'
New-Item -ItemType Directory -Path $captureDirectory | Out-Null

try {
    & $GodotPath @arguments 1> $stdoutPath 2> $stderrPath
    $godotExitCode = $LASTEXITCODE
    $stdout = if (Test-Path -LiteralPath $stdoutPath) {
        Get-Content -Raw -LiteralPath $stdoutPath
    } else {
        ''
    }
    $stderr = if (Test-Path -LiteralPath $stderrPath) {
        Get-Content -Raw -LiteralPath $stderrPath
    } else {
        ''
    }

    if (-not [string]::IsNullOrEmpty($stdout)) {
        [Console]::Out.Write($stdout)
    }
    if (-not [string]::IsNullOrEmpty($stderr)) {
        [Console]::Error.Write($stderr)
    }

    $failures = @()
    if ($godotExitCode -ne 0) {
        $failures += "Godot exited with code $godotExitCode."
    }
    if ($stdout -notmatch '(?m)^TESTS PASSED\s*$') {
        $failures += 'Godot output did not contain TESTS PASSED.'
    }
    if (-not [string]::IsNullOrWhiteSpace($stderr)) {
        $failures += 'Godot wrote to stderr.'
    }
    if ($failures.Count -gt 0) {
        [Console]::Error.WriteLine(($failures -join ' '))
        exit 1
    }

    Write-Output 'GODOT TEST WRAPPER PASSED'
    exit 0
} finally {
    Remove-Item -LiteralPath $captureDirectory -Recurse -Force -ErrorAction SilentlyContinue
}
