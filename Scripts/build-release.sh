#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"

scheme="${HIKVISION_XCODE_SCHEME:-HikvisionViewer}"
project="${HIKVISION_XCODE_PROJECT:-HikvisionViewer.xcodeproj}"
archive_path="${HIKVISION_ARCHIVE_PATH:-$repo_root/build/HikvisionViewer.xcarchive}"
export_path="${HIKVISION_EXPORT_PATH:-$repo_root/build/export}"
export_method="${HIKVISION_EXPORT_METHOD:-development}"
signing_team="${HIKVISION_DEVELOPMENT_TEAM:-}"
signing_style="${HIKVISION_SIGNING_STYLE:-Automatic}"
configuration="${HIKVISION_CONFIGURATION:-Release}"
allow_updates="${HIKVISION_ALLOW_PROVISIONING_UPDATES:-1}"
export_options_plist="$repo_root/build/ExportOptions.plist"

mkdir -p "$repo_root/build"
rm -rf "$archive_path" "$export_path"

if command -v xcodegen >/dev/null 2>&1; then
  echo "Regenerating Xcode project..."
  xcodegen generate
fi

cat > "$export_options_plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>$export_method</string>
    <key>signingStyle</key>
    <string>$signing_style</string>
</dict>
</plist>
PLIST

archive_cmd=(
  xcodebuild
  -project "$project"
  -scheme "$scheme"
  -configuration "$configuration"
  -destination 'generic/platform=macOS'
  -archivePath "$archive_path"
  archive
)

if [[ "$allow_updates" == "1" ]]; then
  archive_cmd+=(-allowProvisioningUpdates)
fi

if [[ -n "$signing_team" ]]; then
  archive_cmd+=(DEVELOPMENT_TEAM="$signing_team")
fi

echo "Archiving $scheme..."
"${archive_cmd[@]}"

if [[ -z "$signing_team" ]]; then
  echo "Archive complete: $archive_path"
  echo "Skipping export because no Apple team is configured."
  echo "Set HIKVISION_DEVELOPMENT_TEAM and rerun to export a signed app for another Mac."
  echo "Example: HIKVISION_DEVELOPMENT_TEAM=TEAMID HIKVISION_EXPORT_METHOD=development Scripts/build-release.sh"
  exit 0
fi

export_cmd=(
  xcodebuild
  -exportArchive
  -archivePath "$archive_path"
  -exportPath "$export_path"
  -exportOptionsPlist "$export_options_plist"
)

if [[ "$allow_updates" == "1" ]]; then
  export_cmd+=(-allowProvisioningUpdates)
fi

if [[ -n "$signing_team" ]]; then
  export_cmd+=(DEVELOPMENT_TEAM="$signing_team")
fi

echo "Exporting app..."
"${export_cmd[@]}"

echo "Export complete: $export_path"