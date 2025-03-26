//
//  GoogleSignInView.swift
//  Bondfyr
//
//  Created by Arjun Varma on 25/03/25.
//

import SwiftUI
import GoogleSignIn
import GoogleSignInSwift

struct GoogleSignInView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "flame.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .foregroundColor(.pink)

            Text("Welcome to Bondfyr")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)

            GoogleSignInButton(action: handleGoogleSignIn)
                .frame(height: 48)
                .padding(.horizontal)

            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
            }

            Spacer()
        }
        .padding()
        .background(Color.black.ignoresSafeArea())
    }

    func handleGoogleSignIn() {
        guard let rootVC = UIApplication.shared.connectedScenes
            .compactMap({ ($0 as? UIWindowScene)?.keyWindow?.rootViewController })
            .first else { return }

        isLoading = true
        authViewModel.signInWithGoogle(presenting: rootVC) { success, error in
            DispatchQueue.main.async {
                isLoading = false
            }

            if let error = error {
                print("❌ Google Sign-In Error: \(error.localizedDescription)")
            }

            if success {
                // handled in SplashView already
            }
        }
    }
}
