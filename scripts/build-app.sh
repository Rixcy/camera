#!/usr/bin/env bash
# Builds build/Camera.app.
#   SIGN_IDENTITY  signing certificate (ad-hoc by default); a real identity also
#                  turns on the hardened runtime that notarization needs
#   ARCHS          architectures to build, e.g. "arm64 x86_64" for a universal app
#   VERSION        stamped into Info.plist, e.g. 1.2.0
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
config="${CONFIG:-release}"
build="$root/build"
app="$build/Camera.app"
identity="${SIGN_IDENTITY:--}"

swift_args=(-c "$config" --package-path "$root")
for arch in ${ARCHS:-}; do swift_args+=(--arch "$arch"); done
swift build "${swift_args[@]}" --product Camera
bin="$(swift build "${swift_args[@]}" --show-bin-path)"

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

if [[ -n "${VERSION:-}" ]]; then
  plist="$app/Contents/Info.plist"
  /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$plist"
  /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $VERSION" "$plist"
fi

if [[ "$identity" == "-" ]]; then
  codesign --force --sign - "$app"
else
  codesign --force --sign "$identity" --options runtime --timestamp \
    --entitlements "$root/Resources/Camera.entitlements" "$app"
fi
echo "Built $app"
