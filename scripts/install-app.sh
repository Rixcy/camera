#!/usr/bin/env bash
# Builds Camera.app and installs it into ~/Applications (or INSTALL_DIR),
# then registers it so Spotlight finds it straight away.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
dest_dir="${INSTALL_DIR:-$HOME/Applications}"
dest="$dest_dir/Camera.app"
lsregister=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

"$root/scripts/build-app.sh"

# A copy left running from the old bundle (or from `make run`) would keep
# answering launches with the stale binary.
binaries="$dest/Contents/MacOS/Camera|$root/build/Camera.app/Contents/MacOS/Camera"
if pgrep -f -- "$binaries" >/dev/null; then
  osascript -e 'tell application id "com.rixcy.Camera" to quit' >/dev/null 2>&1 || true
  for _ in {1..50}; do pgrep -f -- "$binaries" >/dev/null || break; sleep 0.1; done
  pkill -f -- "$binaries" || true
fi

mkdir -p "$dest_dir"
rm -rf "$dest"
ditto "$root/build/Camera.app" "$dest"

# Only the installed copy should appear in Spotlight.
"$lsregister" -u "$root/build/Camera.app" >/dev/null 2>&1 || true
"$lsregister" -f "$dest"
mdimport "$dest" 2>/dev/null || true
echo "Installed $dest — search Spotlight for \"Camera\"."
