//
//  LoginView.swift
//  Bondfyr
//
//  Created by Arjun Varma on 24/03/25.
//

import SwiftUI
import GoogleSignInSwift

struct LoginView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var isSigningIn = false

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Text("Welcome to Bondfyr")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.white)

            Spacer()

            GoogleSignInButton(action: handleGoogleSignIn)
                .frame(height: 50)
                .padding(.horizontal)

            Spacer()
        }
        .padding()
        .background(Color.black.ignoresSafeArea())
    }

    func handleGoogleSignIn() {
        guard let rootViewController = UIApplication.shared.connectedScenes
                .compactMap({ ($0 as? UIWindowScene)?.keyWindow?.rootViewController })
                .first else {
            return
        }

        isSigningIn = true
        authViewModel.signInWithGoogle(presenting: rootViewController) { success, error in
            isSigningIn = false
            if let error = error {
                print("❌ Google Sign-In error: \(error.localizedDescription)")
            } else {
                print("✅ Google Sign-In success")
            }
        }
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView().environmentObject(AuthViewModel())
    }
}
