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

function Resolve-GodotConsoleExecutable([string]$Candidate) {
    if ([string]::IsNullOrWhiteSpace($Candidate) -or -not (Test-Path -LiteralPath $Candidate -PathType Leaf)) {
        return $null
    }

    $resolvedCandidate = (Resolve-Path -LiteralPath $Candidate).Path
    $fileName = [System.IO.Path]::GetFileName($resolvedCandidate)
    if ($fileName -match '(?i)(^godot_console|_console)\.exe$') {
        return $resolvedCandidate
    }

    $directory = [System.IO.Path]::GetDirectoryName($resolvedCandidate)
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($resolvedCandidate)
    $companions = @(
        (Join-Path $directory 'godot_console.exe'),
        (Join-Path $directory ("{0}_console.exe" -f $baseName))
    )
    foreach ($companion in $companions) {
        if (Test-Path -LiteralPath $companion -PathType Leaf) {
            return (Resolve-Path -LiteralPath $companion).Path
        }
    }
    return $null
}

if ([string]::IsNullOrWhiteSpace($GodotPath)) {
    $candidates = @(
        $env:GODOT_BIN,
        (Join-Path $env:LOCALAPPDATA 'Programs\Godot\4.7\godot_console.exe')
    )
} else {
    $candidates = @($GodotPath)
}

$GodotPath = $null
foreach ($candidate in $candidates) {
    $GodotPath = Resolve-GodotConsoleExecutable $candidate
    if (-not [string]::IsNullOrWhiteSpace($GodotPath)) {
        break
    }
}

if ([string]::IsNullOrWhiteSpace($GodotPath)) {
    [Console]::Error.WriteLine('Godot 4.7 console executable was not found. Set GODOT_BIN or pass -GodotPath.')
    exit 1
}

Write-Output "GODOT TEST EXECUTABLE: $GodotPath"

$arguments = @(
    '--headless',
    '--path',
    ('"{0}"' -f $repositoryRoot),
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
    $process = Start-Process -FilePath $GodotPath `
        -ArgumentList $arguments `
        -Wait `
        -PassThru `
        -NoNewWindow `
        -RedirectStandardOutput $stdoutPath `
        -RedirectStandardError $stderrPath
    $godotExitCode = $process.ExitCode
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

    if (
        [string]::IsNullOrWhiteSpace($Suite) -and
        $RunnerScript -eq 'res://tests/test_runner.gd'
    ) {
        & (Join-Path $repositoryRoot 'tests\tools\test_task_3_review.ps1')
    }

    Write-Output 'GODOT TEST WRAPPER PASSED'
    exit 0
} finally {
    Remove-Item -LiteralPath $captureDirectory -Recurse -Force -ErrorAction SilentlyContinue
}
