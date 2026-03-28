import SwiftUI
import VLCKit

struct PlayerContainerView: NSViewRepresentable {
    let videoView: VLCVideoView

    func makeNSView(context: Context) -> VLCVideoView {
        videoView
    }

    func updateNSView(_ nsView: VLCVideoView, context: Context) {
        nsView.frame = nsView.superview?.bounds ?? nsView.frame
    }
}
