//
//  GoogleSignInView.swift
//  Bondfyr
//
//  Created by Arjun Varma on 25/03/25.
//

import SwiftUI
import GoogleSignInSwift

struct GoogleSignInView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var isLoading = false
    @State private var showProfileForm = false
    @State private var navigateToMainApp = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                Image("BondfyrLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)

                Text("Welcome to Bondfyr")
                    .font(.title2)
                    .foregroundColor(.white)

                GoogleSignInButton(action: handleGoogleSignIn)
                    .frame(height: 50)
                    .padding(.horizontal, 40)

                Spacer()
            }

            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
            }
        }
        // Navigate to ProfileForm if needed
        .fullScreenCover(isPresented: $showProfileForm) {
            ProfileFormView()
                .environmentObject(authViewModel)
        }
        // Navigate to main app if logged in
        .fullScreenCover(isPresented: $navigateToMainApp) {
            MainTabView()
                .environmentObject(authViewModel)
        }
    }

    func handleGoogleSignIn() {
        guard let rootVC = UIApplication.shared.connectedScenes
            .compactMap({ ($0 as? UIWindowScene)?.keyWindow })
            .first?.rootViewController else {
            return
        }

        isLoading = true

        authViewModel.signInWithGoogle(presenting: rootVC) { success, _ in
            if success {
                authViewModel.fetchUserProfile { exists in
                    DispatchQueue.main.async {
                        isLoading = false
                        if exists {
                            authViewModel.isLoggedIn = true
                            navigateToMainApp = true
                        } else {
                            showProfileForm = true
                        }
                    }
                }
            } else {
                isLoading = false
            }
        }
    }
}

