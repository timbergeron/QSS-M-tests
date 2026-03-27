#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$SCRIPT_DIR/ci-version.sh"

cd "$SCRIPT_DIR"

echo "Git URL:      https://github.com/timbergeron/QSS-M.git" > QSS-M-Revision.txt
echo "Git Revision: `git rev-parse HEAD`" >> QSS-M-Revision.txt
echo "Git Date:     `git log -1 --date=short --format=%cd`" >> QSS-M-Revision.txt
echo "Compile Date: `date`" >> QSS-M-Revision.txt
export SOURCE_DATE_EPOCH=$(git log -1 --date=short --format=%ct)

cd Quake/
MAKEARGS="${MAKEARGS:--j8}"

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

run_make() {
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

# Make Linux64
export QSS_CFLAGS="$(append_flags "$(qssm_build_cflags)" "${QSS_CFLAGS:-}")"
export QSS_LDFLAGS="$(append_flags "-Wl,--allow-multiple-definition" "${QSS_LDFLAGS:-}")"
make clean
run_make USE_SDL2=1
mv quakespasm QSS-M-l64
zip -9j QSS-M-l64.zip ../LICENSE.txt ../Quakespasm.html quakespasm.pak qssm.pak ../Quakespasm.txt ../Quakespasm-Spiked.txt ../Quakespasm-Music.txt ../QSS-M-Revision.txt QSS-M-l64
make clean
