import SwiftUI
import UIKit

struct RemoteVideoView: UIViewRepresentable {
    let uid: UInt
    @ObservedObject var manager: AgoraAudienceManager

    func makeUIView(context: Context) -> UIView {
        manager.videoView(for: uid)
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // No-op. Agora renders directly to this UIView.
    }
}
