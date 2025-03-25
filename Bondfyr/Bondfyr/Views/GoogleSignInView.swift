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

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image("BondfyrLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)

            Text("Welcome to Bondfyr")
                .font(.title)
                .foregroundColor(.white)

            GoogleSignInButton(action: handleSignIn)
                .frame(width: 220, height: 50)

            Spacer()
        }
        .padding()
        .background(Color.black.ignoresSafeArea())
    }

    private func handleSignIn() {
        guard let rootVC = UIApplication.shared.windows.first?.rootViewController else { return }

        authViewModel.signInWithGoogle(presenting: rootVC) { success, error in
            if !success {
                print("❌ Google Sign-In Failed: \(error?.localizedDescription ?? "Unknown error")")
            }
        }
    }
}
