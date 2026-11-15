#!/usr/bin/env bash
# Builds Camera.app and installs it into ~/Applications (or INSTALL_DIR),
# then registers it so Spotlight finds it straight away.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
dest_dir="${INSTALL_DIR:-$HOME/Applications}"
dest="$dest_dir/Camera.app"

"$root/scripts/build-app.sh"

mkdir -p "$dest_dir"
if pgrep -f "$dest/Contents/MacOS/Camera" >/dev/null; then
  osascript -e 'tell application id "com.rixcy.Camera" to quit' || true
fi
rm -rf "$dest"
ditto "$root/build/Camera.app" "$dest"

lsregister=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
"$lsregister" -f "$dest"
mdimport "$dest" 2>/dev/null || true
echo "Installed $dest — search Spotlight for \"Camera\"."
