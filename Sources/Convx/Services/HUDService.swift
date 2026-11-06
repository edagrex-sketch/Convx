import SwiftUI
import UIKit

@MainActor
public final class HUDService: ObservableObject {
    public static let shared = HUDService()

    public struct HUDItem: Equatable, Identifiable {
        public let id = UUID()
        public let icon: String
        public let iconColor: Color
        public let title: String
        public let subtitle: String?

        public static func == (lhs: HUDItem, rhs: HUDItem) -> Bool {
            lhs.id == rhs.id
        }
    }

    @Published public var currentItem: HUDItem? = nil
    private var dismissTask: Task<Void, Never>? = nil

    private init() {}

    public func show(icon: String, iconColor: Color = .cyan, title: String, subtitle: String? = nil) {
        dismissTask?.cancel()
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.70)) {
            currentItem = HUDItem(icon: icon, iconColor: iconColor, title: title, subtitle: subtitle)
        }

        dismissTask = Task {
            try? await Task.sleep(nanoseconds: 2_300_000_000)
            if !Task.isCancelled {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    self.currentItem = nil
                }
            }
        }
    }

    public func dismiss() {
        dismissTask?.cancel()
        withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
            currentItem = nil
        }
    }
}

public struct ConvxFloatingHUDView: View {
    @ObservedObject var hud = HUDService.shared

    public init() {}

    public var body: some View {
        Group {
            if let item = hud.currentItem {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(item.iconColor.opacity(0.18))
                            .frame(width: 32, height: 32)
                        Image(systemName: item.icon)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(item.iconColor)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        if let sub = item.subtitle, !sub.isEmpty {
                            Text(sub)
                                .font(.system(size: 11, weight: .regular))
                                .foregroundColor(.white.opacity(0.70))
                                .lineLimit(1)
                        }
                    }

                    Spacer(minLength: 8)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .frame(maxWidth: 320)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.22), lineWidth: 0.9))
                .shadow(color: Color.black.opacity(0.40), radius: 16, x: 0, y: 8)
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.85)),
                    removal: .move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.90))
                ))
            }
        }
        .animation(.spring(response: 0.38, dampingFraction: 0.72), value: hud.currentItem)
    }
}
