import SwiftUI

public enum Tab: String, CaseIterable {
    case home = "Home"
    case search = "Search"
    case library = "Library"
    case settings = "Settings"

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .search: return "magnifyingglass"
        case .library: return "square.stack.fill"
        case .settings: return "gearshape.fill"
        }
    }
}

public struct ContentView: View {
    @ObservedObject var player = AudioPlayerService.shared
    @ObservedObject var theme = ThemeManager.shared
    @State private var selectedTab: Tab = .home

    public init() {}

    public var body: some View {
        ZStack(alignment: .bottom) {
            // Ambient Live Mesh Backdrop
            MeshGradientBackground()
                .allowsHitTesting(false)

            // Persistent Tab Pages (Preserves scroll positions, search queries, and loaded feeds)
            ZStack {
                HomeView()
                    .opacity(selectedTab == .home ? 1 : 0)
                    .allowsHitTesting(selectedTab == .home)

                SearchView()
                    .opacity(selectedTab == .search ? 1 : 0)
                    .allowsHitTesting(selectedTab == .search)

                LibraryView()
                    .opacity(selectedTab == .library ? 1 : 0)
                    .allowsHitTesting(selectedTab == .library)

                SettingsView()
                    .opacity(selectedTab == .settings ? 1 : 0)
                    .allowsHitTesting(selectedTab == .settings)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Floating Controls: MiniPlayer + Glass TabBar
            VStack(spacing: 8) {
                // MiniPlayer (only if a track is active)
                MiniPlayerView()

                // Floating Glass TabBar
                floatingTabBar
            }
            .padding(.bottom, 8)
            .ignoresSafeArea(.keyboard, edges: .bottom)
        }
        .clipped()
        .overlay(alignment: .top) {
            ConvxNotchIsland()
        }
        .sheet(isPresented: $player.isPresentingFullPlayer) {
            PlayerView()
                .presentationDragIndicator(.hidden)
        }
        .preferredColorScheme(.dark)
    }

    private var floatingTabBar: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases, id: \.self) { tab in
                let isSelected = (selectedTab == tab)
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        selectedTab = tab
                    }
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 20, weight: isSelected ? .bold : .regular))
                            .foregroundColor(isSelected ? theme.activeAccentColor : .white.opacity(0.45))
                            .scaleEffect(isSelected ? 1.08 : 1.0)
                            .shadow(color: isSelected ? theme.activeAccentColor.opacity(0.40) : .clear, radius: 8)

                        Text(tab.rawValue)
                            .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                            .foregroundColor(isSelected ? theme.activeAccentColor : .white.opacity(0.45))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 62)
        .liquidGlass(cornerRadius: 32, opacity: 0.92)
        .padding(.horizontal, 24)
    }
}
