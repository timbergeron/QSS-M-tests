#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
artifacts_dir="$repo_root/artifacts"
binary="$repo_root/Quake/quakespasm-valgrind"
autoexec_path="$repo_root/Quake/autoexec.cfg"
autoexec_backup=""

mkdir -p "$artifacts_dir"

if [ ! -x "$binary" ]; then
  echo "Missing valgrind binary at $binary; run build-linux-valgrind.sh first." >&2
  exit 1
fi

# Prepare a tiny autoexec so shareware builds still run scripted commands.
if [ -f "$autoexec_path" ]; then
  autoexec_backup="$(mktemp)"
  cp "$autoexec_path" "$autoexec_backup"
fi

cleanup() {
  rm -f "$autoexec_path"
  if [ -n "$autoexec_backup" ] && [ -f "$autoexec_backup" ]; then
    mv "$autoexec_backup" "$autoexec_path"
  fi
}
trap cleanup EXIT

cat > "$autoexec_path" <<'EOF'
map start
wait 10
quit
EOF

# Use headless drivers to avoid needing a display/audio device on CI.
export SDL_AUDIODRIVER=dummy

cd "$repo_root/Quake"

timeout 120s xvfb-run -a valgrind \
  --tool=memcheck \
  --leak-check=full \
  --show-leak-kinds=all \
  --track-origins=yes \
  --error-exitcode=1 \
  --log-file="$artifacts_dir/valgrind.log" \
  ./quakespasm-valgrind \
  -basedir "$repo_root/Quake" \
  -heapsize 256000 \
  -zone 1024 \
  +map start \
  +wait 10 \
  +quit
