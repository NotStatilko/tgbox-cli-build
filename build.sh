#!/usr/bin/env bash
set -euxo pipefail

HOMEDIR=$(realpath .)
OS="$(uname -s)"

set -a
source config.env
set +a

echo "Building `tgbox-cli`"
echo "tgbox-cli hash: $TGBOX_CLI_COMMIT_HASH"
echo "tgbox hash: $TGBOX_COMMIT_HASH"

echo "ffmpeg-preview (linux): $FFMPEG_PREVIEW_LINUX_LINK"
echo "ffmpeg-preview (windows): $FFMPEG_PREVIEW_WINDOWS_LINK"
echo "ffmpeg-preview (macos): $FFMPEG_PREVIEW_MACOS_LINK"

# Making Python virtual env
python -m venv tgbox-cli-build-venv
cd tgbox-cli-build-venv; source bin/activate

# Clone & Install PyInstaller. We want to build our own
# bootloader for PyInstaller, because the default one,
# shipped from PyPI, are flagged by many Antiviruses
git clone https://github.com/pyinstaller/pyinstaller
cd pyinstaller/bootloader
echo "Building PyInstaller bootloader"
python ./waf all
cd ../..
echo "PyInstaller bootloader done!"
python -m pip install ./pyinstaller

# Clone tgbox
echo "Cloning tgbox"
git clone https://github.com/NonProjects/tgbox
cd tgbox
git checkout $TGBOX_COMMIT_HASH

# Downloading FFMpeg
cd tgbox/other

if [[ "$OS" == "Darwin" ]]; then
  echo "Downloading FFMpeg for MacOS"
  wget $FFMPEG_PREVIEW_MACOS_LINK

elif [[ "$OS" == MINGW* || "$OS" == MSYS* ]]; then
  echo "Downloading FFMpeg for Windows"
  wget $FFMPEG_PREVIEW_WINDOWS_LINK

else
  echo "Downloading FFMpeg for Linux"
  wget $FFMPEG_PREVIEW_LINUX_LINK
fi

unzip ffmpeg-*
rm ffmpeg-*
rm ffprobe*
cd ../../..

# Clone & Install tgbox-cli
echo "Cloning & Installing tgbox-cli"
git clone https://github.com/NotStatilko/tgbox-cli
cd tgbox-cli
git checkout $TGBOX_CLI_COMMIT_HASH
python -m pip install .

cd ..
echo "Installing tgbox"
python -m pip install ./tgbox[fast]

echo "Making executable"
cd tgbox-cli/pyinstaller
python -m PyInstaller tgbox_cli.spec
./dist/tgbox-cli* cli-info

if [[ "$OS" == MINGW* || "$OS" == MSYS* ]]; then
  EXECUTABLE=$(realpath dist/tgbox-cli.exe)
else
  EXECUTABLE=$(realpath dist/tgbox-cli)
fi

mkdir -p $HOMEDIR/artifact
mv $EXECUTABLE $HOMEDIR/artifact

echo "Done :)"
