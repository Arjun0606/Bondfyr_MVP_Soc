import SwiftUI

struct GrainyBackground: View {
    var body: some View {
        ZStack {
            Color.white
            Image("grain") // Add a seamless grain PNG to your assets named "grain"
                .resizable(resizingMode: .tile)
                .opacity(0.12)
        }
        .ignoresSafeArea()
    }
} 