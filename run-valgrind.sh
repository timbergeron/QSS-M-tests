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
server_status=0
server_valgrind_log="$artifacts_dir/valgrind-server.log"
server_stdout_log="$artifacts_dir/server.log"
server_ready=false

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

# Use headless drivers to avoid needing a display/audio device on CI.
export SDL_AUDIODRIVER=dummy

cd "$repo_root/Quake"

# Optionally launch a local server using crmod7 if the progs.dat is present.
if [ -f "$server_dir/progs.dat" ]; then
  echo "Starting local server with -game $server_mod"
  touch "$server_valgrind_log" "$server_stdout_log"
  if ! command -v valgrind >/dev/null 2>&1; then
    echo "Warning: valgrind not found; running server without it" >&2
    timeout 90s "$binary" \
      -basedir "$repo_root/Quake" \
      -game "$server_mod" \
      -dedicated 1 \
      -port 26000 \
      +map start \
      +sv_public 0 \
      >"$server_stdout_log" 2>&1 &
  else
    timeout 90s valgrind \
      --tool=memcheck \
      --leak-check=full \
      --show-leak-kinds=definite \
      --track-origins=yes \
      --suppressions="$supp_file" \
      --error-exitcode=1 \
      --log-file="$server_valgrind_log" \
      -basedir "$repo_root/Quake" \
      -game "$server_mod" \
      -dedicated 1 \
      -port 26000 \
      +map start \
      +sv_public 0 \
      >"$server_stdout_log" 2>&1 &
  fi
  server_pid=$!

  # Wait briefly for the server port to open; if it never does, skip the local connect.
  for i in $(seq 1 15); do
    if python3 - <<'PY'
import socket, sys
s = socket.socket()
s.settimeout(0.5)
try:
    s.connect(("127.0.0.1", 26000))
    sys.exit(0)
except Exception:
    sys.exit(1)
PY
    then
      server_ready=true
      break
    fi
    sleep 1
  done
  if [ "$server_ready" != true ]; then
    echo "Local server did not open port 26000; killing it and skipping local connect"
    if [ -n "$server_pid" ]; then
      kill "$server_pid" 2>/dev/null || true
      wait "$server_pid" || true
      server_pid=""
    fi
  fi
else
  echo "Skipping local server: $server_dir/progs.dat not found"
fi

# Write autoexec after server decision so we can include/exclude local connect.
{
  cat <<'EOF'
map start
wait 30
connect la.quakeone.com:26002
wait 300
disconnect
EOF
  if [ "$server_ready" = true ]; then
    cat <<'EOF'
connect 127.0.0.1:26000
wait 300
disconnect
EOF
  fi
  cat <<'EOF'
quit
EOF
} > "$autoexec_path"

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
client_status=$?

if [ -n "$server_pid" ]; then
  wait "$server_pid"
  server_status=$?
  server_pid=""
fi

set -e

if [ "$client_status" -eq 124 ]; then
  echo "Valgrind run timed out after 120s" >&2
  exit $client_status
elif [ "$client_status" -ne 0 ]; then
  echo "Valgrind reported errors (exit $client_status); see $artifacts_dir/valgrind.log" >&2
fi

if [ "$server_status" -eq 124 ]; then
  echo "Server valgrind timed out after 90s" >&2
elif [ "$server_status" -ne 0 ]; then
  echo "Server valgrind reported errors (exit $server_status); see $server_valgrind_log" >&2
fi

if [ -f "$artifacts_dir/valgrind.log" ]; then
  echo
  echo "==== valgrind log (tail) ===="
  tail -n 200 "$artifacts_dir/valgrind.log"
fi

if [ -f "$server_valgrind_log" ]; then
  echo
  echo "==== server valgrind log (tail) ===="
  tail -n 200 "$server_valgrind_log"
fi

if [ -f "$server_stdout_log" ]; then
  echo
  echo "==== server stdout (tail) ===="
  tail -n 200 "$server_stdout_log"
fi

exit 0
