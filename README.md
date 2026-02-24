# Agora AV Subscriber (Web)

Simple static web client that joins an Agora channel as an audience user and subscribes to remote audio/video.

## Features

- Inputs for `App ID`, `Channel`, and optional `Token`
- `Video Layer` selector:
  - `Auto (ABR)`: prefer high stream and allow fallback to low stream
  - `High`: force high stream
  - `Low`: force low stream
  - `Layer 1` to `Layer 6`: request `RemoteStreamType` layers (`4..9`)
- Joins with `token` when provided, otherwise `token = null`
- Receives and plays remote video/audio tracks
- Enables subscriber-side adaptive bitrate behavior:
  - `AgoraRTC.setParameter("ENABLE_AUT_CC", true)` when available
  - `client.setRemoteDefaultVideoStreamType(...)` based on selected layer mode
  - `client.setRemoteVideoStreamType(uid, ...)` based on selected layer mode
  - `client.setStreamFallbackOption(uid, 1)` in `Auto (ABR)` mode

## Run

Because the page loads the Agora SDK from CDN, serve this folder over HTTP:

```bash
cd /Users/jalbo/Desktop/dev/abr
python3 -m http.server 8080
```

Then open:

- http://localhost:8080

Enter your Agora `App ID`, `Channel`, and optional `Token`, then click **Join**.
# agora_abr_web_client
