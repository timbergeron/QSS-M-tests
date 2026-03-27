#!/bin/sh
set -eu

append_flags() {
	base="$1"
	extra="$2"

	if [ -n "$base" ] && [ -n "$extra" ]; then
		printf '%s %s' "$base" "$extra"
	elif [ -n "$extra" ]; then
		printf '%s' "$extra"
	else
		printf '%s' "$base"
	fi
}

run_make_linux() {
	set -- $MAKEARGS "$@" "USE_GNUTLS=${USE_GNUTLS:-1}"
	if [ "${GNUTLS_PKG_OK+x}" = x ]; then
		set -- "$@" "GNUTLS_PKG_OK=$GNUTLS_PKG_OK"
	fi
	if [ "${GNUTLS_CFLAGS+x}" = x ]; then
		set -- "$@" "GNUTLS_CFLAGS=$GNUTLS_CFLAGS"
	fi
	if [ "${GNUTLS_LIBS+x}" = x ]; then
		set -- "$@" "GNUTLS_LIBS=$GNUTLS_LIBS"
	fi
	make "$@"
}

echo "Git URL:      https://github.com/timbergeron/QSS-M.git" > QSS-M-Revision.txt
echo "Git Revision: `git rev-parse HEAD`" >> QSS-M-Revision.txt
echo "Git Date:     `git log -1 --date=short --format=%cd`" >> QSS-M-Revision.txt
echo "Compile Date: `date`" >> QSS-M-Revision.txt
export SOURCE_DATE_EPOCH=$(git log -1 --date=short --format=%ct)

cd Quake/
MAKEARGS="-j8"
USER_QSS_CFLAGS="${QSS_CFLAGS:-}"
USER_QSS_LDFLAGS="${QSS_LDFLAGS:-}"

# Make win32
export QSS_CFLAGS="$(append_flags "-DQSS_REVISION=`git rev-parse HEAD`" "$USER_QSS_CFLAGS")"
export QSS_LDFLAGS="$(append_flags "-Wl,--allow-multiple-definition" "$USER_QSS_LDFLAGS")"
make -f Makefile.w32 clean
./build_cross_win32-sdl2.sh $MAKEARGS
mv quakespasm.exe QSS-M-w32.exe
zip -9j QSS-M-w32.zip ../Windows/codecs/x86/*.dll ../Windows/curl/lib/x86/libcurl.dll ../Windows/zlib/x86/zlib1.dll ../LICENSE.txt ../Quakespasm.html quakespasm.pak ../Quakespasm.txt ../Quakespasm-Spiked.txt ../Quakespasm-Music.txt ../Windows/SDL2/lib/SDL2.dll ../QSS-M-Revision.txt QSS-M-w32.exe
make -f Makefile.w32 clean

# Make win64
export QSS_CFLAGS="$(append_flags "-DQSS_REVISION=`git rev-parse HEAD`" "$USER_QSS_CFLAGS")"
export QSS_LDFLAGS="$(append_flags "-Wl,--allow-multiple-definition" "$USER_QSS_LDFLAGS")"
make -f Makefile.w64 clean
./build_cross_win64-sdl2.sh $MAKEARGS
mv quakespasm.exe QSS-M-w64.exe
zip -9j QSS-M-w64.zip ../Windows/codecs/x64/*.dll ../Windows/curl/lib/x64/libcurl.dll ../Windows/zlib/x64/zlib1.dll ../LICENSE.txt ../Quakespasm.html quakespasm.pak ../Quakespasm.txt ../Quakespasm-Spiked.txt ../Quakespasm-Music.txt ../Windows/SDL2/lib64/SDL2.dll ../QSS-M-Revision.txt QSS-M-w64.exe
make -f Makefile.w64 clean

# Make Linux64
export QSS_CFLAGS="$(append_flags "-DQSS_REVISION=`git rev-parse HEAD`" "$USER_QSS_CFLAGS")"
export QSS_LDFLAGS="$(append_flags "" "$USER_QSS_LDFLAGS")"
make clean
run_make_linux USE_SDL2=1
mv quakespasm QSS-M-l64
zip -9j QSS-M-l64.zip ../LICENSE.txt ../Quakespasm.html quakespasm.pak ../Quakespasm.txt ../Quakespasm-Spiked.txt ../Quakespasm-Music.txt ../QSS-M-Revision.txt QSS-M-l64
make clean
