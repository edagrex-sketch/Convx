import SwiftUI

@main
struct ConvxApp: App {
    init() {
        // Pre-warm audio session and AVPlayer at cold launch for zero-latency start
        AudioPlayerService.shared.warmup()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
