#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)
. "$REPO_DIR/ci-version.sh"

cd "$REPO_DIR"

echo "Git URL:      https://github.com/timbergeron/QSS-M.git" > QSS-M-Revision.txt
echo "Git Revision: `git rev-parse HEAD`" >> QSS-M-Revision.txt
echo "Git Date:     `git log -1 --date=short --format=%cd`" >> QSS-M-Revision.txt
echo "Compile Date: `date`" >> QSS-M-Revision.txt
export SOURCE_DATE_EPOCH=$(git log -1 --date=short --format=%ct)

cd Quake/
if command -v nproc >/dev/null 2>&1; then
  MAKEARGS="-j`nproc`"
else
  MAKEARGS="-j2"
fi

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

export QSS_CFLAGS="$(append_flags "$(qssm_build_cflags)" "${QSS_CFLAGS:-}")"
export QSS_LDFLAGS="$(append_flags "-Wl,--allow-multiple-definition" "${QSS_LDFLAGS:-}")"

make clean
run_make USE_SDL2=1 DEBUG=1
mv quakespasm quakespasm-valgrind
