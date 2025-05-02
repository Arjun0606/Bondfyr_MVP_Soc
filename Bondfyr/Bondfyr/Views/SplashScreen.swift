import SwiftUI

struct SplashScreen: View {
    @State private var animate = false

    var body: some View {
        ZStack {
            GrainyBackground()
            VStack {
                Image("divo_logo") // Add your logo as "divo_logo" in assets
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    .scaleEffect(animate ? 1 : 0.7)
                    .opacity(animate ? 1 : 0)
                    .animation(.easeOut(duration: 1.0), value: animate)
                Text("DIVO")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(Color("#FA812F"))
                    .opacity(animate ? 1 : 0)
                    .animation(.easeOut(duration: 1.2).delay(0.2), value: animate)
            }
        }
        .onAppear { animate = true }
    }
} 