import SwiftUI

public struct ConvxSyncedLyricsView: View {
    @ObservedObject var player = AudioPlayerService.shared
    @ObservedObject var theme = ThemeManager.shared
    @State private var userIsInteracting = false
    @State private var interactionTimer: Timer? = nil

    public init() {}

    public var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                if player.lyrics.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "quote.bubble.fill")
                            .font(.system(size: 42))
                            .foregroundColor(.white.opacity(0.35))
                        Text("No synchronized lyrics available")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.55))
                    }
                    .frame(maxWidth: .infinity, minHeight: 250)
                } else {
                    LazyVStack(alignment: .leading, spacing: 22) {
                        ForEach(Array(player.lyrics.enumerated()), id: \.element.id) { index, line in
                            let isActive = (index == player.currentLyricIndex)

                            Button(action: {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                player.seek(to: Double(line.timeMs) / 1000.0)
                            }) {
                                Text(line.text)
                                    .font(.system(size: isActive ? 27 : 21, weight: isActive ? .bold : .medium, design: .rounded))
                                    .foregroundColor(isActive ? .white : .white.opacity(0.32))
                                    .shadow(color: isActive ? theme.activeAccentColor.opacity(0.45) : .clear, radius: 10, x: 0, y: 0)
                                    .blur(radius: isActive ? 0 : 1.3)
                                    .scaleEffect(isActive ? 1.03 : 1.0, anchor: .leading)
                                    .animation(.spring(response: 0.35, dampingFraction: 0.72), value: isActive)
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                            .id(index)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 32)
                }
            }
            .simultaneousGesture(
                DragGesture().onChanged { _ in
                    userIsInteracting = true
                    interactionTimer?.invalidate()
                    interactionTimer = Timer.scheduledTimer(withTimeInterval: 3.5, repeats: false) { _ in
                        Task { @MainActor in
                            userIsInteracting = false
                        }
                    }
                }
            )
            .onChange(of: player.currentLyricIndex) { _, newIndex in
                if let newIndex = newIndex, !userIsInteracting {
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
                        proxy.scrollTo(newIndex, anchor: .center)
                    }
                }
            }
        }
    }
}

public typealias LyricsView = ConvxSyncedLyricsView
