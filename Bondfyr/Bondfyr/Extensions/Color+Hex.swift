import SwiftUI

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Safe Area Extensions for Dynamic Island Support
extension View {
    /// Adds top padding that works for all devices including Dynamic Island
    func safeTopPadding(_ amount: CGFloat = 8) -> some View {
        self.padding(.top, amount)
            .safeAreaInset(edge: .top, spacing: 0) {
                Color.clear.frame(height: 0)
            }
    }
    
    /// Background that properly handles safe areas
    func universalBackground(_ color: Color = .black) -> some View {
        self.background(
            ZStack {
                color.ignoresSafeArea(.all, edges: .bottom)
                color.ignoresSafeArea(.all, edges: .horizontal)
                // Don't ignore top safe area to respect Dynamic Island
            }
        )
    }
    
    /// Navigation-safe background for top-level views
    func navigationSafeBackground(_ color: Color = .black) -> some View {
        self.background(
            color.ignoresSafeArea(.container, edges: .bottom)
        )
    }
} 