#!/usr/bin/env bash
# Builds build/Camera.app. Set SIGN_IDENTITY to sign with a real certificate
# (ad-hoc signing is the default).
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
config="${CONFIG:-release}"
build="$root/build"
app="$build/Camera.app"

swift build -c "$config" --package-path "$root" --product Camera
bin="$(swift build -c "$config" --package-path "$root" --show-bin-path)"

icon="$build/AppIcon.icns"
if [[ ! -f "$icon" || "$root/scripts/make-icon.swift" -nt "$icon" ]]; then
  rm -rf "$build/AppIcon.iconset"
  swift "$root/scripts/make-icon.swift" "$build/AppIcon.iconset"
  iconutil -c icns "$build/AppIcon.iconset" -o "$icon"
fi

# Keep Spotlight from listing this build next to the installed app.
mkdir -p "$build"
touch "$build/.metadata_never_index"

rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$bin/Camera" "$app/Contents/MacOS/Camera"
cp "$root/Resources/Info.plist" "$app/Contents/Info.plist"
cp "$icon" "$app/Contents/Resources/AppIcon.icns"

codesign --force --sign "${SIGN_IDENTITY:--}" "$app"
echo "Built $app"
