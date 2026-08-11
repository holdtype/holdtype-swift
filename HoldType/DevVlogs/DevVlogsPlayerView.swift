import AVKit
import SwiftUI

struct DevVlogsPlayerView: View {
    let url: URL

    @State private var player: AVPlayer

    init(url: URL) {
        self.url = url
        _player = State(initialValue: AVPlayer(url: url))
    }

    var body: some View {
        VideoPlayer(player: player)
            .frame(minWidth: 640, minHeight: 360)
            .onAppear {
                player.play()
            }
            .onDisappear {
                player.pause()
            }
            .accessibilityLabel("Dev Vlogs video player")
    }
}

#if DEBUG
#Preview {
    DevVlogsPlayerView(url: URL(fileURLWithPath: "/Preview/clip.mov"))
}
#endif
