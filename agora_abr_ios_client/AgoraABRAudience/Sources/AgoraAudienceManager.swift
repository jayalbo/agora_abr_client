import Foundation
import AgoraRtcKit
import UIKit

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
    @Published var logs: [String] = []
    @Published var remoteUsers: [UInt] = []
    @Published var layerMode: LayerMode = .auto
    @Published var remoteStats: [UInt: RemoteMediaStats] = [:]

    private let maxLogLines = 500

    private var engine: AgoraRtcEngineKit?
    private var remoteVideoViews: [UInt: UIView] = [:]

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

    func join(appId: String, channel: String, token: String?) {
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

        engine.enableAudio()
        engine.enableVideo()
        engine.setChannelProfile(.liveBroadcasting)
        engine.setClientRole(.audience)

        applyLayerModeToEngine()

        let result = engine.joinChannel(byToken: (token?.isEmpty == true ? nil : token), channelId: cleanChannel, info: nil, uid: 0) { [weak self] _, uid, _ in
            DispatchQueue.main.async {
                self?.isJoined = true
                self?.appendLog("Joined channel=\"\(cleanChannel)\" as audience (uid=\(uid)).")
            }
        }

        if result != 0 {
            appendLog("Join failed immediately with code=\(result)")
        }
    }

    func leave() {
        guard let engine else { return }

        engine.leaveChannel(nil)
        isJoined = false
        remoteUsers = []
        remoteStats = [:]
        remoteVideoViews = [:]
        appendLog("Left channel.")
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
            current.delayMs = Int(stats.delay)
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
            if uid == 0 {
                self.appendLog("Network quality: uplink=\(txQuality.rawValue), downlink=\(rxQuality.rawValue)")
            }
        }
    }

}
