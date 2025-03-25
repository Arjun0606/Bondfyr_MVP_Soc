//
//  SplashView.swift
//  Bondfyr
//
//  Created by Arjun Varma on 24/03/25.
//

import SwiftUI
import FirebaseAuth

struct SplashView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var isChecking = true
    @State private var showSplash = true
    @State private var hasSeenOnboarding = UserDefaults.standard.bool(forKey: "hasSeenOnboarding")
    @State private var opacity: Double = 0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if showSplash {
                VStack(spacing: 12) {
                    Spacer()

                    Image(systemName: "flame.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                        .foregroundColor(.pink)

                    Text("Bondfyr")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    Spacer()
                }
                .opacity(opacity)
                .onAppear {
                    withAnimation(.easeIn(duration: 1.0)) {
                        opacity = 1.0 // Fade in
                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        withAnimation(.easeOut(duration: 0.5)) {
                            opacity = 0 // Fade out before transition
                        }

                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            checkAuthStatus()
                        }
                    }
                }
            } else {
                if !hasSeenOnboarding {
                    OnboardingView(hasSeenOnboarding: $hasSeenOnboarding)
                } else if let _ = Auth.auth().currentUser {
                    if authViewModel.currentUser == nil {
                        ProfileFormView()
                    } else {
                        MainTabView()
                    }
                } else {
                    GoogleSignInView()
                }
            }
        }
    }

    private func checkAuthStatus() {
        if let _ = Auth.auth().currentUser {
            authViewModel.fetchUserProfile { _ in
                showSplash = false
            }
        } else {
            showSplash = false
        }
    }
}
