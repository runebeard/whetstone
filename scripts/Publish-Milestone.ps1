param(
    [Parameter(Mandatory)]
    [ValidatePattern('\A[A-Za-z0-9]+(?:[.-][A-Za-z0-9]+)*\z')]
    [string]$Milestone,
    [switch]$BuildAndroid
)

$ErrorActionPreference = 'Stop'

function Invoke-Checked {
    param([string]$Program, [string[]]$Arguments)
    & $Program @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$Program failed with exit code $LASTEXITCODE."
    }
}

function Invoke-RecoveryFlutter {
    param([string[]]$FlutterArguments)
    $toolRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
    $flutterRoot = Join-Path $toolRoot 'flutter-sdk'
    $dart = Join-Path $flutterRoot 'bin/cache/dart-sdk/bin/dart.exe'
    $snapshot = Join-Path $flutterRoot 'bin/cache/flutter_tools.snapshot'
    if (!(Test-Path -LiteralPath $dart) -or !(Test-Path -LiteralPath $snapshot)) {
        Invoke-Checked flutter $FlutterArguments
        return
    }
    $verificationEnvironment = @{
        FLUTTER_ROOT = $flutterRoot
        APPDATA = (Join-Path $toolRoot 'flutter-appdata')
        TEMP = (Join-Path $toolRoot 'flutter-temp')
        TMP = (Join-Path $toolRoot 'flutter-temp')
        CI = 'true'
    }
    $savedEnvironment = @{}
    foreach ($name in $verificationEnvironment.Keys) {
        $savedEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
    }
    New-Item -ItemType Directory -Path $verificationEnvironment.APPDATA -Force | Out-Null
    New-Item -ItemType Directory -Path $verificationEnvironment.TEMP -Force | Out-Null
    try {
        foreach ($name in $verificationEnvironment.Keys) {
            [Environment]::SetEnvironmentVariable($name, $verificationEnvironment[$name], 'Process')
        }
        Invoke-Checked $dart (@($snapshot) + $FlutterArguments)
    } finally {
        foreach ($name in $savedEnvironment.Keys) {
            [Environment]::SetEnvironmentVariable($name, $savedEnvironment[$name], 'Process')
        }
    }
}

Push-Location (Join-Path $PSScriptRoot '..')
try {
    $branch = Invoke-Checked git @('branch', '--show-current')
    if ($branch -ne 'recovery/beta5') {
        throw 'Check out recovery/beta5 before publishing a milestone.'
    }
    $changes = Invoke-Checked git @('status', '--porcelain')
    if ($changes) {
        throw 'Commit the milestone and clean the working tree before publishing.'
    }
    $commit = Invoke-Checked git @('rev-parse', 'HEAD')
    $tag = "milestone/$Milestone"

    Invoke-RecoveryFlutter @('analyze', '--no-pub')
    Invoke-RecoveryFlutter @('test', '--no-pub')
    if ($BuildAndroid) {
        & (Join-Path $PSScriptRoot 'Build-Android.ps1')
    }

    $currentCommit = Invoke-Checked git @('rev-parse', 'HEAD')
    $changes = Invoke-Checked git @('status', '--porcelain')
    if ($currentCommit -ne $commit -or $changes) {
        throw 'The checkout changed during verification. Review it and retry.'
    }

    Invoke-Checked git @(
        'push', '--atomic', 'origin',
        "${commit}:refs/heads/recovery/beta5",
        "${commit}:refs/tags/$tag"
    )
} finally {
    Pop-Location
}
