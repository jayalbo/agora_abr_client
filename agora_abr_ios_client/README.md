# Agora ABR Audience (iOS)

This folder contains an iOS version of the web ABR audience client, implemented with SwiftUI and the Agora iOS SDK.

## What it mirrors from the web app

- Join as **audience** (subscribe only) or **host** (publish + subscribe) in live mode
- Inputs for `App ID`, `Channel`, optional `Token`
- Video layer selector:
  - `Auto (ABR)`
  - `High`
  - `Low`
  - `Layer 1` to `Layer 6`
- Subscriber-side ABR behavior:
  - Enables Agora log upload
  - Applies remote default video stream type
  - Applies remote stream type for each subscribed uid
  - In `Auto (ABR)`, enables native fallback stepping down through layers to `Layer 6`
- Remote video rendering
- Network quality and per-uid remote audio/video stats

**Host mode (optional):** When joining as host, you get local camera preview, video/audio toggles, switch camera, host resolution pick (360p–1080p), and "video off" placeholder when video is disabled.

## Agora: SPM only (no CocoaPods)

Agora is included via **Swift Package Manager** in `project.yml`. Do **not** run `pod install` here. Using both CocoaPods and SPM for Agora can cause duplicate/conflicting frameworks and **"Bad executable" (error 85)** on device.

- Always open **`AgoraABRAudience.xcodeproj`** (not any `.xcworkspace`).
- If you previously ran `pod install`: delete the `Pods` folder and `AgoraABRAudience.xcworkspace` (if present), then open only the `.xcodeproj`.

## Project generation

This repo does not include a prebuilt `.xcodeproj`. It includes an `xcodegen` spec.

1. Install XcodeGen (once):

```bash
brew install xcodegen
```

2. Generate project:

```bash
cd agora_abr_ios_client
xcodegen generate
```

3. Open the project:

```bash
open AgoraABRAudience.xcodeproj
```

4. Agora is already added via SPM in `project.yml`. If you regenerated the project and the package is missing, in Xcode: **File → Add Package Dependencies...** → URL: `https://github.com/AgoraIO/AgoraRtcEngine_iOS` → add product **RtcBasic** to target **AgoraABRAudience**.

5. Build and run on device/simulator. Use the **.xcodeproj** only (no workspace).

## iOS privacy keys

`Info.plist` already includes microphone and camera usage descriptions required by Agora.

## App icon

- A generated icon set is included in `AgoraABRAudience/Resources/Assets.xcassets/AppIcon.appiconset`.
- To replace it with your own PNG and regenerate required sizes, follow `IOS_ICON.md`.

## Device launch: "Bad executable" (error 85)

If the app builds but **fails to launch on a physical device** with error 85 (Bad executable), try the following.

### 0. Avoid CocoaPods + SPM together

If you ever ran `pod install` in this folder, you may have **both** CocoaPods and SPM providing Agora. That can cause duplicate/conflicting frameworks and launch failure. Use **SPM only**: remove the `Pods` folder and `AgoraABRAudience.xcworkspace`, open **only** `AgoraABRAudience.xcodeproj`, then clean and run again (see below).

### 1. Clean and rebuild

- In Xcode: **Product → Clean Build Folder** (⇧⌘K).
- Delete the app from the iPhone (long-press icon → Remove App).
- Quit Xcode, then delete DerivedData for this project:
  ```bash
  rm -rf ~/Library/Developer/Xcode/DerivedData/*AgoraABRAudience*
  ```
- Reopen `AgoraABRAudience.xcodeproj`, select your **iPhone** as the run destination (not "Any iOS Device"), then **Product → Run**.

### 2. Build scripts (already in project.yml)

The project runs two scripts on **device** builds only:

- **Strip invalid architectures** – removes simulator slices from embedded frameworks that can cause the loader to reject the app.
- **Re-sign embedded frameworks** – re-signs frameworks with your app's identity so the device accepts them.

Regenerate the project so these run: `xcodegen generate` in `agora_abr_ios_client`, then build and run again.

### 3. Capture device logs (if Xcode Console won't open)

From Terminal, with the iPhone connected and unlocked:

```bash
cd agora_abr_ios_client/scripts
chmod +x device-logs.sh
./device-logs.sh
```

Then in Xcode, **Build & Run**. Let the script run for 10–20 seconds, press **Ctrl+C**, then open `device_log.txt` (in the same directory) and search for:

- `dyld`
- `Library not loaded` / `image not found`
- `code sign` / `signature` / `invalid`
- `launch failed` / `launchd`

### 4. SDK / OS version mismatch

If the error mentions **sdk_osVersion** (e.g. 26.2) and your device is on a newer OS (e.g. 26.3), install the matching iOS platform in **Xcode → Settings → Platforms** so the app is built with the same SDK version.
