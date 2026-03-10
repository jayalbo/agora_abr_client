import Foundation
import AgoraRtcKit
import UIKit

/// Host publish resolution (encoder configuration). Only applies when joining as host.
enum HostResolution: String, CaseIterable, Identifiable {
    case r360p   // 640×360
    case r480p   // 848×480
    case r720p   // 1280×720 (default)
    case r1080p  // 1920×1080

    var id: String { rawValue }

    var label: String {
        switch self {
        case .r360p: return "360p"
        case .r480p: return "480p"
        case .r720p: return "720p"
        case .r1080p: return "1080p"
        }
    }

    var size: CGSize {
        switch self {
        case .r360p: return CGSize(width: 640, height: 360)
        case .r480p: return CGSize(width: 848, height: 480)
        case .r720p: return CGSize(width: 1280, height: 720)
        case .r1080p: return CGSize(width: 1920, height: 1080)
        }
    }
}

/// User role in the live channel: audience (subscribe only) or host (can publish and subscribe).
enum ClientRole: String, CaseIterable, Identifiable {
    case audience
    case host

    var id: String { rawValue }

    var label: String {
        switch self {
        case .audience: return "Audience"
        case .host: return "Host (publish)"
        }
    }
}

enum LayerMode: String, CaseIterable, Identifiable {
    case auto
    case high
    case low
    case layer1
    case layer2
    case layer3
    case layer4
    case layer5
    case layer6

    var id: String { rawValue }

    var label: String {
        switch self {
        case .auto: return "Auto (ABR)"
        case .high: return "High"
        case .low: return "Low"
        case .layer1: return "Layer 1"
        case .layer2: return "Layer 2"
        case .layer3: return "Layer 3"
        case .layer4: return "Layer 4"
        case .layer5: return "Layer 5"
        case .layer6: return "Layer 6"
        }
    }

    // Agora enum values from native docs:
    // HIGH=0, LOW=1, LAYER_1..LAYER_6=4..9
    var streamTypeRawValue: Int {
        switch self {
        case .auto, .high: return 0
        case .low: return 1
        case .layer1: return 4
        case .layer2: return 5
        case .layer3: return 6
        case .layer4: return 7
        case .layer5: return 8
        case .layer6: return 9
        }
    }

    // Agora fallback options enum values:
    // DISABLED=0, VIDEO_STREAM_LOW=1, AUDIO_ONLY=2, VIDEO_STREAM_LAYER_1..6=3..8
    var fallbackOptionRawValue: Int {
        switch self {
        case .auto: return 8 // Allow ABR to step down progressively to Layer 6.
        default: return 0
        }
    }
}

struct RemoteMediaStats {
    var width: Int = 0
    var height: Int = 0
    var fps: Int = 0
    var videoBitrateKbps: Int = 0
    var audioBitrateKbps: Int = 0
    var packetLossRate: Int?
    var delayMs: Int?

    var summary: String {
        let res = (width > 0 && height > 0) ? "\(width)x\(height)" : "n/a"
        let loss = packetLossRate.map { "\($0)%" } ?? "n/a"
        let delay = delayMs.map { "\($0)ms" } ?? "n/a"
        return "\(res) @ \(fps)fps | V \(videoBitrateKbps)kbps | A \(audioBitrateKbps)kbps | loss \(loss) | delay \(delay)"
    }
}

final class AgoraAudienceManager: NSObject, ObservableObject {
    @Published var isJoined = false
    @Published var isJoining = false
    @Published var logs: [String] = []
    @Published var remoteUsers: [UInt] = []
    @Published var layerMode: LayerMode = .auto
    @Published var remoteStats: [UInt: RemoteMediaStats] = [:]
    @Published var clientRole: ClientRole = .audience
    /// When true, local video view is available (host role and preview/stream started).
    @Published var isHostPublishing = false
    /// Host: whether local video capture is enabled (can toggle without leaving).
    @Published var isLocalVideoEnabled = true
    /// Host: whether local audio (microphone) is enabled (can toggle without leaving).
    @Published var isLocalAudioEnabled = true
    /// Host: when false, iOS camera switching behavior can be changed (setParameters unlock).
    @Published var cameraSwitchingBehaviorLocked = true
    /// Host: publish resolution (applied when joining as host). Default 720p.
    @Published var hostResolution: HostResolution = .r720p

    /// Retrieves the current Agora call ID (if available) and appends it to the logs.
    func logCurrentCallId() {
        guard let engine else {
            appendLog("Call ID unavailable: engine not initialized.")
            return
        }
        if let callId = engine.getCallId() {
            appendLog("Call ID: \(callId)")
        } else {
            appendLog("Call ID unavailable: not in a call or SDK did not return an ID.")
        }
    }

    private let maxLogLines = 500

    private var engine: AgoraRtcEngineKit?
    private var remoteVideoViews: [UInt: UIView] = [:]
    private var localVideoView: UIView?

    private static let logTimeFormatter: DateFormatter = {
        let df = DateFormatter()
        df.timeStyle = .medium
        return df
    }()

    private let logFilePath: String = {
        let path = NSTemporaryDirectory().appending("agora.log")
        return path
    }()

    deinit {
        AgoraRtcEngineKit.destroy()
    }

    func join(appId: String, channel: String, token: String?, uid: UInt? = nil) {
        let cleanAppId = appId.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanChannel = channel.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanAppId.isEmpty, !cleanChannel.isEmpty else {
            appendLog("App ID and channel are required.")
            return
        }

        if engine == nil {
            let config = AgoraRtcEngineConfig()
            config.appId = cleanAppId

            let logConfig = AgoraLogConfig()
            logConfig.level = .info
            logConfig.filePath = logFilePath
            config.logConfig = logConfig

            engine = AgoraRtcEngineKit.sharedEngine(with: config, delegate: self)
        }

        guard let engine else {
            appendLog("Failed to initialize Agora engine.")
            return
        }

        isJoining = true

        engine.enableAudio()

        if clientRole == .host {
            let encConfig = AgoraVideoEncoderConfiguration(
                size: hostResolution.size,
                frameRate: 30,
                bitrate: AgoraVideoBitrateStandard,
                orientationMode: .adaptative,
                mirrorMode: .auto
            )
            encConfig.degradationPreference = AgoraDegradationPreference.maintainQuality
            encConfig.minBitrate = AgoraVideoBitrateStandard
            _ = engine.setVideoEncoderConfiguration(encConfig)
            appendLog("Host resolution: \(hostResolution.label) (\(Int(hostResolution.size.width))×\(Int(hostResolution.size.height))).")
        }

        engine.enableVideo()
        engine.setChannelProfile(.liveBroadcasting)

        let role: AgoraClientRole = clientRole == .host ? .broadcaster : .audience
        engine.setClientRole(role)

        if clientRole == .host {
            localVideoView = UIView(frame: .zero)
            localVideoView?.backgroundColor = .black
            if let view = localVideoView {
                let canvas = AgoraRtcVideoCanvas()
                canvas.uid = 0
                canvas.view = view
                canvas.renderMode = .hidden
                engine.setupLocalVideo(canvas)
                engine.startPreview()
                applyCameraSwitchingBehaviorLockedToEngine()
                isHostPublishing = true
            }
        }

        applyLayerModeToEngine()

        let desiredUID: UInt = uid ?? 0
        let roleLabel = clientRole == .host ? "host" : "audience"
        let result = engine.joinChannel(byToken: (token?.isEmpty == true ? nil : token), channelId: cleanChannel, info: nil, uid: desiredUID) { [weak self] _, uid, _ in
            DispatchQueue.main.async {
                self?.isJoining = false
                self?.isJoined = true
                self?.appendLog("Joined channel=\"\(cleanChannel)\" as \(roleLabel) (uid=\(uid)).")
                self?.logCurrentCallId()
            }
        }

        if result != 0 {
            isJoining = false
            appendLog("Join failed immediately with code=\(result)")
        }
    }

    func leave() {
        isJoining = false
        guard let engine else { return }

        if isHostPublishing {
            engine.stopPreview()
            isHostPublishing = false
            localVideoView = nil
        }
        engine.leaveChannel(nil)
        isJoined = false
        remoteUsers = []
        remoteStats = [:]
        remoteVideoViews = [:]
        appendLog("Left channel.")
    }

    /// Returns the local video view when acting as host (publishing). Nil for audience or before preview starts.
    func getLocalVideoView() -> UIView? {
        localVideoView
    }

    // MARK: - Host: local video and camera

    /// Enables or disables local video capture (host only). When disabled, remote users no longer see your video.
    func setLocalVideoEnabled(_ enabled: Bool) {
        guard let engine, isHostPublishing else { return }
        engine.enableLocalVideo(enabled)
        DispatchQueue.main.async { [weak self] in
            self?.isLocalVideoEnabled = enabled
            self?.appendLog("Local video \(enabled ? "enabled" : "disabled").")
        }
    }

    /// Enables or disables local audio (microphone) capture (host only). When disabled, remote users no longer hear you.
    func setLocalAudioEnabled(_ enabled: Bool) {
        guard let engine, isHostPublishing else { return }
        engine.enableLocalAudio(enabled)
        DispatchQueue.main.async { [weak self] in
            self?.isLocalAudioEnabled = enabled
            self?.appendLog("Local audio \(enabled ? "enabled" : "disabled").")
        }
    }

    /// Switches between front and rear camera (host only, iOS/Android).
    func switchCamera() {
        guard let engine, isHostPublishing else { return }
        let result = engine.switchCamera()
        DispatchQueue.main.async { [weak self] in
            if result == 0 {
                self?.appendLog("Camera switched.")
            } else {
                self?.appendLog("switchCamera failed: \(result).")
            }
        }
    }

    /// When false, allows changing iOS camera switching behavior. Apply before or after join as host.
    func setCameraSwitchingBehaviorLocked(_ locked: Bool) {
        cameraSwitchingBehaviorLocked = locked
        applyCameraSwitchingBehaviorLockedToEngine()
        appendLog("Camera switching behavior locked=\(locked).")
    }

    private func applyCameraSwitchingBehaviorLockedToEngine() {
        guard let engine else { return }
        let value = cameraSwitchingBehaviorLocked ? "true" : "false"
        let json = "{\"rtc.video.ios_camera_switching_behavior_locked\":\(value)}"
        let result = engine.setParameters(json)
        if result != 0 {
            appendLog("setParameters(ios_camera_switching_behavior_locked) failed: \(result).")
        }
    }

    func videoView(for uid: UInt) -> UIView {
        if let view = remoteVideoViews[uid] {
            return view
        }

        let view = UIView(frame: .zero)
        view.backgroundColor = .black
        remoteVideoViews[uid] = view

        if let engine {
            let canvas = AgoraRtcVideoCanvas()
            canvas.uid = uid
            canvas.view = view
            canvas.renderMode = .hidden
            engine.setupRemoteVideo(canvas)
        }

        return view
    }

    func applyLayerMode(_ mode: LayerMode) {
        layerMode = mode
        applyLayerModeToEngine()
        applyLayerModeToUsers()
    }

    private func applyLayerModeToEngine() {
        guard let engine else { return }

        if let streamType = AgoraVideoStreamType(rawValue: layerMode.streamTypeRawValue) {
            _ = engine.setRemoteDefaultVideoStreamType(streamType)
        } else {
            appendLog("Skipped default stream type: unsupported type=\(layerMode.streamTypeRawValue)")
        }

        if layerMode == .auto {
            if let fallback = AgoraStreamFallbackOptions(rawValue: layerMode.fallbackOptionRawValue) {
                _ = engine.setRemoteSubscribeFallbackOption(fallback)
                appendLog("Video layer preference changed: AUTO (ABR), floor=Layer 6")
            } else {
                appendLog("Skipped ABR fallback option: unsupported value=\(layerMode.fallbackOptionRawValue)")
            }
        } else {
            if let fallback = AgoraStreamFallbackOptions(rawValue: 0) {
                _ = engine.setRemoteSubscribeFallbackOption(fallback)
            }
            appendLog("Video layer preference changed: \(layerMode.label)")
        }
    }

    private func applyLayerModeToUsers() {
        guard let engine else { return }

        for uid in remoteUsers {
            guard let streamType = AgoraVideoStreamType(rawValue: layerMode.streamTypeRawValue) else {
                appendLog("Layer mode update skipped for uid=\(uid): unsupported type=\(layerMode.streamTypeRawValue)")
                continue
            }
            _ = engine.setRemoteVideoStream(uid, type: streamType)
            appendLog("Layer mode applied to uid=\(uid): \(layerMode.label)")
        }
    }

    /// Public helper to log UI-driven events from views.
    func logUIEvent(_ message: String) {
        DispatchQueue.main.async { [weak self] in
            self?.appendLog("UI: \(message)")
        }
    }

    private func appendLog(_ message: String) {
        let line = "[\(Self.logTimeFormatter.string(from: Date()))] \(message)"
        logs.append(line)
        if logs.count > maxLogLines {
            let overflow = logs.count - maxLogLines
            logs.removeFirst(overflow)
        }
    }

    /// Returns the URL of the Agora log file if it exists.
    func logFileURL() -> URL? {
        let url = URL(fileURLWithPath: logFilePath)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    /// Presents a share sheet to share the Agora log file (supports AirDrop) from a given UIViewController.
    /// If no log file exists, appends a log entry.
    func presentLogShare(from presenter: UIViewController) {
        guard let url = logFileURL() else {
            appendLog("No Agora log file found to share.")
            return
        }
        let activity = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        presenter.present(activity, animated: true)
    }
}

extension AgoraAudienceManager: AgoraRtcEngineDelegate {
    func rtcEngine(_ engine: AgoraRtcEngineKit, didJoinedOfUid uid: UInt, elapsed: Int) {
        DispatchQueue.main.async {
            if !self.remoteUsers.contains(uid) {
                self.remoteUsers.append(uid)
            }
            if let streamType = AgoraVideoStreamType(rawValue: self.layerMode.streamTypeRawValue) {
                _ = engine.setRemoteVideoStream(uid, type: streamType)
            }
            self.appendLog("User joined: uid=\(uid)")
        }
    }

    func rtcEngine(_ engine: AgoraRtcEngineKit, didOfflineOfUid uid: UInt, reason: AgoraUserOfflineReason) {
        DispatchQueue.main.async {
            self.remoteUsers.removeAll { $0 == uid }
            self.remoteStats.removeValue(forKey: uid)
            self.remoteVideoViews.removeValue(forKey: uid)
            self.appendLog("User left: uid=\(uid), reason=\(reason.rawValue)")
        }
    }

    func rtcEngine(_ engine: AgoraRtcEngineKit, remoteVideoStats stats: AgoraRtcRemoteVideoStats) {
        DispatchQueue.main.async {
            var current = self.remoteStats[stats.uid] ?? RemoteMediaStats()
            current.width = Int(stats.width)
            current.height = Int(stats.height)
            current.fps = Int(stats.rendererOutputFrameRate)
            current.videoBitrateKbps = Int(stats.receivedBitrate)
            current.packetLossRate = Int(stats.packetLossRate)
            current.delayMs = Int(stats.e2eDelay)
            self.remoteStats[stats.uid] = current
        }
    }

    func rtcEngine(_ engine: AgoraRtcEngineKit, remoteAudioStats stats: AgoraRtcRemoteAudioStats) {
        DispatchQueue.main.async {
            var current = self.remoteStats[stats.uid] ?? RemoteMediaStats()
            current.audioBitrateKbps = Int(stats.receivedBitrate)
            current.packetLossRate = Int(stats.audioLossRate)
            self.remoteStats[stats.uid] = current
        }
    }

    func rtcEngine(_ engine: AgoraRtcEngineKit, networkQuality uid: UInt, txQuality: AgoraNetworkQuality, rxQuality: AgoraNetworkQuality) {
        DispatchQueue.main.async {
            if uid == 0 && self.isJoined {
                self.appendLog("Network quality: uplink=\(txQuality.rawValue), downlink=\(rxQuality.rawValue)")
            }
        }
    }

    func rtcEngine(_ engine: AgoraRtcEngineKit, didOccurError errorCode: AgoraErrorCode) {
        DispatchQueue.main.async {
            self.isJoining = false
            if !self.isJoined {
                self.isJoined = false
            }
            self.appendLog("Agora error: \(self.describeAgoraError(errorCode))")
        }
    }

    func rtcEngine(_ engine: AgoraRtcEngineKit, connectionChangedTo state: AgoraConnectionState, reason: AgoraConnectionChangedReason) {
        DispatchQueue.main.async {
            self.appendLog("Connection state changed: state=\(state.rawValue), reason=\(reason.rawValue)")
            switch state {
            case .failed, .disconnected:
                self.isJoining = false
                self.isJoined = false
            default:
                break
            }
        }
    }

    func rtcEngine(_ engine: AgoraRtcEngineKit, didLeaveChannelWith stats: AgoraChannelStats) {
        DispatchQueue.main.async {
            self.appendLog("Left channel (SDK callback). Duration=\(stats.duration)s")
            self.isJoined = false
            self.isJoining = false
            self.isHostPublishing = false
            self.localVideoView = nil
            self.remoteUsers = []
            self.remoteStats = [:]
            self.remoteVideoViews = [:]
        }
    }

    private func describeAgoraError(_ code: AgoraErrorCode) -> String {
        switch code {
        case .invalidAppId: return "INVALID_APP_ID (\(code.rawValue))"
        case .invalidToken: return "INVALID_TOKEN (\(code.rawValue))"
        case .tokenExpired: return "TOKEN_EXPIRED (\(code.rawValue))"
        case .joinChannelRejected: return "JOIN_CHANNEL_REJECTED (\(code.rawValue))"
        default: return "code=\(code.rawValue)"
        }
    }
}
