import SwiftUI

// MARK: - Liquid Glass Modifiers
public struct LiquidGlassModifier: ViewModifier {
    var cornerRadius: CGFloat
    var opacityOverride: Double?
    var addSpecularRim: Bool

    @ObservedObject private var theme = ThemeManager.shared

    public init(cornerRadius: CGFloat = 24, opacity: Double? = nil, addSpecularRim: Bool = true) {
        self.cornerRadius = cornerRadius
        self.opacityOverride = opacity
        self.addSpecularRim = addSpecularRim
    }

    public func body(content: Content) -> some View {
        let style = theme.selectedGlassStyle
        let effectiveOpacity = opacityOverride ?? style.baseOpacity

        content
            .background(
                ZStack {
                    // Base material with user-selected glass style
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .opacity(effectiveOpacity)

                    // Subtle white luminance lift (Convx Liquid Glass spec)
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color.white.opacity(style.whiteLift))

                    // Specular 45° rim stroke
                    if addSpecularRim {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    stops: [
                                        .init(color: Color.white.opacity(style.rimOpacity), location: 0.0),
                                        .init(color: Color.white.opacity(style.rimOpacity * 0.35), location: 0.35),
                                        .init(color: Color.white.opacity(0.05), location: 0.70),
                                        .init(color: Color.black.opacity(0.15), location: 1.0)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.8
                            )
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: Color.black.opacity(0.25), radius: style.shadowRadius, x: 0, y: 6)
    }
}

public extension View {
    func liquidGlass(cornerRadius: CGFloat = 24, opacity: Double? = nil, addSpecularRim: Bool = true) -> some View {
        self.modifier(LiquidGlassModifier(cornerRadius: cornerRadius, opacity: opacity, addSpecularRim: addSpecularRim))
    }
}

// MARK: - Ambient Mesh Gradient Background (Strictly Screen-Bounded)
public struct MeshGradientBackground: View {
    @ObservedObject var theme = ThemeManager.shared
    @ObservedObject var player = AudioPlayerService.shared
    @State private var animateBlobs = false

    public init() {}

    public var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let blobSize = min(w, h) * (player.isPlaying ? 0.85 : 0.75)
            let primaryAccent = theme.activeAccentColor

            ZStack {
                // Deep base dark color
                Color(red: 0.07, green: 0.08, blue: 0.11)

                // Blob 1: Dynamic Sonic Canvas Primary (Top Leading)
                Circle()
                    .fill(RadialGradient(
                        colors: [primaryAccent.opacity(player.isPlaying ? 0.72 : 0.55), Color.clear],
                        center: .center,
                        startRadius: 10,
                        endRadius: blobSize * 0.5
                    ))
                    .frame(width: blobSize, height: blobSize)
                    .position(
                        x: animateBlobs ? w * 0.28 : w * 0.15,
                        y: animateBlobs ? h * 0.22 : h * 0.12
                    )
                    .blur(radius: player.isPlaying ? 58 : 50)
                    .animation(.easeInOut(duration: 3.5), value: primaryAccent)

                // Blob 2: Vibrant Indigo / Purple (Top Trailing)
                Circle()
                    .fill(RadialGradient(
                        colors: [Color(red: 0.45, green: 0.20, blue: 0.85).opacity(0.60), Color.clear],
                        center: .center,
                        startRadius: 10,
                        endRadius: blobSize * 0.55
                    ))
                    .frame(width: blobSize * 1.1, height: blobSize * 1.1)
                    .position(
                        x: animateBlobs ? w * 0.80 : w * 0.85,
                        y: animateBlobs ? h * 0.35 : h * 0.25
                    )
                    .blur(radius: 55)

                // Blob 3: Vibrant Crimson / Amber (Bottom Leading)
                Circle()
                    .fill(RadialGradient(
                        colors: [Color(red: 0.85, green: 0.25, blue: 0.45).opacity(0.50), Color.clear],
                        center: .center,
                        startRadius: 10,
                        endRadius: blobSize * 0.5
                    ))
                    .frame(width: blobSize, height: blobSize)
                    .position(
                        x: animateBlobs ? w * 0.20 : w * 0.15,
                        y: animateBlobs ? h * 0.75 : h * 0.70
                    )
                    .blur(radius: 50)

                // Blob 4: Deep Electric Blue (Bottom Trailing)
                Circle()
                    .fill(RadialGradient(
                        colors: [primaryAccent.opacity(0.40), Color.clear],
                        center: .center,
                        startRadius: 10,
                        endRadius: blobSize * 0.5
                    ))
                    .frame(width: blobSize, height: blobSize)
                    .position(
                        x: animateBlobs ? w * 0.75 : w * 0.80,
                        y: animateBlobs ? h * 0.85 : h * 0.80
                    )
                    .blur(radius: 50)

                // Subtle dark overlay to preserve contrast
                LinearGradient(
                    colors: [Color.black.opacity(0.20), Color.black.opacity(0.65)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .frame(width: w, height: h)
            .clipped()
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 10).repeatForever(autoreverses: true)) {
                animateBlobs.toggle()
            }
        }
    }
}

// MARK: - Liquid Glass Shimmer Effect & Skeleton Loaders
public struct LiquidGlassShimmer: ViewModifier {
    @State private var phase: CGFloat = 0.0

    public func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    let w = geo.size.width
                    LinearGradient(
                        colors: [
                            Color.clear,
                            Color.white.opacity(0.18),
                            Color.clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .rotationEffect(.degrees(20))
                    .offset(x: -w + (w * 2.2 * phase))
                }
            )
            .mask(content)
            .onAppear {
                withAnimation(.linear(duration: 1.6).repeatForever(autoreverses: false)) {
                    phase = 1.0
                }
            }
    }
}

public extension View {
    func liquidGlassShimmer() -> some View {
        modifier(LiquidGlassShimmer())
    }
}

public struct SongRowSkeletonView: View {
    public init() {}

    public var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.08))
                .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 170, height: 14)

                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 110, height: 11)
            }

            Spacer()

            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.06))
                .frame(width: 32, height: 12)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.03))
        .cornerRadius(14)
        .liquidGlassShimmer()
    }
}

// MARK: - In-Memory High-Speed Artwork Cache (Eliminates disk I/O on 120Hz ProMotion)
public final class ImageMemoryCache: @unchecked Sendable {
    public static let shared = ImageMemoryCache()
    private let cache = NSCache<NSString, UIImage>()

    private init() {
        cache.countLimit = 500
        cache.totalCostLimit = 150 * 1024 * 1024 // 150MB RAM limit
    }

    public func image(for key: String) -> UIImage? {
        cache.object(forKey: key as NSString)
    }

    public func insert(_ image: UIImage, for key: String) {
        let cost = Int(image.size.width * image.size.height * 4)
        cache.setObject(image, forKey: key as NSString, cost: cost)
    }
}

// MARK: - Async Artwork Image with Smooth Fallback & RAM Caching
public struct ArtworkImageView: View {
    let urlString: String?
    let songId: String?
    let size: CGFloat
    let cornerRadius: CGFloat

    @State private var loadedImage: UIImage?

    public init(urlString: String?, songId: String? = nil, size: CGFloat, cornerRadius: CGFloat = 12) {
        self.urlString = urlString
        self.songId = songId
        self.size = size
        self.cornerRadius = cornerRadius
    }

    private var cacheKey: String? {
        songId ?? urlString
    }

    public var body: some View {
        Group {
            if let cached = loadedImage ?? (cacheKey.flatMap { ImageMemoryCache.shared.image(for: $0) }) {
                Image(uiImage: cached)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if let songId = songId, let localArtURL = DownloadService.shared.localArtworkURL(for: songId) {
                fallbackView
                    .task(id: localArtURL.path) {
                        if let img = ImageMemoryCache.shared.image(for: songId) {
                            self.loadedImage = img
                            return
                        }
                        let path = localArtURL.path
                        let img = await Task.detached(priority: .userInitiated) { () -> UIImage? in
                            UIImage(contentsOfFile: path)
                        }.value
                        if let img = img {
                            ImageMemoryCache.shared.insert(img, for: songId)
                            await MainActor.run {
                                self.loadedImage = img
                            }
                        }
                    }
            } else if let urlString = urlString, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure, .empty:
                        fallbackView
                    @unknown default:
                        fallbackView
                    }
                }
            } else {
                fallbackView
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .onAppear {
            if loadedImage == nil, let key = cacheKey, let cached = ImageMemoryCache.shared.image(for: key) {
                self.loadedImage = cached
            }
        }
    }

    private var fallbackView: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.25, green: 0.25, blue: 0.35), Color(red: 0.12, green: 0.12, blue: 0.18)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "music.note")
                .font(.system(size: size * 0.36, weight: .semibold))
                .foregroundColor(.white.opacity(0.6))
        }
    }
}

// MARK: - Marquee Text for Long Titles
public struct MarqueeText: View {
    let text: String
    let font: Font
    let color: Color

    public init(text: String, font: Font = .body, color: Color = .primary) {
        self.text = text
        self.font = font
        self.color = color
    }

    public var body: some View {
        Text(text)
            .font(font)
            .foregroundColor(color)
            .lineLimit(1)
            .truncationMode(.tail)
    }
}
