[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$sourceInstaller = Join-Path $repositoryRoot 'tools\install_godot_sqlite.ps1'
$temporaryRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath()).TrimEnd('\')
$sandboxRoot = Join-Path $temporaryRoot ("zodiakos-sqlite-safety-{0}" -f [guid]::NewGuid())
$projectRoot = Join-Path $sandboxRoot 'project'
$externalRoot = Join-Path $sandboxRoot 'external'
$junctionPath = Join-Path $projectRoot 'addons'
$externalAddon = Join-Path $externalRoot 'godot-sqlite'
$sentinel = Join-Path $externalAddon 'sentinel.txt'
$fixtureRoot = Join-Path $sandboxRoot 'fixture'
$fixtureAddon = Join-Path $fixtureRoot 'demo\addons\godot-sqlite'
$fixtureArchive = Join-Path $sandboxRoot 'fixture.zip'

function Assert-SafeSandboxTree([string]$Candidate, [string]$ExpectedPrefix) {
    $canonicalCandidate = [System.IO.Path]::GetFullPath($Candidate)
    $candidateParent = [System.IO.Path]::GetDirectoryName($canonicalCandidate).TrimEnd('\')
    $candidateName = [System.IO.Path]::GetFileName($canonicalCandidate)
    if (-not $candidateParent.Equals($temporaryRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Sandbox is outside TEMP: $canonicalCandidate"
    }
    if (-not $candidateName.StartsWith($ExpectedPrefix, [System.StringComparison]::Ordinal)) {
        throw "Sandbox has an unexpected name: $canonicalCandidate"
    }

    foreach ($componentPath in @($temporaryRoot, $canonicalCandidate)) {
        if (-not (Test-Path -LiteralPath $componentPath)) {
            continue
        }
        $resolvedComponent = (Resolve-Path -LiteralPath $componentPath).Path
        if (-not $resolvedComponent.Equals($componentPath, [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "Sandbox component resolved to an unexpected path: $resolvedComponent"
        }
        $componentItem = Get-Item -LiteralPath $componentPath -Force
        if (($componentItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "Sandbox component cannot be a reparse point: $componentPath"
        }
    }
    return $canonicalCandidate
}

try {
    New-Item -ItemType Directory -Path (Join-Path $projectRoot 'tools') -Force | Out-Null
    New-Item -ItemType Directory -Path $externalAddon -Force | Out-Null
    New-Item -ItemType Directory -Path $fixtureAddon -Force | Out-Null
    Set-Content -LiteralPath $sentinel -Value 'must survive' -Encoding ascii
    Set-Content -LiteralPath (Join-Path $fixtureAddon 'gdsqlite.gdextension') -Value '[configuration]' -Encoding ascii
    Set-Content -LiteralPath (Join-Path $fixtureAddon 'LICENSE') -Value 'fixture license' -Encoding ascii
    Compress-Archive -Path (Join-Path $fixtureRoot '*') -DestinationPath $fixtureArchive
    Copy-Item -LiteralPath $sourceInstaller -Destination (Join-Path $projectRoot 'tools\install_godot_sqlite.ps1')
    New-Item -ItemType Junction -Path $junctionPath -Target $externalRoot | Out-Null

    function Invoke-WebRequest {
        param([string]$Uri, [string]$OutFile)
        Copy-Item -LiteralPath $fixtureArchive -Destination $OutFile
    }
    function Get-FileHash {
        param([string]$LiteralPath, [string]$Algorithm)
        return [pscustomobject]@{
            Hash = '26966044757cf86a223a8027f8bc88c49c289ab047dcf8138bb591d7632e580e'
        }
    }

    $rejected = $false
    try {
        . (Join-Path $projectRoot 'tools\install_godot_sqlite.ps1')
    } catch {
        if ($_.Exception.Message -match 'reparse point') {
            $rejected = $true
        } else {
            throw
        }
    }

    if (-not (Test-Path -LiteralPath $sentinel -PathType Leaf)) {
        throw 'Installer changed data outside the project through the addons junction.'
    }
    if (-not $rejected) {
        throw 'Installer did not reject an addons junction.'
    }

    Write-Output 'INSTALLER JUNCTION SAFETY PASSED'
} finally {
    if (Test-Path -LiteralPath $junctionPath) {
        $junctionItem = Get-Item -LiteralPath $junctionPath -Force
        if (($junctionItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -eq 0) {
            throw "Expected cleanup path to remain a junction: $junctionPath"
        }
        Remove-Item -LiteralPath $junctionPath -Force
    }
    if (Test-Path -LiteralPath $junctionPath) {
        throw "Cleanup junction still exists: $junctionPath"
    }
    if (-not (Test-Path -LiteralPath $sentinel -PathType Leaf)) {
        throw 'External sentinel was changed before sandbox cleanup.'
    }
    $sandboxRoot = Assert-SafeSandboxTree $sandboxRoot 'zodiakos-sqlite-safety-'
    if (Test-Path -LiteralPath $sandboxRoot) {
        Remove-Item -LiteralPath $sandboxRoot -Recurse -Force
    }
}
