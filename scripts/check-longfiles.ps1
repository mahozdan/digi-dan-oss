param(
    [Parameter(Position = 0)]
    [int]$Threshold = 300
)

Write-Host "======================================" -ForegroundColor Cyan
Write-Host " Checking for long files (> $Threshold lines)..." -ForegroundColor Cyan
Write-Host " You can change the Threshold by specifing a number after command" -ForegroundColor Cyan
Write-Host " e.g. npm run check:longfiles 450" -ForegroundColor green
Write-Host "======================================" -ForegroundColor Cyan
Start-Sleep -Milliseconds 500

$exts = 'js','ts','tsx','jsx','py','rb','rs','go','java','cpp','c','cs','php','sql'
$long = @()
$scanned = 0

Get-ChildItem -Recurse -File |
Where-Object {
    $_.Extension.TrimStart('.') -in $exts -and
    $_.FullName -notmatch '\\\.git\\' -and
    $_.FullName -notmatch '\\node_modules\\' -and
    $_.FullName -notmatch '\\scripts\\' -and
    $_.FullName -notmatch '\\\.next\\' -and
    $_.FullName -notmatch '\\out\\' -and
    $_.FullName -notmatch '\\dist\\' -and
    $_.Name -ne 'nul' -and
    $_.Extension -notin @('.json','.html','.css','.yml','.yaml') -and
    $_.Name -notmatch '(?i)test|spec'
} |
ForEach-Object {
    $lines = 0
    $scanned++ 
    try {
        foreach ($_tmp in [System.IO.File]::ReadLines($_.FullName)) { $lines++ }
    }
    catch {
        $lines = 0
    }
    if ($lines -gt $Threshold) {
        Write-Host ">> $($_.FullName) - $lines lines" -ForegroundColor Red
        $long += [pscustomobject]@{ File = $_.FullName; Lines = $lines }
    } else {
        Write-Host "OK $($_.FullName) - $lines lines" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "===== Long files (> $Threshold lines) ====="
Write-Host ("Scanned files: {0}" -f $scanned)
Write-Host ("Long files  : {0}" -f $long.Count)
Write-Host ""
if ($long.Count -gt 0) {
    $long | Sort-Object Lines -Descending |
        ForEach-Object { Write-Host "$($_.File) - $($_.Lines) lines" -ForegroundColor blue } |
        Tee-Object -FilePath long_files.txt
} else {
    'None' | Tee-Object -FilePath long_files.txt
}

