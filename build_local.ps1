$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$ProjectRoot = $PSScriptRoot
$OutputZip = Join-Path (Split-Path -Parent $ProjectRoot) 'Hospital_Management_System.zip'
$Items = @(
    @{ Path = 'app.py'; Entry = 'app.py' },
    @{ Path = 'schema.sql'; Entry = 'schema.sql' },
    @{ Path = 'requirements.txt'; Entry = 'requirements.txt' },
    @{ Path = 'README.md'; Entry = 'README.md' },
    @{ Path = 'docs/Hospital_Management_System_Report.pdf'; Entry = 'docs/Hospital_Management_System_Report.pdf' }
)
foreach ($Item in $Items) {
    if (-not (Test-Path -LiteralPath (Join-Path $ProjectRoot $Item.Path))) {
        throw "Missing package file: $($Item.Path)"
    }
}
if (Test-Path -LiteralPath $OutputZip) {
    Remove-Item -LiteralPath $OutputZip -Force
}
$Archive = [System.IO.Compression.ZipFile]::Open($OutputZip, [System.IO.Compression.ZipArchiveMode]::Create)
try {
    foreach ($Item in $Items) {
        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
            $Archive,
            (Join-Path $ProjectRoot $Item.Path),
            $Item.Entry,
            [System.IO.Compression.CompressionLevel]::Optimal
        ) | Out-Null
    }
}
finally {
    $Archive.Dispose()
}
Write-Output "Created local bundle: $OutputZip"
