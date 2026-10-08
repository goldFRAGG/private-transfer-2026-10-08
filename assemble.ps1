$ErrorActionPreference = 'Stop'
try {
    $manifest = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'manifest.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    $targetPath = Join-Path $PSScriptRoot $manifest.filename
    if (Test-Path -LiteralPath $targetPath) { throw 'Output archive already exists. Move it elsewhere before assembling.' }
    foreach ($part in $manifest.parts) {
        $path = Join-Path $PSScriptRoot $part.name
        if (!(Test-Path -LiteralPath $path)) { throw ('Missing file: ' + $part.name) }
        if ((Get-Item -LiteralPath $path).Length -ne $part.size) { throw ('Incorrect file size: ' + $part.name) }
        Write-Host ('Checking ' + $part.name)
        if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ne $part.sha256) { throw ('Checksum mismatch: ' + $part.name) }
    }
    $outputStream = [IO.File]::Open($targetPath, [IO.FileMode]::CreateNew)
    try {
        foreach ($part in $manifest.parts) {
            Write-Host ('Joining ' + $part.name)
            $inputStream = [IO.File]::OpenRead((Join-Path $PSScriptRoot $part.name))
            try { $inputStream.CopyTo($outputStream) } finally { $inputStream.Dispose() }
        }
    } finally { $outputStream.Dispose() }
    if ((Get-Item -LiteralPath $targetPath).Length -ne $manifest.size) { throw 'Final size mismatch' }
    Write-Host 'Checking final archive...'
    if ((Get-FileHash -LiteralPath $targetPath -Algorithm SHA256).Hash -ne $manifest.sha256) { throw 'Final checksum mismatch' }
    Write-Host ('Ready: ' + $targetPath)
} catch {
    Write-Host $_ -ForegroundColor Red
    exit 1
}
