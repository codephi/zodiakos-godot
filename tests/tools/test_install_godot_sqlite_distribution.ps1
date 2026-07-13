[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$sourceInstaller = Join-Path $repositoryRoot 'tools\install_godot_sqlite.ps1'
$vendoredLicense = Join-Path $repositoryRoot 'addons\godot-sqlite\LICENSE.md'
$expectedLicenseHash = '24f129f1d5ce9913b4408e09bb74f50259dd10bb8b4b49478ff5a0d2c977fa60'
$temporaryRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath()).TrimEnd('\')
$sandboxRoot = Join-Path $temporaryRoot ("zodiakos-sqlite-distribution-{0}" -f [guid]::NewGuid())
$projectRoot = Join-Path $sandboxRoot 'project'
$fixtureRoot = Join-Path $sandboxRoot 'fixture'
$fixtureAddon = Join-Path $fixtureRoot 'demo\addons\godot-sqlite'
$fixtureArchive = Join-Path $sandboxRoot 'fixture.zip'
$fixtureLicense = Join-Path $sandboxRoot 'LICENSE.md'
$extensionList = Join-Path $projectRoot '.godot\extension_list.cfg'
$sqliteExtension = 'res://addons/godot-sqlite/gdsqlite.gdextension'
$existingExtension = 'res://addons/existing/example.gdextension'

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

function Assert-ExtensionList {
    $bytes = [System.IO.File]::ReadAllBytes($extensionList)
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xef -and $bytes[1] -eq 0xbb -and $bytes[2] -eq 0xbf) {
        throw 'extension_list.cfg contains an UTF-8 BOM.'
    }
    $entries = @(Get-Content -LiteralPath $extensionList | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if (@($entries | Where-Object { $_ -eq $existingExtension }).Count -ne 1) {
        throw "Installer did not preserve the existing extension registration: $($entries -join ', ')"
    }
    if (@($entries | Where-Object { $_ -eq $sqliteExtension }).Count -ne 1) {
        throw 'Installer did not register SQLite exactly once.'
    }
}

try {
    New-Item -ItemType Directory -Path (Join-Path $projectRoot 'tools') -Force | Out-Null
    New-Item -ItemType Directory -Path $fixtureAddon -Force | Out-Null
    New-Item -ItemType Directory -Path (Split-Path $extensionList) -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $fixtureAddon 'gdsqlite.gdextension') -Value '[configuration]' -Encoding ascii
    Set-Content -LiteralPath $fixtureLicense -Value 'fixture license from the pinned tag' -Encoding ascii
    Compress-Archive -Path (Join-Path $fixtureRoot '*') -DestinationPath $fixtureArchive
    Copy-Item -LiteralPath $sourceInstaller -Destination (Join-Path $projectRoot 'tools\install_godot_sqlite.ps1')
    [System.IO.File]::WriteAllText(
        $extensionList,
        "$existingExtension`n",
        [System.Text.UTF8Encoding]::new($true)
    )

    function Invoke-WebRequest {
        param([string]$Uri, [string]$OutFile)
        if ($Uri.EndsWith('/demo.zip', [System.StringComparison]::Ordinal)) {
            Copy-Item -LiteralPath $fixtureArchive -Destination $OutFile
            return
        }
        if ($Uri.EndsWith('/LICENSE.md', [System.StringComparison]::Ordinal)) {
            Copy-Item -LiteralPath $fixtureLicense -Destination $OutFile
            return
        }
        throw "Unexpected download URL: $Uri"
    }
    function Get-FileHash {
        param([string]$LiteralPath, [string]$Algorithm)
        $hash = if ($LiteralPath.EndsWith('.zip', [System.StringComparison]::OrdinalIgnoreCase)) {
            '26966044757cf86a223a8027f8bc88c49c289ab047dcf8138bb591d7632e580e'
        } else {
            $expectedLicenseHash
        }
        return [pscustomobject]@{ Hash = $hash }
    }

    . (Join-Path $projectRoot 'tools\install_godot_sqlite.ps1')
    $installedLicense = Join-Path $projectRoot 'addons\godot-sqlite\LICENSE.md'
    if (-not (Test-Path -LiteralPath $installedLicense -PathType Leaf)) {
        throw 'Installer did not include the pinned upstream license.'
    }
    if ((Get-Content -Raw -LiteralPath $installedLicense) -ne (Get-Content -Raw -LiteralPath $fixtureLicense)) {
        throw 'Installed license differs from the pinned license download.'
    }
    Assert-ExtensionList

    . (Join-Path $projectRoot 'tools\install_godot_sqlite.ps1')
    Assert-ExtensionList

    if (-not (Test-Path -LiteralPath $vendoredLicense -PathType Leaf)) {
        throw 'Vendored upstream license is missing.'
    }
    $actualLicenseHash = (Microsoft.PowerShell.Utility\Get-FileHash -LiteralPath $vendoredLicense -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actualLicenseHash -ne $expectedLicenseHash) {
        throw "Vendored upstream license hash mismatch: $actualLicenseHash"
    }

    Write-Output 'INSTALLER DISTRIBUTION TESTS PASSED'
} finally {
    $sandboxRoot = Assert-SafeSandboxTree $sandboxRoot 'zodiakos-sqlite-distribution-'
    if (Test-Path -LiteralPath $sandboxRoot) {
        Remove-Item -LiteralPath $sandboxRoot -Recurse -Force
    }
}
