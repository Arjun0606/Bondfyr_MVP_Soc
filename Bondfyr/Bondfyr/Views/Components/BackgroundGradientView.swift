import SwiftUI

struct BackgroundGradientView: View {
    var body: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color.black,
                Color.purple.opacity(0.7),
                Color(.systemIndigo).opacity(0.6)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
} 