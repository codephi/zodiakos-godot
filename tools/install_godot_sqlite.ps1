[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$url = 'https://github.com/2shady4u/godot-sqlite/releases/download/v4.7/demo.zip'
$expectedChecksum = '26966044757cf86a223a8027f8bc88c49c289ab047dcf8138bb591d7632e580e'
$licenseUrl = 'https://raw.githubusercontent.com/2shady4u/godot-sqlite/v4.7/LICENSE.md'
$expectedLicenseChecksum = '24f129f1d5ce9913b4408e09bb74f50259dd10bb8b4b49478ff5a0d2c977fa60'
$temporaryRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath()).TrimEnd('\')
$temporary = Join-Path $temporaryRoot ("godot-sqlite-v4.7-{0}" -f [guid]::NewGuid())
$archive = "$temporary.zip"
$license = "$temporary-LICENSE.md"

function Assert-NoReparsePointPathComponents([string]$RootPath, [string]$Candidate) {
    $canonicalRoot = [System.IO.Path]::GetFullPath($RootPath).TrimEnd('\')
    $canonicalCandidate = [System.IO.Path]::GetFullPath($Candidate)
    $rootPrefix = "$canonicalRoot\"
    if (
        -not $canonicalCandidate.Equals($canonicalRoot, [System.StringComparison]::OrdinalIgnoreCase) -and
        -not $canonicalCandidate.StartsWith($rootPrefix, [System.StringComparison]::OrdinalIgnoreCase)
    ) {
        throw "Path is outside the repository root: $canonicalCandidate"
    }

    $relativeCandidate = $canonicalCandidate.Substring($canonicalRoot.Length).TrimStart([char[]]@('\', '/'))
    $components = @($canonicalRoot)
    $currentPath = $canonicalRoot
    foreach ($component in @($relativeCandidate -split '[\\/]') | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) {
        $currentPath = Join-Path $currentPath $component
        $components += $currentPath
    }

    foreach ($componentPath in $components) {
        if (-not (Test-Path -LiteralPath $componentPath)) {
            continue
        }
        $componentItem = Get-Item -LiteralPath $componentPath -Force
        if (($componentItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "Repository destination contains a reparse point: $componentPath"
        }
    }
}

function Assert-SafeDestination([string]$Candidate) {
    $expectedDestination = [System.IO.Path]::GetFullPath(
        (Join-Path $root 'addons\godot-sqlite')
    )
    $canonicalCandidate = [System.IO.Path]::GetFullPath($Candidate)
    if (-not $canonicalCandidate.Equals($expectedDestination, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Unsafe Godot-SQLite destination: $canonicalCandidate"
    }
    Assert-NoReparsePointPathComponents $root $canonicalCandidate

    if (Test-Path -LiteralPath $canonicalCandidate) {
        $resolvedCandidate = (Resolve-Path -LiteralPath $canonicalCandidate).Path
        if (-not $resolvedCandidate.Equals($expectedDestination, [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "Godot-SQLite destination resolved outside the expected path: $resolvedCandidate"
        }
        $destinationItem = Get-Item -LiteralPath $canonicalCandidate -Force
        if (($destinationItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "Godot-SQLite destination cannot be a reparse point: $canonicalCandidate"
        }
    }

    return $canonicalCandidate
}

function Assert-SafeTemporaryDirectory([string]$Candidate) {
    $canonicalCandidate = [System.IO.Path]::GetFullPath($Candidate)
    $candidateParent = [System.IO.Path]::GetDirectoryName($canonicalCandidate).TrimEnd('\')
    $candidateName = [System.IO.Path]::GetFileName($canonicalCandidate)
    if (-not $candidateParent.Equals($temporaryRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Temporary directory is outside TEMP: $canonicalCandidate"
    }
    if (-not $candidateName.StartsWith('godot-sqlite-v4.7-', [System.StringComparison]::Ordinal)) {
        throw "Temporary directory has an unexpected name: $canonicalCandidate"
    }

    if (Test-Path -LiteralPath $canonicalCandidate) {
        $temporaryItem = Get-Item -LiteralPath $canonicalCandidate -Force
        if (($temporaryItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "Temporary directory cannot be a reparse point: $canonicalCandidate"
        }
    }

    return $canonicalCandidate
}

$destination = Assert-SafeDestination (Join-Path $root 'addons\godot-sqlite')
$temporary = Assert-SafeTemporaryDirectory $temporary

try {
    Invoke-WebRequest -Uri $url -OutFile $archive
    $actualChecksum = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actualChecksum -ne $expectedChecksum) {
        throw "Godot-SQLite checksum mismatch: $actualChecksum"
    }
    Invoke-WebRequest -Uri $licenseUrl -OutFile $license
    $actualLicenseChecksum = (Get-FileHash -LiteralPath $license -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actualLicenseChecksum -ne $expectedLicenseChecksum) {
        throw "Godot-SQLite license checksum mismatch: $actualLicenseChecksum"
    }

    Expand-Archive -LiteralPath $archive -DestinationPath $temporary
    $extension = Get-ChildItem -Path $temporary -Recurse -Filter gdsqlite.gdextension |
        Select-Object -First 1
    if ($null -eq $extension) {
        throw 'gdsqlite.gdextension was not present in the release archive.'
    }

    $destination = Assert-SafeDestination $destination
    New-Item -ItemType Directory -Path (Split-Path $destination) -Force | Out-Null
    $destination = Assert-SafeDestination $destination
    if (Test-Path -LiteralPath $destination) {
        Remove-Item -LiteralPath $destination -Recurse -Force
    }
    $destination = Assert-SafeDestination $destination
    Copy-Item -LiteralPath $extension.Directory.FullName -Destination $destination -Recurse
    $destination = Assert-SafeDestination $destination
    Copy-Item -LiteralPath $license -Destination (Join-Path $destination 'LICENSE.md')

    # Direct Godot runs need this cache entry when the editor cache predates the addon.
    $extensionListDirectory = Join-Path $root '.godot'
    $extensionListPath = Join-Path $extensionListDirectory 'extension_list.cfg'
    New-Item -ItemType Directory -Path $extensionListDirectory -Force | Out-Null
    $registeredExtensions = @(
        if (Test-Path -LiteralPath $extensionListPath) {
            Get-Content -LiteralPath $extensionListPath |
                Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        }
    )
    $extensionResourcePath = 'res://addons/godot-sqlite/gdsqlite.gdextension'
    if ($registeredExtensions -notcontains $extensionResourcePath) {
        $registeredExtensions += $extensionResourcePath
    }
    [System.IO.File]::WriteAllLines(
        $extensionListPath,
        [string[]]$registeredExtensions,
        [System.Text.UTF8Encoding]::new($false)
    )
} finally {
    Remove-Item -LiteralPath $archive -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $license -Force -ErrorAction SilentlyContinue
    $temporary = Assert-SafeTemporaryDirectory $temporary
    Remove-Item -LiteralPath $temporary -Recurse -Force -ErrorAction SilentlyContinue
}
