$ErrorActionPreference = "Stop"
$manifest = Join-Path $PSScriptRoot "android\app\src\main\AndroidManifest.xml"
if (-not (Test-Path $manifest)) {
    Write-Host "Manifeste Android introuvable. Lancez d'abord PREPARER_FLUTTER_WINDOWS.bat." -ForegroundColor Red
    exit 1
}
$content = Get-Content -LiteralPath $manifest -Raw
$permissionAudio = '<uses-permission android:name="android.permission.RECORD_AUDIO" />'
$permissionInternet = '<uses-permission android:name="android.permission.INTERNET" />'
if ($content -notmatch 'android\.permission\.RECORD_AUDIO') {
    $content = [regex]::Replace($content, '(<manifest\b[^>]*>)', ('$1' + "`r`n    " + $permissionAudio), 1)
}
if ($content -notmatch 'android\.permission\.INTERNET') {
    $content = [regex]::Replace($content, '(<manifest\b[^>]*>)', ('$1' + "`r`n    " + $permissionInternet), 1)
}
if ($content -notmatch 'android\.speech\.RecognitionService') {
    $queries = @'
    <queries>
        <intent>
            <action android:name="android.speech.RecognitionService" />
        </intent>
    </queries>
'@
    $content = [regex]::Replace($content, '(<application\b)', ($queries + "`r`n    " + '$1'), 1)
}
Set-Content -LiteralPath $manifest -Value $content -Encoding UTF8
Write-Host "Manifeste Android configure : microphone, Internet et visibilité du service vocal." -ForegroundColor Green
