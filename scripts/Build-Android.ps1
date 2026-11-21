[CmdletBinding()]
param([switch]$RefreshDependencies)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$toolRoot = (Resolve-Path (Join-Path $repoRoot '..')).Path
$flutterRoot = Join-Path $toolRoot 'flutter-sdk'
$androidRoot = Join-Path $toolRoot 'android-sdk'
$dart = Join-Path $flutterRoot 'bin/cache/dart-sdk/bin/dart.exe'
$flutterTools = Join-Path $flutterRoot 'bin/cache/flutter_tools.snapshot'
$javaRoot = $env:JAVA_HOME
if (!$javaRoot -or !(Test-Path -LiteralPath (Join-Path $javaRoot 'bin/java.exe'))) {
    $javaRoot = 'C:/Program Files/Android/Android Studio/jbr'
}
foreach ($required in @($dart, $flutterTools,
    (Join-Path $javaRoot 'bin/java.exe'),
    (Join-Path $androidRoot 'platforms/android-36/android.jar'),
    (Join-Path $androidRoot 'ndk/28.2.13676358/source.properties'))) {
    if (!(Test-Path -LiteralPath $required)) { throw "Missing build prerequisite: $required" }
}

$buildEnvironment = @{
    FLUTTER_ROOT = $flutterRoot
    JAVA_HOME = $javaRoot
    ANDROID_HOME = $androidRoot
    ANDROID_SDK_ROOT = $androidRoot
    ANDROID_USER_HOME = (Join-Path $toolRoot 'android-user')
    GRADLE_USER_HOME = (Join-Path $toolRoot 'gradle-home')
    PUB_CACHE = (Join-Path $toolRoot 'pub-cache')
    APPDATA = (Join-Path $toolRoot 'flutter-appdata')
    TEMP = (Join-Path $toolRoot 'flutter-temp')
    TMP = (Join-Path $toolRoot 'flutter-temp')
    CI = 'true'
}
$savedEnvironment = @{}
foreach ($name in $buildEnvironment.Keys) {
    $savedEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
}
foreach ($directoryName in @('ANDROID_USER_HOME', 'GRADLE_USER_HOME', 'PUB_CACHE', 'APPDATA', 'TEMP')) {
    New-Item -ItemType Directory -Path $buildEnvironment[$directoryName] -Force | Out-Null
}

function Invoke-Flutter {
    param([string[]]$FlutterArguments)
    & $dart $flutterTools @FlutterArguments
    if ($LASTEXITCODE -ne 0) { throw "Flutter failed with exit code $LASTEXITCODE." }
}

Push-Location $repoRoot
try {
    foreach ($name in $buildEnvironment.Keys) {
        [Environment]::SetEnvironmentVariable($name, $buildEnvironment[$name], 'Process')
    }
    if ($RefreshDependencies -or !(Test-Path -LiteralPath '.dart_tool/package_config.json') -or
        !(Test-Path -LiteralPath '.flutter-plugins-dependencies')) {
        Invoke-Flutter @('pub', 'get')
    }
    Invoke-Flutter @('build', 'apk', '--debug', '--no-pub')
    Write-Output (Join-Path $repoRoot 'build/app/outputs/flutter-apk/app-debug.apk')
} finally {
    Pop-Location
    foreach ($name in $savedEnvironment.Keys) {
        [Environment]::SetEnvironmentVariable($name, $savedEnvironment[$name], 'Process')
    }
}
