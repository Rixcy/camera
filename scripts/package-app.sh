#!/usr/bin/env bash
# Builds a universal Camera.app and zips it to build/Camera-<version>.zip for
# a GitHub release. VERSION defaults to the one in Info.plist.
# Notarizes when APPLE_ID, APPLE_TEAM_ID and APPLE_APP_PASSWORD are set, which
# needs SIGN_IDENTITY to be a Developer ID Application certificate.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
export VERSION="${VERSION:-$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$root/Resources/Info.plist")}"
export ARCHS="${ARCHS:-arm64 x86_64}"
app="$root/build/Camera.app"
zip="$root/build/Camera-$VERSION.zip"

"$root/scripts/build-app.sh"

rm -f "$zip"
ditto -c -k --norsrc --keepParent "$app" "$zip"

if [[ -n "${APPLE_ID:-}" && -n "${APPLE_TEAM_ID:-}" && -n "${APPLE_APP_PASSWORD:-}" ]]; then
  xcrun notarytool submit "$zip" --wait \
    --apple-id "$APPLE_ID" --team-id "$APPLE_TEAM_ID" --password "$APPLE_APP_PASSWORD"
  xcrun stapler staple "$app"
  rm -f "$zip"
  ditto -c -k --norsrc --keepParent "$app" "$zip"
fi

echo "Packaged $zip"
