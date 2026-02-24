# Agora ABR Audience (iOS)

This folder contains an iOS version of the web ABR audience client, implemented with SwiftUI and the Agora iOS SDK.

## What it mirrors from the web app

- Join as `audience` in live mode
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

4. In Xcode, add Agora iOS SDK with Swift Package Manager:

- `File` -> `Add Package Dependencies...`
- URL: `https://github.com/AgoraIO/AgoraRtcEngine_iOS`
- Add product `RtcBasic` to target `AgoraABRAudience` (this provides `AgoraRtcKit`)

5. Build and run on device/simulator.

## iOS privacy keys

`Info.plist` already includes microphone and camera usage descriptions required by Agora.
