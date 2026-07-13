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

$powerShellPath = (Get-Process -Id $PID).Path
$focusedOutput = & $powerShellPath -NoProfile -File $wrapperPath `
    -Suite 'res://tests/domain/universe/test_universe_generator.gd' 2>&1
if ($LASTEXITCODE -ne 0) {
    throw "Focused wrapper run failed:`n$($focusedOutput -join [Environment]::NewLine)"
}
if (($focusedOutput -join [Environment]::NewLine) -notmatch 'TESTS PASSED') {
    throw 'Focused wrapper run did not preserve the Godot success marker.'
}

$runtimeErrorOutput = & $powerShellPath -NoProfile -File $wrapperPath `
    -RunnerScript 'res://tests/fixtures/runtime_error_test_runner.gd' 2>&1
if ($LASTEXITCODE -eq 0) {
    throw "Wrapper accepted Godot stderr alongside TESTS PASSED:`n$($runtimeErrorOutput -join [Environment]::NewLine)"
}

Write-Output 'TASK 3 REVIEW CHECKS PASSED'
exit 0
