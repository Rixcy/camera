#!/usr/bin/env bash
# Retakes the README screenshots in docs/. The Camera window opens for a
# couple of seconds on a drawn scene; the real camera stays off.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"

swift build -c debug --package-path "$root" --product Camera
bin="$(swift build -c debug --package-path "$root" --show-bin-path)"

mkdir -p "$root/docs"
CAMERA_SCREENSHOTS="$root/docs" "$bin/Camera"
echo "Saved $root/docs/camera.png and $root/docs/switching.png"
