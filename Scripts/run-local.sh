#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"

install_root="${HIKVISION_VIEWER_INSTALL_DIR:-$HOME/Applications}"
app_bundle="$install_root/HikvisionViewer.app"
codesign_identity="${HIKVISION_VIEWER_CODESIGN_IDENTITY:-}"

if [[ -z "$codesign_identity" ]]; then
	first_identity="$(security find-identity -p codesigning -v 2>/dev/null | awk '/\) / {print $2; exit}')"
	if [[ -n "$first_identity" ]]; then
		codesign_identity="$first_identity"
	else
		codesign_identity="-"
		echo "No valid code-signing identity found. Falling back to ad-hoc signing."
		echo "Install an Apple Development certificate and set HIKVISION_VIEWER_CODESIGN_IDENTITY to avoid repeated macOS trust prompts."
	fi
fi

swift build
bin_path="$(swift build --show-bin-path)"
platform_dir="$(cd "$bin_path/.." && pwd)"
source_framework="$repo_root/Vendor/VLCKit/VLCKit.xcframework/macos-arm64_x86_64/VLCKit.framework"
contents_dir="$app_bundle/Contents"
macos_dir="$contents_dir/MacOS"
frameworks_dir="$contents_dir/Frameworks"
resources_dir="$contents_dir/Resources"
plist_path="$contents_dir/Info.plist"
sign_args=(--force --sign "$codesign_identity" --timestamp=none)

echo "Preparing app bundle..."
rm -rf "$app_bundle"
mkdir -p "$install_root"
mkdir -p "$frameworks_dir"
mkdir -p "$macos_dir"
mkdir -p "$resources_dir"

cat > "$plist_path" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>en</string>
	<key>CFBundleExecutable</key>
	<string>HikvisionViewer</string>
	<key>CFBundleIdentifier</key>
	<string>com.bgazzera.HikvisionViewer</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>HikvisionViewer</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>1.0</string>
	<key>CFBundleVersion</key>
	<string>1</string>
	<key>LSMinimumSystemVersion</key>
	<string>13.0</string>
	<key>NSHighResolutionCapable</key>
	<true/>
	<key>NSPrincipalClass</key>
	<string>NSApplication</string>
</dict>
</plist>
PLIST

cp "$bin_path/HikvisionViewer" "$macos_dir/HikvisionViewer"
cp -R "$source_framework" "$frameworks_dir/"

if [[ -f "$repo_root/.env" ]]; then
	cp "$repo_root/.env" "$resources_dir/defaults.env"
fi

echo "Signing app bundle with identity: $codesign_identity"
codesign "${sign_args[@]}" "$frameworks_dir/VLCKit.framework"
codesign "${sign_args[@]}" --deep "$app_bundle"

if pgrep -x HikvisionViewer >/dev/null; then
	pkill -x HikvisionViewer || true
	sleep 1
fi

echo "Launching HikvisionViewer.app..."
"$macos_dir/HikvisionViewer" >/tmp/hikvision-viewer.log 2>&1 & disown
