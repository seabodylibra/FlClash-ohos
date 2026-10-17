$ErrorActionPreference = 'Stop'

$packageConfigPath = Join-Path (Get-Location) '.dart_tool/package_config.json'
if (-not (Test-Path -LiteralPath $packageConfigPath)) {
    throw 'Run flutter pub get before applying the OHOS UI compatibility patch.'
}

$packageConfig = Get-Content -LiteralPath $packageConfigPath -Raw | ConvertFrom-Json
$packages = @('material_ui', 'cupertino_ui')
$totalChanges = 0

foreach ($packageName in $packages) {
    $package = $packageConfig.packages | Where-Object name -EQ $packageName | Select-Object -First 1
    if ($null -eq $package) {
        throw "Package '$packageName' is missing from .dart_tool/package_config.json."
    }

    $packageRoot = ([Uri]::new([string]$package.rootUri)).LocalPath
    $pubspecPath = Join-Path $packageRoot 'pubspec.yaml'
    $pubspec = [System.IO.File]::ReadAllText($pubspecPath)
    if ($pubspec -notmatch '(?m)^version:\s*([^\s#]+)') {
        throw "Could not read the version for '$packageName' at '$pubspecPath'."
    }
    $version = $Matches[1]
    $packageChanges = 0

    Get-ChildItem -LiteralPath (Join-Path $packageRoot 'lib/src') -Recurse -File -Filter '*.dart' | ForEach-Object {
        $path = $_.FullName
        $text = [System.IO.File]::ReadAllText($path)
        $newline = if ($text.Contains("`r`n")) { "`r`n" } else { "`n" }
        $lines = [System.Collections.Generic.List[string]]::new()
        $text -split "`r?`n" | ForEach-Object { $lines.Add($_) }
        $changed = $false

        for ($index = 0; $index -lt $lines.Count; $index++) {
            $line = $lines[$index]
            if ($line -match '^([ \t]*)case TargetPlatform\.android:$') {
                if ($index -eq 0 -or $lines[$index - 1] -notmatch '^([ \t]*)case TargetPlatform\.ohos:$') {
                    $lines.Insert($index, "$($Matches[1])case TargetPlatform.ohos:")
                    $index++
                    $packageChanges++
                    $changed = $true
                }
                continue
            }

            if ($line -match '^([ \t]*)TargetPlatform\.android\s*\|\|') {
                if ($index -eq 0 -or $lines[$index - 1] -notmatch '^([ \t]*)TargetPlatform\.ohos\s*\|\|') {
                    $lines.Insert($index, "$($Matches[1])TargetPlatform.ohos ||")
                    $index++
                    $packageChanges++
                    $changed = $true
                }
                continue
            }

            if ($line -match 'TargetPlatform\.android' -and $line -match '=>' -and $line -notmatch 'TargetPlatform\.ohos') {
                $updated = [regex]::Replace($line, 'TargetPlatform\.android', 'TargetPlatform.ohos || TargetPlatform.android', 1)
                if ($updated -ne $line) {
                    $lines[$index] = $updated
                    $packageChanges++
                    $changed = $true
                }
            }
        }

        if ($changed) {
            [System.IO.File]::WriteAllText($path, [string]::Join($newline, $lines), [System.Text.UTF8Encoding]::new($false))
        }
    }

    if ($packageChanges -eq 0) {
        Write-Output "$packageName $version already has OHOS platform cases."
    } else {
        Write-Output "$packageName ${version}: mapped $packageChanges Android-style platform branches to OHOS in the local pub cache."
        $totalChanges += $packageChanges
    }
}

if ($totalChanges -eq 0) {
    Write-Output 'No OHOS UI compatibility edits were needed.'
}
