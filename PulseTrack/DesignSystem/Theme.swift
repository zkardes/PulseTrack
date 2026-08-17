import SwiftUI

/// Central design system for the app. Sleek, dark, Whoop-inspired.
enum Theme {

    // MARK: - Colors
    enum Colors {
        static let background   = Color(hex: "0A0A0F")
        static let surface      = Color(hex: "15151C")
        static let surfaceHigh  = Color(hex: "1E1E28")
        static let stroke       = Color.white.opacity(0.06)

        static let textPrimary   = Color.white
        static let textSecondary = Color.white.opacity(0.62)
        static let textTertiary  = Color.white.opacity(0.38)

        // Metric accent colors
        static let recovery = Color(hex: "16E7B8")   // teal/green
        static let strain   = Color(hex: "4AA9FF")   // blue
        static let sleep    = Color(hex: "9B7BFF")   // purple
        static let heart    = Color(hex: "FF4D6D")   // red/pink

        /// Recovery zone color: red (low) -> yellow -> green (high)
        static func recoveryZone(_ percent: Double) -> Color {
            switch percent {
            case ..<34:  return Color(hex: "FF4D5E")
            case ..<67:  return Color(hex: "FFD23F")
            default:     return Color(hex: "16E7B8")
            }
        }
    }

    // MARK: - Typography
    enum Typography {
        static func metric(_ size: CGFloat = 48) -> Font {
            .system(size: size, weight: .bold, design: .rounded)
        }
        static let title    = Font.system(size: 22, weight: .bold, design: .rounded)
        static let headline = Font.system(size: 17, weight: .semibold, design: .rounded)
        static let body     = Font.system(size: 15, weight: .regular, design: .rounded)
        static let caption  = Font.system(size: 12, weight: .medium, design: .rounded)
        static let label    = Font.system(size: 11, weight: .semibold, design: .rounded)
    }

    // MARK: - Layout
    enum Layout {
        static let cornerRadius: CGFloat = 20
        static let cardPadding: CGFloat = 18
        static let spacing: CGFloat = 14
    }
}

// MARK: - Color hex helper
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB,
                  red: Double(r) / 255,
                  green: Double(g) / 255,
                  blue: Double(b) / 255,
                  opacity: Double(a) / 255)
    }
}
