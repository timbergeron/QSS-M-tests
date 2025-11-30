#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
artifacts_dir="$repo_root/artifacts"
binary="$repo_root/Quake/quakespasm-valgrind"
supp_file="$repo_root/valgrind.supp"
autoexec_dir="$repo_root/Quake/id1"
autoexec_path="$autoexec_dir/autoexec.cfg"
autoexec_backup=""
server_mod="crmod7"
server_dir="$repo_root/Quake/$server_mod"
server_pid=""

mkdir -p "$artifacts_dir"

if [ ! -x "$binary" ]; then
  echo "Missing valgrind binary at $binary; run build-linux-valgrind.sh first." >&2
  exit 1
fi

# Prepare a tiny autoexec so shareware builds still run scripted commands.
mkdir -p "$autoexec_dir"

if [ -f "$autoexec_path" ]; then
  autoexec_backup="$(mktemp)"
  cp "$autoexec_path" "$autoexec_backup"
fi

cleanup() {
  rm -f "$autoexec_path"
  if [ -n "$autoexec_backup" ] && [ -f "$autoexec_backup" ]; then
    mv "$autoexec_backup" "$autoexec_path"
  fi
  if [ -n "$server_pid" ]; then
    kill "$server_pid" 2>/dev/null || true
  fi
}
trap cleanup EXIT

cat > "$autoexec_path" <<'EOF'
map start
wait 30
connect la.quakeone.com:26002
wait 300
disconnect
connect 127.0.0.1:26000
wait 300
disconnect
quit
EOF

# Use headless drivers to avoid needing a display/audio device on CI.
export SDL_AUDIODRIVER=dummy

cd "$repo_root/Quake"

# Optionally launch a local server using crmod7 if the progs.dat is present.
if [ -f "$server_dir/progs.dat" ]; then
  echo "Starting local server with -game $server_mod"
  timeout 90s "$binary" \
    -basedir "$repo_root/Quake" \
    -game "$server_mod" \
    -dedicated 1 \
    -port 26000 \
    +map start \
    +sv_public 0 \
    >"$artifacts_dir/server.log" 2>&1 &
  server_pid=$!
else
  echo "Skipping local server: $server_dir/progs.dat not found"
fi

set +e
timeout 120s xvfb-run -a valgrind \
  --tool=memcheck \
  --leak-check=full \
  --show-leak-kinds=definite \
  --track-origins=yes \
  --suppressions="$supp_file" \
  --error-exitcode=1 \
  --log-file="$artifacts_dir/valgrind.log" \
  ./quakespasm-valgrind \
  -basedir "$repo_root/Quake" \
  -heapsize 256000 \
  -zone 1024 \
  +exec autoexec.cfg
status=$?
set -e

if [ "$status" -eq 124 ]; then
  echo "Valgrind run timed out after 120s" >&2
  exit $status
elif [ "$status" -ne 0 ]; then
  echo "Valgrind reported errors (exit $status); see $artifacts_dir/valgrind.log" >&2
fi

if [ -f "$artifacts_dir/valgrind.log" ]; then
  echo
  echo "==== valgrind log (tail) ===="
  tail -n 200 "$artifacts_dir/valgrind.log"
fi

exit 0
