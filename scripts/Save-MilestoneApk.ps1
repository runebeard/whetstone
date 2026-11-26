param(
    [Parameter(Mandatory)]
    [ValidatePattern('\A[A-Za-z0-9]+(?:[.-][A-Za-z0-9]+)*\z')]
    [string]$Milestone,
    [Parameter(Mandatory)]
    [ValidatePattern('\A[0-9a-f]{40}\z')]
    [string]$SourceCommit,
    [Parameter(Mandatory)][string]$TestLog
)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$toolRoot = Split-Path $repoRoot -Parent
$outputRoot = Join-Path (Split-Path $toolRoot -Parent) 'outputs'
$headCommit = & git -C $repoRoot rev-parse HEAD
if ($LASTEXITCODE -ne 0 -or $headCommit -ne $SourceCommit) { throw 'The source commit changed.' }
$changes = & git -C $repoRoot status --porcelain
if ($LASTEXITCODE -ne 0 -or $changes) { throw 'The source checkout must be clean.' }
$testText = Get-Content -LiteralPath $TestLog -Raw
$testResults = [regex]::Matches($testText, '\+(\d+): All tests passed!')
if ($testResults.Count -ne 1) { throw 'Expected one successful full-suite result.' }
$testCount = [int]$testResults[0].Groups[1].Value
if ($testCount -lt 1) { throw 'The verification log contains no passing tests.' }
$apk = Join-Path $repoRoot 'build/app/outputs/flutter-apk/app-debug.apk'
$buildTools = Join-Path $toolRoot 'android-sdk/build-tools/36.0.0'
$certificate = 'd858e643337689a7aee6a141a5d49a8771ff85c4d49ee6a3c0125eb93543e713'
$savedJava = $env:JAVA_HOME
try {
    if (!$env:JAVA_HOME -or !(Test-Path -LiteralPath (Join-Path $env:JAVA_HOME 'bin/java.exe'))) {
        $env:JAVA_HOME = 'C:/Program Files/Android/Android Studio/jbr'
    }
    $signature = & (Join-Path $buildTools 'apksigner.bat') verify --print-certs $apk
    if ($LASTEXITCODE -ne 0 -or !($signature -match $certificate)) { throw 'APK signing identity mismatch.' }
    $badging = & (Join-Path $buildTools 'aapt.exe') dump badging $apk
    if ($LASTEXITCODE -ne 0 -or !($badging -match "^package: name='com\.runebeard\.whetstone\.recovery'") -or
        !($badging -match "^application-label:'Whetstone Recovery'")) { throw 'APK package or launcher identity mismatch.' }
} finally {
    $env:JAVA_HOME = $savedJava
}

New-Item -ItemType Directory -Path $outputRoot -Force | Out-Null
$artifactName = "Whetstone-recovery-$Milestone-debug.apk"
$destination = Join-Path $outputRoot $artifactName
$hash = (Get-FileHash -LiteralPath $apk -Algorithm SHA256).Hash.ToLowerInvariant()
if (Test-Path -LiteralPath $destination) {
    if ((Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash.ToLowerInvariant() -ne $hash) {
        throw 'An APK with different contents already exists for this milestone. Use a new milestone name.'
    }
} else {
    Copy-Item -LiteralPath $apk -Destination $destination
}
if ((Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash.ToLowerInvariant() -ne $hash) {
    throw 'The preserved APK checksum does not match the build.'
}
$recordPath = "$destination.json"
if (Test-Path -LiteralPath $recordPath) {
    $previous = Get-Content -LiteralPath $recordPath -Raw | ConvertFrom-Json
    if ($previous.sourceCommit -ne $SourceCommit -or $previous.sha256 -ne $hash) {
        throw 'A different source record exists for this milestone. Use a new milestone name.'
    }
}
$verifiedDate = if ($Milestone -match '(\d{4}-\d{2}-\d{2})$') { $Matches[1] } else { [DateTime]::UtcNow.ToString('yyyy-MM-dd') }
$record = [ordered]@{
    artifact = $artifactName
    sourceCommit = $SourceCommit
    milestone = "milestone/$Milestone"
    applicationId = 'com.runebeard.whetstone.recovery'
    analysis = 'No issues found'
    flutterTestsPassed = $testCount
    sha256 = $hash
    certificateSha256 = $certificate
    verifiedDate = $verifiedDate
    deviceVerification = 'Pending'
}
$record | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $recordPath -Encoding utf8
Write-Output "Preserved verified APK: $destination"
Write-Output "Source $SourceCommit | $testCount tests | SHA-256 $hash"
