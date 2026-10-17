$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$configPath = Join-Path $repositoryRoot '.dart_tool/package_config.json'
$config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
$package = $config.packages | Where-Object name -EQ 'sqlite3' | Select-Object -First 1
if ($null -eq $package) { throw 'Run flutter pub get before preparing OHOS SQLite.' }
$packageRoot = ([Uri]::new([Uri]::new($configPath), [string]$package.rootUri)).LocalPath
$pubspec = Get-Content -LiteralPath (Join-Path $packageRoot 'pubspec.yaml') -Raw
if ($pubspec -notmatch '(?m)^version:\s*3\.7\.0\s*$') {
    throw 'This OHOS hook patch is reviewed for sqlite3 3.7.0; review it before upgrading.'
}

$hookPath = Join-Path $packageRoot 'hook/build.dart'
$hook = [IO.File]::ReadAllText($hookPath).Replace("`r`n", "`n")
$anchor = '    final sqlite = SqliteBinary.forBuild(input);'
$dispatch = '    if (await buildSqliteForOhos(input, output)) return;'
if (-not $hook.Contains($anchor)) { throw 'Unexpected sqlite3 hook; refusing to patch.' }

$cache = Join-Path $repositoryRoot '.dart_tool/ohos-sqlite'
$null = New-Item -ItemType Directory -Path $cache -Force
$archive = Join-Path $cache 'sqlite-amalgamation-3530400.zip'
$expectedHash = '1E71DDF93849C6A6ECF58B827C0692073D2DD7EE40196158068F7B29F422E87D'
if (-not (Test-Path -LiteralPath $archive)) {
    Invoke-WebRequest -Uri 'https://sqlite.org/2026/sqlite-amalgamation-3530400.zip' -OutFile $archive
}
if ((Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash -ne $expectedHash) {
    throw 'SQLite source archive checksum mismatch.'
}
Add-Type -AssemblyName System.IO.Compression.FileSystem
$destination = Join-Path $packageRoot 'hook/ohos'
$null = New-Item -ItemType Directory -Path $destination -Force
$zip = [IO.Compression.ZipFile]::OpenRead($archive)
try {
    $entry = $zip.GetEntry('sqlite-amalgamation-3530400/sqlite3.c')
    if ($null -eq $entry) { throw 'SQLite source missing from verified archive.' }
    [IO.Compression.ZipFileExtensions]::ExtractToFile($entry, (Join-Path $destination 'sqlite3.c'), $true)
} finally {
    $zip.Dispose()
}
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'ohos/sqlite_build.dart') -Destination (Join-Path $packageRoot 'hook/ohos.dart') -Force
if (-not $hook.Contains($dispatch)) {
    $hook = "import 'ohos.dart';`n`n" + $hook.Replace($anchor, "$dispatch`n`n$anchor")
    [IO.File]::WriteAllText($hookPath, $hook, [Text.UTF8Encoding]::new($false))
}
# Hosted hooks are treated as immutable, so cache edits need explicit invalidation.
$hookCache = Join-Path $repositoryRoot '.dart_tool/hooks_runner/sqlite3'
if (Test-Path -LiteralPath $hookCache) {
    Get-ChildItem -LiteralPath $hookCache -Recurse -File | Where-Object {
        $_.Name -in @('hook.dill', 'hook.dependencies_hash_file.json', 'output.json')
    } | ForEach-Object { Remove-Item -LiteralPath $_.FullName }
}
Write-Output 'sqlite3 3.7.0: OHOS NDK source build enabled; other targets retain the upstream hook.'
