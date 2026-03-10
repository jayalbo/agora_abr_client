import SwiftUI
import UIKit

/// Host's local camera preview (used when client role is host).
struct LocalVideoView: UIViewRepresentable {
    @ObservedObject var manager: AgoraAudienceManager

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.backgroundColor = .black
        return container
    }

    func updateUIView(_ container: UIView, context: Context) {
        guard let localView = manager.getLocalVideoView() else { return }
        if localView.superview != container {
            localView.frame = container.bounds
            localView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            container.addSubview(localView)
        }
    }
}
