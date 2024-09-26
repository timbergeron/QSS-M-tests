#!/bin/sh

set -e  # Exit immediately if a command exits with a non-zero status.

echo "Git URL:      https://github.com/timbergeron/QSS-M.git" > QSS-M-Revision.txt
echo "Git Revision: $(git rev-parse HEAD)" >> QSS-M-Revision.txt
echo "Git Date:     $(git log -1 --date=short --format=%cd)" >> QSS-M-Revision.txt
echo "Compile Date: $(date)" >> QSS-M-Revision.txt
export SOURCE_DATE_EPOCH=$(git log -1 --date=short --format=%ct)

cd Quake/
MAKEARGS="-j$(nproc)"

# Set compiler flags
export QSS_CFLAGS="-DQSS_REVISION=$(git rev-parse HEAD)"
export QSS_LDFLAGS="-Wl,--allow-multiple-definition"

make -f Makefile.w64 clean
./build_cross_win64-sdl2-msys.sh $MAKEARGS
mv quakespasm.exe QSS-M-w64.exe

# Adjust paths to DLLs in MSYS2
zip -9j QSS-M-w64.zip \
  /mingw64/bin/SDL2.dll \
  /mingw64/bin/libcurl-*.dll \
  /mingw64/bin/libmad-0.dll \
  /mingw64/bin/libopus-0.dll \
  /mingw64/bin/libvorbis-0.dll \
  /mingw64/bin/libvorbisfile-3.dll \
  /mingw64/bin/zlib1.dll \
  ../LICENSE.txt \
  ../Quakespasm.html \
  quakespasm.pak \
  qssm.pak \
  ../Quakespasm.txt \
  ../Quakespasm-Spiked.txt \
  ../Quakespasm-Music.txt \
  ../QSS-M-Revision.txt \
  QSS-M-w64.exe

make -f Makefile.w64 clean
