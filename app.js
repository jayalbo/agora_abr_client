const form = document.getElementById("join-form");
const appIdInput = document.getElementById("app-id");
const channelInput = document.getElementById("channel");
const tokenInput = document.getElementById("token");
const layerModeSelect = document.getElementById("layer-mode");
const joinBtn = document.getElementById("join-btn");
const leaveBtn = document.getElementById("leave-btn");
const videoGrid = document.getElementById("video-grid");
const logBox = document.getElementById("log");

const AgoraRTCSDK = window.AgoraRTC;
if (!AgoraRTCSDK) {
  joinBtn.disabled = true;
  leaveBtn.disabled = true;
  appIdInput.disabled = true;
  channelInput.disabled = true;
  tokenInput.disabled = true;
  layerModeSelect.disabled = true;
  logBox.textContent =
    "AgoraRTC SDK failed to load. Check internet access and script URL.";
  throw new Error("AgoraRTC SDK is not loaded.");
}

if (typeof AgoraRTCSDK.enableLogUpload === "function") {
  AgoraRTCSDK.enableLogUpload();
}

const client = AgoraRTCSDK.createClient({ mode: "live", codec: "vp9" });
const subscribedUsers = new Set();
let preferredLayerMode = "auto";
let remoteStatsIntervalId = null;
const STREAM_TYPE_LABELS = {
  0: "HIGH",
  1: "LOW",
  4: "LAYER_1",
  5: "LAYER_2",
  6: "LAYER_3",
  7: "LAYER_4",
  8: "LAYER_5",
  9: "LAYER_6",
};

function log(message) {
  const timestamp = new Date().toLocaleTimeString();
  logBox.textContent = `[${timestamp}] ${message}\n${logBox.textContent}`;
}

function setUiState(joined) {
  appIdInput.disabled = joined;
  channelInput.disabled = joined;
  tokenInput.disabled = joined;
  joinBtn.disabled = joined;
  leaveBtn.disabled = !joined;
}

function createVideoContainer(uid) {
  let container = document.getElementById(`remote-${uid}`);
  if (container) return container.querySelector(".video-host");

  container = document.createElement("div");
  container.id = `remote-${uid}`;
  container.className = "video-tile";

  const videoHost = document.createElement("div");
  videoHost.id = `remote-video-${uid}`;
  videoHost.className = "video-host";

  const statsOverlay = document.createElement("div");
  statsOverlay.id = `stats-${uid}`;
  statsOverlay.className = "stats-overlay";
  statsOverlay.textContent = `uid=${uid} | waiting for stats...`;

  container.appendChild(videoHost);
  container.appendChild(statsOverlay);
  videoGrid.appendChild(container);
  return videoHost;
}

function removeVideoContainer(uid) {
  const container = document.getElementById(`remote-${uid}`);
  if (container) container.remove();
}

function enableAbrBandwidthEstimation() {
  if (typeof AgoraRTCSDK.enableLogUpload === "function") {
    log("Agora log upload: enabled.");
  } else {
    log("Agora log upload: API unavailable in this SDK build.");
  }

  if (typeof AgoraRTCSDK.setParameter === "function") {
    AgoraRTCSDK.setParameter("ENABLE_AUT_CC", true);
    log("ABR: ENABLE_AUT_CC enabled.");
  } else {
    log("ABR: ENABLE_AUT_CC parameter API unavailable in this SDK build.");
  }
}

function getStatForUid(stats, uid) {
  if (!stats) return null;
  return stats[uid] || stats[String(uid)] || null;
}

function renderRemoteStats() {
  let remoteVideoStats = null;
  let remoteAudioStats = null;

  try {
    if (typeof client.getRemoteVideoStats === "function") {
      remoteVideoStats = client.getRemoteVideoStats();
    }
    if (typeof client.getRemoteAudioStats === "function") {
      remoteAudioStats = client.getRemoteAudioStats();
    }
  } catch (error) {
    log(`Stats poll failed: ${error.message || error}`);
    return;
  }

  for (const uid of subscribedUsers) {
    const overlay = document.getElementById(`stats-${uid}`);
    if (!overlay) continue;

    const v = getStatForUid(remoteVideoStats, uid);
    const a = getStatForUid(remoteAudioStats, uid);

    const w = v?.receiveResolutionWidth || v?.width || 0;
    const h = v?.receiveResolutionHeight || v?.height || 0;
    const fps =
      v?.renderFrameRate ||
      v?.receiveFrameRate ||
      v?.receiveFrameRateDecoded ||
      0;
    const vBitrate = v?.receiveBitrate || 0;
    const aBitrate = a?.receiveBitrate || 0;
    const loss = v?.packetLossRate ?? a?.packetLossRate;
    const delayMs = v?.receiveDelay;

    const lossText = typeof loss === "number" ? `${loss.toFixed(1)}%` : "n/a";
    const delayText =
      typeof delayMs === "number" ? `${Math.round(delayMs)}ms` : "n/a";
    const resolutionText = w > 0 && h > 0 ? `${w}x${h}` : "n/a";

    overlay.textContent =
      `uid=${uid} | ${resolutionText} @ ${Math.round(fps)}fps | ` +
      `V ${Math.round(vBitrate)}kbps | A ${Math.round(aBitrate)}kbps | ` +
      `loss ${lossText} | delay ${delayText}`;
  }
}

function startRemoteStatsPolling() {
  if (remoteStatsIntervalId) return;
  renderRemoteStats();
  remoteStatsIntervalId = window.setInterval(renderRemoteStats, 2000);
}

function stopRemoteStatsPolling() {
  if (!remoteStatsIntervalId) return;
  window.clearInterval(remoteStatsIntervalId);
  remoteStatsIntervalId = null;
}

async function applyLayerMode(uid) {
  if (preferredLayerMode === "auto") {
    await client.setRemoteVideoStreamType(uid, 0);
    await client.setStreamFallbackOption(uid, 1);
    log(`Layer mode applied to uid=${uid}: AUTO (ABR)`);
    return;
  }

  const streamType = Number(preferredLayerMode);
  await client.setStreamFallbackOption(uid, 0);
  await client.setRemoteVideoStreamType(uid, streamType);
  log(
    `Layer mode applied to uid=${uid}: ${STREAM_TYPE_LABELS[streamType] || streamType}`,
  );
}

async function applyLayerModeToSubscribedUsers() {
  for (const uid of subscribedUsers) {
    try {
      await applyLayerMode(uid);
    } catch (error) {
      log(
        `Layer mode update skipped for uid=${uid}: ${error.message || error}`,
      );
    }
  }
}

client.on("user-published", async (user, mediaType) => {
  await client.subscribe(user, mediaType);
  subscribedUsers.add(user.uid);

  if (mediaType === "video" && user.videoTrack) {
    const videoHost = createVideoContainer(user.uid);
    user.videoTrack.play(videoHost);
    renderRemoteStats();
    log(`Subscribed video from uid=${user.uid}`);

    try {
      await applyLayerMode(user.uid);
    } catch (error) {
      log(
        `Layer mode setup skipped for uid=${user.uid}: ${error.message || error}`,
      );
    }
  }

  if (mediaType === "audio" && user.audioTrack) {
    user.audioTrack.play();
    log(`Subscribed audio from uid=${user.uid}`);
  }
});

client.on("user-unpublished", (user, mediaType) => {
  if (mediaType === "video") {
    removeVideoContainer(user.uid);
  }
  log(`User unpublished ${mediaType}, uid=${user.uid}`);
});

client.on("user-left", (user) => {
  removeVideoContainer(user.uid);
  subscribedUsers.delete(user.uid);
  log(`User left, uid=${user.uid}`);
});

client.on("stream-type-changed", (uid, streamType) => {
  const typeLabel = STREAM_TYPE_LABELS[streamType] || `UNKNOWN(${streamType})`;
  log(`ABR: stream-type-changed uid=${uid}, type=${typeLabel}`);
});

client.on("stream-fallback", (uid, isFallbackOrRecover) => {
  const state = isFallbackOrRecover === "fallback" ? "fallback" : "recover";
  log(`ABR: stream-fallback uid=${uid}, state=${state}`);
});

client.on("network-quality", (stats) => {
  log(
    `Network quality: uplink=${stats.uplinkNetworkQuality}, downlink=${stats.downlinkNetworkQuality}`,
  );
});

layerModeSelect.addEventListener("change", async (event) => {
  preferredLayerMode = event.target.value;
  if (preferredLayerMode === "auto") {
    log("Video layer preference changed: AUTO (ABR)");
  } else {
    const streamType = Number(preferredLayerMode);
    log(
      `Video layer preference changed: ${STREAM_TYPE_LABELS[streamType] || streamType}`,
    );
  }
  await applyLayerModeToSubscribedUsers();
});

form.addEventListener("submit", async (event) => {
  event.preventDefault();

  const appId = appIdInput.value.trim();
  const channel = channelInput.value.trim();
  const token = tokenInput.value.trim();

  if (!appId || !channel) {
    log("App ID and channel are required.");
    return;
  }

  try {
    setUiState(true);
    enableAbrBandwidthEstimation();

    await client.setClientRole("audience");
    await client.join(appId, channel, token || null, null);
    startRemoteStatsPolling();
    try {
      const defaultType =
        preferredLayerMode === "auto" ? 0 : Number(preferredLayerMode);
      await client.setRemoteDefaultVideoStreamType(defaultType);
    } catch (error) {
      log(`ABR default stream preference skipped: ${error.message || error}`);
    }
    log(`Joined channel="${channel}" as audience.`);
  } catch (error) {
    setUiState(false);
    log(`Join failed: ${error.message || error}`);
  }
});

leaveBtn.addEventListener("click", async () => {
  try {
    await client.leave();
    stopRemoteStatsPolling();
    subscribedUsers.clear();
    videoGrid.innerHTML = "";
    setUiState(false);
    log("Left channel.");
  } catch (error) {
    log(`Leave failed: ${error.message || error}`);
  }
});
