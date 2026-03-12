Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$HOMEDIR = Resolve-Path .
$OS = $PSVersionTable.OS

# Load config.env (simple key=value parsing)
Get-Content .\config.env | ForEach-Object {
    # Skip empty lines or lines starting with #
    if ($_ -match '^\s*([^#][^=]+)=(.+)$') {
        $key = $matches[1].Trim()
        $value = $matches[2].Trim().Trim('"')
        Set-Item -Path Env:$key -Value $value
    }
}

Write-Host "Building tgbox-cli"
Write-Host "tgbox-cli hash: $Env:TGBOX_CLI_COMMIT_HASH"
Write-Host "tgbox hash: $Env:TGBOX_COMMIT_HASH"

Write-Host "ffmpeg-preview (linux): $Env:FFMPEG_PREVIEW_LINUX_LINK"
Write-Host "ffmpeg-preview (windows): $Env:FFMPEG_PREVIEW_WINDOWS_LINK"
Write-Host "ffmpeg-preview (macos): $Env:FFMPEG_PREVIEW_MACOS_LINK"

# Make Python virtual env
python -m venv tgbox-cli-build-venv
& .\tgbox-cli-build-venv\Scripts\Activate.ps1

# Clone & Install PyInstaller
git clone https://github.com/pyinstaller/pyinstaller
Push-Location pyinstaller\bootloader
Write-Host "Building PyInstaller bootloader"
python ./waf all
Pop-Location
Write-Host "PyInstaller bootloader done!"
python -m pip install ./pyinstaller

# Clone tgbox
Write-Host "Cloning tgbox"
git clone https://github.com/NonProjects/tgbox
Push-Location tgbox
git checkout $Env:TGBOX_COMMIT_HASH

# Download FFMpeg
Push-Location tgbox
Push-Location other
Write-Host "Downloading FFMpeg for Windows"
Invoke-WebRequest -Uri $Env:FFMPEG_PREVIEW_WINDOWS_LINK -OutFile ffmpeg.zip

Expand-Archive -Path ffmpeg.zip -DestinationPath .
Remove-Item ffmpeg.zip
Remove-Item ffprobe*

Pop-Location
Pop-Location
Pop-Location

# Clone & install tgbox-cli
Write-Host "Cloning & Installing tgbox-cli"
git clone https://github.com/NotStatilko/tgbox-cli
Push-Location tgbox-cli
git checkout $Env:TGBOX_CLI_COMMIT_HASH
python -m pip install .

Pop-Location

Write-Host "Installing tgbox"
python -m pip install .\tgbox[fast]

# Build executable
Write-Host "Making executable"
Push-Location tgbox-cli\pyinstaller
python -m PyInstaller tgbox_cli.spec
Pop-Location

$EXECUTABLE = Join-Path $HOMEDIR "tgbox-cli\pyinstaller\dist\tgbox-cli.exe"
$ARTIFACT = Join-Path $HOMEDIR "artifact"
if (-not (Test-Path $ARTIFACT)) {
    New-Item -ItemType Directory -Path $ARTIFACT
}
Move-Item $EXECUTABLE $ARTIFACT

Write-Host "Done :)"
