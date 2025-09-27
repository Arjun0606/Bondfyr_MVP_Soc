import SwiftUI

enum BrandColors {
    static let primary = Color(hex: "FF3B5C")       // Bondfyr pink
    static let secondary = Color(hex: "8B5CF6")     // Purple accent
    static let accent = Color(hex: "FA812F")        // Orange accent
    static let background = Color.black
    static let surface = Color(hex: "1A1A1A")
    static let textPrimary = Color.white
    static let textSecondary = Color.gray

    static var primaryGradient: LinearGradient {
        LinearGradient(
            colors: [primary, secondary],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

struct BrandButtonStyle: ButtonStyle {
    var isEnabled: Bool = true
    var height: CGFloat = 54
    var cornerRadius: CGFloat = 12

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(
                Group {
                    if isEnabled {
                        BrandColors.primaryGradient
                    } else {
                        Color.gray.opacity(0.3)
                    }
                }
            )
            .cornerRadius(cornerRadius)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: configuration.isPressed)
    }
}

extension View {
    func brandPrimaryButtonStyle(enabled: Bool = true, height: CGFloat = 54) -> some View {
        self.buttonStyle(BrandButtonStyle(isEnabled: enabled, height: height))
    }
}


