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
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        VStack(spacing: 20) {
            Text("Welcome to Bondfyr")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)

            TextField("Email", text: $email)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .padding()
                .background(Color.white.opacity(0.1))
                .cornerRadius(10)
                .foregroundColor(.white)

            SecureField("Password", text: $password)
                .padding()
                .background(Color.white.opacity(0.1))
                .cornerRadius(10)
                .foregroundColor(.white)

            Button(action: {
                authViewModel.login(email: email, password: password) { success in
                    if !success {
                        print("Login failed")
                    }
                }
            }) {
                Text("Login")
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.pink)
                    .cornerRadius(10)
            }

            GoogleSignInButton {
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let rootViewController = windowScene.windows.first?.rootViewController {
                    authViewModel.signInWithGoogle(presenting: rootViewController) { success, error in
                        if success {
                            print("✅ Google Sign-In success")
                        } else {
                            print("❌ Google Sign-In failed: \(error?.localizedDescription ?? "Unknown error")")
                        }
                    }
                }
            }
            .frame(height: 50)
            .padding(.horizontal)

            NavigationLink(
                destination: SignUpView().environmentObject(authViewModel),
                label: {
                    Text("Don’t have an account? Sign up")
                        .foregroundColor(.gray)
                        .font(.footnote)
                }
            )
        }
        .padding()
        .background(Color.black.ignoresSafeArea())
    }
}
