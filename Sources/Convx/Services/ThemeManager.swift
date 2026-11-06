import SwiftUI
import UIKit

// MARK: - Accent Color Options
public enum AccentColorOption: String, CaseIterable, Identifiable, Codable {
    case neonCyan = "Neon Cyan"
    case electricPurple = "Electric Purple"
    case sunsetAmber = "Sunset Amber"
    case roseGold = "Rose Gold"
    case emeraldGreen = "Emerald Green"
    case cupertinoCoral = "Cupertino Coral"
    case monochrome = "Pure Monochrome"
    case dynamicArtwork = "Dynamic Artwork"

    public var id: String { rawValue }

    public var staticColor: Color {
        switch self {
        case .neonCyan:        return Color(red: 0.00, green: 0.94, blue: 1.00) // #00F0FF
        case .electricPurple:  return Color(red: 0.68, green: 0.35, blue: 0.98) // #AD5AFF
        case .sunsetAmber:     return Color(red: 1.00, green: 0.65, blue: 0.10) // #FFA61A
        case .roseGold:        return Color(red: 1.00, green: 0.42, blue: 0.62) // #FF6B9E
        case .emeraldGreen:    return Color(red: 0.10, green: 0.82, blue: 0.55) // #1AD18C
        case .cupertinoCoral:  return Color(red: 1.00, green: 0.38, blue: 0.40) // #FF6166
        case .monochrome:      return Color.white
        case .dynamicArtwork:  return Color(red: 0.00, green: 0.94, blue: 1.00)
        }
    }
}

// MARK: - Glassmorphism Blur Intensity Styles
public enum GlassStyle: String, CaseIterable, Identifiable, Codable {
    case subtle = "Subtle Glass"
    case appleFrosted = "Apple Frosted"
    case deepVelvet = "Deep Velvet"

    public var id: String { rawValue }

    public var baseOpacity: Double {
        switch self {
        case .subtle:       return 0.60
        case .appleFrosted: return 0.88
        case .deepVelvet:   return 0.96
        }
    }

    public var whiteLift: Double {
        switch self {
        case .subtle:       return 0.06
        case .appleFrosted: return 0.12
        case .deepVelvet:   return 0.04
        }
    }

    public var rimOpacity: Double {
        switch self {
        case .subtle:       return 0.35
        case .appleFrosted: return 0.55
        case .deepVelvet:   return 0.20
        }
    }

    public var shadowRadius: CGFloat {
        switch self {
        case .subtle:       return 8
        case .appleFrosted: return 14
        case .deepVelvet:   return 22
        }
    }
}

// MARK: - Player Visualizer Center Modes
public enum PlayerCoverStyle: String, CaseIterable, Identifiable, Codable {
    case modern = "Modern Cover"
    case vinyl = "Retro Vinyl"
    case visualizer = "Spectrum Wave"
    case djLivi = "DJ Livi Hologram"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .modern:     return "square.fill"
        case .vinyl:      return "opticaldisc"
        case .visualizer: return "waveform"
        case .djLivi:     return "sparkles"
        }
    }
}

// MARK: - Asynchronous Dominant Artwork Color Extractor
@MainActor
public final class DominantColorService {
    public static let shared = DominantColorService()
    private var colorCache: [String: Color] = [:]

    private init() {}

    public func extractDominantColor(from image: UIImage, key: String) -> Color {
        if let cached = colorCache[key] { return cached }

        guard let cgImage = image.cgImage else { return AccentColorOption.neonCyan.staticColor }

        let width = 20
        let height = 20
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var rawData = [UInt8](repeating: 0, count: width * height * 4)

        guard let context = CGContext(
            data: &rawData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        ) else { return AccentColorOption.neonCyan.staticColor }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var bestColor = UIColor(red: 0.0, green: 0.94, blue: 1.0, alpha: 1.0)
        var maxVibrancy: CGFloat = -1.0

        for i in stride(from: 0, to: rawData.count, by: 4) {
            let r = CGFloat(rawData[i]) / 255.0
            let g = CGFloat(rawData[i+1]) / 255.0
            let b = CGFloat(rawData[i+2]) / 255.0

            var h: CGFloat = 0, s: CGFloat = 0, br: CGFloat = 0, a: CGFloat = 0
            let uic = UIColor(red: r, green: g, blue: b, alpha: 1.0)
            uic.getHue(&h, saturation: &s, brightness: &br, alpha: &a)

            if br > 0.25 && s > 0.30 {
                let vibrancy = s * (1.0 - abs(br - 0.65))
                if vibrancy > maxVibrancy {
                    maxVibrancy = vibrancy
                    let adjustedBr = max(br, 0.70)
                    bestColor = UIColor(hue: h, saturation: min(s * 1.15, 1.0), brightness: adjustedBr, alpha: 1.0)
                }
            }
        }

        let resolved = Color(bestColor)
        colorCache[key] = resolved
        return resolved
    }
}

// MARK: - Central Theme Manager
@MainActor
public final class ThemeManager: ObservableObject {
    public static let shared = ThemeManager()

    @AppStorage("accentOption") public var selectedAccent: AccentColorOption = .neonCyan
    @AppStorage("glassStyle") public var selectedGlassStyle: GlassStyle = .appleFrosted
    @AppStorage("coverStyle") public var selectedCoverStyle: PlayerCoverStyle = .modern
    @AppStorage("shakeToShuffle") public var shakeToShuffleEnabled: Bool = true
    @AppStorage("hapticsEnabled") public var hapticsEnabled: Bool = true

    @Published public var dynamicColor: Color = AccentColorOption.neonCyan.staticColor

    private init() {}

    public var activeAccentColor: Color {
        if selectedAccent == .dynamicArtwork {
            return dynamicColor
        }
        return selectedAccent.staticColor
    }

    public func updateDominantColor(from image: UIImage, key: String) {
        let extracted = DominantColorService.shared.extractDominantColor(from: image, key: key)
        withAnimation(.easeInOut(duration: 0.45)) {
            self.dynamicColor = extracted
        }
    }
}

// MARK: - Device Shake Notification
extension NSNotification.Name {
    public static let deviceDidShake = NSNotification.Name("ConvxDeviceDidShakeNotification")
}

#if os(iOS)
extension UIWindow {
    open override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        super.motionEnded(motion, with: event)
        if motion == .motionShake {
            NotificationCenter.default.post(name: .deviceDidShake, object: nil)
        }
    }
}
#endif
