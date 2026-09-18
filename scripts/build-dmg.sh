#!/bin/bash
set -euo pipefail

root_dir="$(cd "$(dirname "$0")/.." && pwd)"
build_dir="$root_dir/build"
archive_path="$build_dir/AIRViewer.xcarchive"
staging_dir="$build_dir/dmg"
output_dir="$root_dir/dist"
app_name="AIR Viewer"

rm -rf "$build_dir" "$output_dir"
mkdir -p "$staging_dir" "$output_dir"

signing_args=(CODE_SIGNING_ALLOWED=NO)
if [[ -n "${DEVELOPER_ID_APPLICATION:-}" ]]; then
  signing_args=(CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="$DEVELOPER_ID_APPLICATION")
fi

xcodebuild archive \
  -project "$root_dir/AIRViewer.xcodeproj" \
  -scheme AIRViewer \
  -configuration Release \
  -destination "generic/platform=macOS" \
  -archivePath "$archive_path" \
  "${signing_args[@]}"

ditto "$archive_path/Products/Applications/$app_name.app" "$staging_dir/$app_name.app"
ln -s /Applications "$staging_dir/Applications"

dmg_path="$output_dir/AIRViewer.dmg"
hdiutil create -volname "$app_name" -srcfolder "$staging_dir" -ov -format UDZO "$dmg_path"

if [[ -n "${APPLE_ID:-}" && -n "${APPLE_APP_PASSWORD:-}" && -n "${APPLE_TEAM_ID:-}" && -n "${DEVELOPER_ID_APPLICATION:-}" ]]; then
  xcrun notarytool submit "$dmg_path" --apple-id "$APPLE_ID" --password "$APPLE_APP_PASSWORD" --team-id "$APPLE_TEAM_ID" --wait
  xcrun stapler staple "$dmg_path"
fi

echo "Created $dmg_path"
