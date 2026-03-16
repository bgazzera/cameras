# HikvisionViewer

HikvisionViewer is a native macOS SwiftUI app that connects to a Hikvision NVR on your LAN, discovers channels when the NVR exposes ISAPI endpoints, stores credentials securely in macOS Keychain, and plays the authenticated RTSP stream directly inside the app window using VLCKit.

## What This MVP Does

- Collects NVR host, username, password, RTSP port, and HTTP port
- Stores the password in Keychain and the non-secret settings in UserDefaults
- Attempts channel discovery through Hikvision ISAPI endpoints
- Accepts discovered channel IDs such as `1`, `2`, and `3` and maps them to Hikvision main-stream RTSP channels such as `101`, `201`, and `301`
- Builds the authenticated RTSP URL for the selected channel
- Embeds the video directly in the app window through VLCKit
- Exposes basic playback controls from the app: play, pause, stop, and mute
- Optionally reconnects the in-app player when the stream fails unexpectedly
- Monitors a Hikvision door station by polling `ISAPI/VideoIntercom/callStatus`
- Shows a local macOS notification when the doorbell starts ringing and can auto-switch the player to the Portero stream
- Adds a dedicated `Portero` button for the DS-KV6113-WPE1 stream
- Supports `.env`-backed defaults for IPs, usernames, ports, and password while still allowing saved settings to override them later
- Adds a global HD/SD toggle for camera streams and the Portero stream

## Requirements

- macOS 13 or newer
- Xcode command-line tools or Xcode installed

The repository vendors the `VLCKit.xcframework` locally under `Vendor/`.

## Build

From the repository root:

```bash
swift build
```

## Xcode Project

This repository now includes a native Xcode project at [HikvisionViewer.xcodeproj](/Users/bruno/Projects/bgazzera/cameras/HikvisionViewer.xcodeproj). It is generated from [project.yml](/Users/bruno/Projects/bgazzera/cameras/project.yml) using XcodeGen.

Open the project in Xcode:

```bash
open HikvisionViewer.xcodeproj
```

If you change the project structure later, regenerate it with:

```bash
xcodegen generate
```

## Run

From the repository root:


The launcher installs the app to `~/Applications/HikvisionViewer.app` by default and reuses that fixed path on each run. Override the install directory with `HIKVISION_VIEWER_INSTALL_DIR` if you want a different location.

If you have a local signing identity, set it explicitly before launching:

```bash
HIKVISION_VIEWER_CODESIGN_IDENTITY="Apple Development: Your Name (TEAMID)" \
./Scripts/run-local.sh
```

```bash
./Scripts/run-local.sh
```

You can prefill the app from the shell without committing credentials into the repository:

```bash
HIKVISION_NVR_HOST=192.168.86.230 \
HIKVISION_NVR_USERNAME=admin \
HIKVISION_NVR_PASSWORD='your-password' \
HIKVISION_NVR_CHANNEL=1 \
./Scripts/run-local.sh
```

The app opens a native macOS window with the embedded video surface at the top. When you click `Connect`, playback starts inside the app.

You can also keep your default device settings in a local `.env` file at the repository root. The launcher copies that file into the app bundle as `defaults.env`, and the app uses those values as defaults before applying any saved settings.

Supported keys are:

```bash
HIKVISION_NVR_HOST=192.168.86.230
HIKVISION_NVR_USERNAME=admin
HIKVISION_NVR_PASSWORD='your-password'
HIKVISION_NVR_CHANNEL=1
HIKVISION_DOORBELL_HOST=192.168.86.54
HIKVISION_DOORBELL_RTSP_PORT=554
HIKVISION_DOORBELL_HTTP_PORT=80
HIKVISION_DOORBELL_HD_CHANNEL=101
HIKVISION_DOORBELL_SD_CHANNEL=102
HIKVISION_DEFAULT_STREAM=hd
```

## Signing In Xcode

To get a stable signed app that you can install on another Mac:

1. Open [HikvisionViewer.xcodeproj](/Users/bruno/Projects/bgazzera/cameras/HikvisionViewer.xcodeproj) in Xcode.
2. Select the `HikvisionViewer` target.
3. Open `Signing & Capabilities`.
4. Enable `Automatically manage signing`.
5. Choose your Apple team.

For local use across your own Macs, an `Apple Development` identity is enough to get started. For smoother installation without Gatekeeper friction on a second Mac, use a `Developer ID Application` certificate and notarize the app.

## Archive For Another Mac

From Xcode:

1. Set the build destination to `Any Mac`.
2. Use `Product > Archive`.
3. In Organizer, choose `Distribute App`.
4. Export a signed app for direct distribution.

From Terminal, you can also archive and export with the included script:

```bash
HIKVISION_DEVELOPMENT_TEAM=TEAMID \
HIKVISION_EXPORT_METHOD=development \
./Scripts/build-release.sh
```

This writes the archive to `build/HikvisionViewer.xcarchive` and the exported app to `build/export`.

If you run the script without `HIKVISION_DEVELOPMENT_TEAM`, it still creates the `.xcarchive` but skips export and tells you what to set.

If Xcode command-line tools complain about first-launch or plugin loading on this Mac, run this once in Terminal and enter your admin password:

```bash
sudo xcodebuild -runFirstLaunch
```

`swift run` is not the recommended launch path for this package because SwiftPM does not automatically stage vendored `.framework` binaries into a `Frameworks` directory for plain executable targets. The wrapper script handles that setup before launch.

## Notes

- Channel discovery depends on the exact Hikvision NVR model and enabled HTTP endpoints. If discovery fails, enter either a discovered camera number such as `1` or a full Hikvision RTSP channel such as `101`.
- Embedded playback is provided by the vendored VLCKit binary framework.
- Credentials are stored in Keychain under the service name `com.bgazzera.HikvisionViewer`.
- The DS-KV6113-WPE1 doorbell path currently supports ring detection, notifications, and direct RTSP playback. The visible talk and hang control still needs the firmware-specific writable `VideoIntercom/callSignal` payload before microphone talkback can be enabled.

## Common Channel IDs

- `101`: camera 1 main stream
- `102`: camera 1 substream on some devices
- `201`: camera 2 main stream
- `301`: camera 3 main stream

Actual mappings depend on the NVR model and configuration.
