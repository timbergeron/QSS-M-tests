#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
artifacts_dir="$repo_root/artifacts"
binary="$repo_root/Quake/quakespasm-valgrind"

mkdir -p "$artifacts_dir"

if [ ! -x "$binary" ]; then
  echo "Missing valgrind binary at $binary; run build-linux-valgrind.sh first." >&2
  exit 1
fi

# Use headless drivers to avoid needing a display/audio device on CI.
export SDL_VIDEODRIVER=dummy
export SDL_AUDIODRIVER=dummy

cd "$repo_root/Quake"

valgrind \
  --tool=memcheck \
  --leak-check=full \
  --show-leak-kinds=all \
  --track-origins=yes \
  --error-exitcode=1 \
  --log-file="$artifacts_dir/valgrind.log" \
  ./quakespasm-valgrind \
  -basedir "$repo_root/Quake" \
  -dedicated 1 \
  -heapsize 64000 \
  +map start \
  +quit
