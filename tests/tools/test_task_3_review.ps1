$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$generatorPath = Join-Path $repositoryRoot 'scripts\domain\universe\universe_generator.gd'
$generatorSource = Get-Content -Raw -LiteralPath $generatorPath
$typedContract = 'func generate_sector\(coordinate: SectorCoordinate\) -> UniverseSector:'

if ($generatorSource -notmatch $typedContract) {
    throw 'UniverseGenerator.generate_sector does not expose the required typed contract.'
}

$wrapperPath = Join-Path $repositoryRoot 'tools\run_godot_tests.ps1'
if (-not (Test-Path -LiteralPath $wrapperPath -PathType Leaf)) {
    throw 'The native Godot test wrapper does not exist.'
}

function Invoke-WrapperProcess([string[]]$Arguments) {
    $captureDirectory = Join-Path ([System.IO.Path]::GetTempPath()) ("zodiakos-wrapper-check-{0}" -f [guid]::NewGuid())
    $stdoutPath = Join-Path $captureDirectory 'stdout.txt'
    $stderrPath = Join-Path $captureDirectory 'stderr.txt'
    New-Item -ItemType Directory -Path $captureDirectory | Out-Null
    try {
        $processArguments = @('-NoProfile', '-File', $wrapperPath) + $Arguments
        $process = Start-Process -FilePath (Get-Process -Id $PID).Path `
            -ArgumentList $processArguments `
            -Wait `
            -PassThru `
            -NoNewWindow `
            -RedirectStandardOutput $stdoutPath `
            -RedirectStandardError $stderrPath
        $stdout = if (Test-Path -LiteralPath $stdoutPath) { Get-Content -Raw -LiteralPath $stdoutPath } else { '' }
        $stderr = if (Test-Path -LiteralPath $stderrPath) { Get-Content -Raw -LiteralPath $stderrPath } else { '' }
        return [pscustomobject]@{
            ExitCode = $process.ExitCode
            Output = $stdout + $stderr
        }
    } finally {
        Remove-Item -LiteralPath $captureDirectory -Recurse -Force -ErrorAction SilentlyContinue
    }
}

$originalGodotBin = $env:GODOT_BIN
try {
    $env:GODOT_BIN = Join-Path $env:LOCALAPPDATA 'Programs\Godot\4.7\Godot_v4.7-stable_win64.exe'
    $focusedResult = Invoke-WrapperProcess @(
        '-Suite',
        'res://tests/domain/universe/test_universe_generator.gd'
    )
    if ($focusedResult.ExitCode -ne 0) {
        throw "Focused wrapper run failed with GUI GODOT_BIN:`n$($focusedResult.Output)"
    }
    $focusedText = $focusedResult.Output
    if ($focusedText -notmatch 'TESTS PASSED') {
        throw 'Focused wrapper run did not preserve the Godot success marker.'
    }
    if ($focusedText -notmatch 'godot_console\.exe') {
        throw 'Wrapper did not resolve GUI GODOT_BIN to the console companion.'
    }
} finally {
    $env:GODOT_BIN = $originalGodotBin
}

$runtimeErrorResult = Invoke-WrapperProcess @(
    '-RunnerScript',
    'res://tests/fixtures/runtime_error_test_runner.gd'
)
if ($runtimeErrorResult.ExitCode -eq 0) {
    throw "Wrapper accepted Godot stderr alongside TESTS PASSED:`n$($runtimeErrorResult.Output)"
}
$runtimeErrorText = $runtimeErrorResult.Output
if ($runtimeErrorText -notmatch 'missing_runtime_method') {
    throw "Wrapper failure did not expose the runtime error:`n$runtimeErrorText"
}

Write-Output 'TASK 3 REVIEW CHECKS PASSED'
