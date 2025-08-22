//
//  GoogleSignInView.swift
//  Bondfyr
//
//  Created by Arjun Varma on 25/03/25.
//

import SwiftUI
import GoogleSignIn
import GoogleSignInSwift
import AuthenticationServices

struct GoogleSignInView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var showError = false
    @State private var logoScale: CGFloat = 1.0
    @State private var backgroundAnimation = false
    @State private var isDemoMode = false
    
    var body: some View {
        ZStack {
            // Animated background
            ZStack {
                // Base black background
                Color.black.ignoresSafeArea()
                
                // Animated gradient overlay
                RadialGradient(
                    gradient: Gradient(colors: [
                        Color.pink.opacity(backgroundAnimation ? 0.2 : 0.1),
                        Color.black.opacity(0.9)
                    ]),
                    center: .center,
                    startRadius: 100,
                    endRadius: backgroundAnimation ? 400 : 300
                )
                .ignoresSafeArea()
                .animation(
                    Animation.easeInOut(duration: 4)
                        .repeatForever(autoreverses: true),
                    value: backgroundAnimation
                )
                
                // Particle effect
                ForEach(0..<30) { _ in
                    Circle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: CGFloat.random(in: 2...6))
                        .position(
                            x: CGFloat.random(in: 0...UIScreen.main.bounds.width),
                            y: CGFloat.random(in: 0...UIScreen.main.bounds.height)
                        )
                        .blur(radius: 1)
                }
            }
            
            // Main content
            VStack(spacing: 24) {
                Spacer()
                
                // Logo with subtle bounce animation
                ZStack {
                    // Glow effect
                    Image("logo_screens")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 190)
                        .blur(radius: 15)
                        .opacity(0.4)
                        .foregroundColor(.pink)
                    
                    // Main logo
                    Image("logo_screens")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 180)
                }
                .scaleEffect(logoScale)
                .padding(.bottom, 20)
                
                // Welcome text with subtle shadow
                Text("Welcome to Bondfyr")
                    .font(.custom("Avenir-Black", size: 28))
                    .fontWeight(.heavy)
                    .foregroundColor(.white)
                    .shadow(color: .pink.opacity(0.5), radius: 10, x: 0, y: 0)
                    .padding(.bottom, 20)
                
                // Error message
                if let errorMessage = errorMessage, showError {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .frame(maxWidth: 300)
                        .padding(.vertical, 10)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                }
                
                // Demo Mode Toggle
                HStack {
                    Text("Demo Mode (App Review)")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Toggle("", isOn: $isDemoMode)
                        .toggleStyle(SwitchToggleStyle(tint: .pink))
                        .scaleEffect(0.8)
                }
                .padding(.bottom, 10)
                
                // Sign in buttons with enhanced styling
                VStack(spacing: 16) {
                    // Sign in with Apple button
                    SignInWithAppleButton(
                        onRequest: { request in
                            configureAppleSignIn(request)
                        },
                        onCompletion: { result in
                            handleAppleSignInResult(result)
                        }
                    )
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 55)
                    .frame(maxWidth: 300)
                    .cornerRadius(12)
                    .shadow(color: Color.pink.opacity(0.3), radius: 10, x: 0, y: 4)
                    .disabled(isLoading)
                    
                    // Custom Google sign-in button
                    Button(action: handleGoogleSignIn) {
                        HStack(spacing: 12) {
                            // Google logo
                            Image(systemName: "g.circle.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 22, height: 22)
                                .foregroundColor(.white)
                            
                            Text("Sign in with Google")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                        }
                        .frame(height: 55)
                        .frame(maxWidth: 300)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.black.opacity(0.8), Color.black.opacity(0.9)]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(LinearGradient(
                                    gradient: Gradient(colors: [Color.pink.opacity(0.8), Color.pink.opacity(0.4)]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ), lineWidth: 1.5)
                        )
                        .cornerRadius(12)
                        .shadow(color: Color.pink.opacity(0.3), radius: 10, x: 0, y: 4)
                    }
                    .disabled(isLoading)
                    
                    // Demo Mode Button
                    if isDemoMode {
                        Button(action: handleDemoSignIn) {
                            HStack(spacing: 12) {
                                Image(systemName: "play.circle.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 22, height: 22)
                                    .foregroundColor(.white)
                                
                                Text("Continue as Demo User")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white)
                            }
                            .frame(height: 55)
                            .frame(maxWidth: 300)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.orange.opacity(0.8), Color.orange.opacity(0.9)]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(12)
                            .shadow(color: Color.orange.opacity(0.3), radius: 10, x: 0, y: 4)
                        }
                        .disabled(isLoading)
                    }
                    
                    // Loading indicator
                    if isLoading {
                        VStack(spacing: 12) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.2)
                            
                            Text("Signing in...")
                                .foregroundColor(.gray)
                                .font(.caption)
                        }
                        .padding()
                        .background(Color.black.opacity(0.3))
                        .cornerRadius(12)
                    }
                }
                
                Spacer()
                
                // App version or branding
                Text("v1.0")
                    .font(.caption2)
                    .foregroundColor(.gray.opacity(0.6))
                    .padding(.bottom, 20)
            }
            .padding(.horizontal, 30)
        }
        .onAppear {
            // Start animations
            withAnimation(Animation.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                logoScale = 1.05
                backgroundAnimation = true
            }
        }
    }

    func handleGoogleSignIn() {
        // Clear previous errors
        errorMessage = nil
        showError = false
        
        guard let rootVC = UIApplication.shared.connectedScenes
            .compactMap({ ($0 as? UIWindowScene)?.keyWindow?.rootViewController })
            .first else { 
                errorMessage = "Unable to present sign-in flow"
                showError = true
                return 
            }

        isLoading = true
        authViewModel.signInWithGoogle(presenting: rootVC) { success, error in
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error = error {
                    self.errorMessage = "Sign-in failed: \(error.localizedDescription)"
                    self.showError = true
                } else if success {
                    // Set demo mode in UserDefaults if toggle is on
                    UserDefaults.standard.set(self.isDemoMode, forKey: "isDemoMode")
                    // Post notification that login succeeded
                    NotificationCenter.default.post(name: NSNotification.Name("UserDidLogin"), object: nil)
                    // Force onboarding state update
                    if let splash = UIApplication.shared.connectedScenes
                        .compactMap({ ($0 as? UIWindowScene)?.windows.first?.rootViewController as? UIHostingController<SplashView> })
                        .first {
                        splash.rootView.checkAuthStatus()
                    }
                }
            }
        }
    }
    
    func configureAppleSignIn(_ request: ASAuthorizationAppleIDRequest) {
        request.requestedScopes = [.fullName, .email]
    }
    
    func handleAppleSignInResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                handleAppleSignInCredential(appleIDCredential)
            } else {
                DispatchQueue.main.async {
                    self.errorMessage = "Invalid Apple Sign-In credentials"
                    self.showError = true
                }
            }
        case .failure(let error):
            print("❌ Apple Sign-In failed: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.isLoading = false
                self.errorMessage = "Apple Sign-In failed: \(error.localizedDescription)"
                self.showError = true
            }
        }
    }
    
    func handleAppleSignInCredential(_ credential: ASAuthorizationAppleIDCredential) {
        print("🍎 Processing Apple Sign-In credential...")
        isLoading = true
        
        authViewModel.signInWithApple(credential: credential) { success, error in
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error = error {
                    print("❌ Apple Sign-In error: \(error.localizedDescription)")
                    self.errorMessage = "Apple Sign-In failed: \(error.localizedDescription)"
                    self.showError = true
                } else if success {
                    print("✅ Apple Sign-In successful!")
                    // Set demo mode in UserDefaults if toggle is on
                    UserDefaults.standard.set(self.isDemoMode, forKey: "isDemoMode")
                    // Post notification that login succeeded
                    NotificationCenter.default.post(name: NSNotification.Name("UserDidLogin"), object: nil)
                    // Force onboarding state update
                    if let splash = UIApplication.shared.connectedScenes
                        .compactMap({ ($0 as? UIWindowScene)?.windows.first?.rootViewController as? UIHostingController<SplashView> })
                        .first {
                        splash.rootView.checkAuthStatus()
                    }
                }
            }
        }
    }
    
    func handleDemoSignIn() {
        isLoading = true
        
        // Create a demo user account
        authViewModel.signInWithDemo { success, error in
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error = error {
                    self.errorMessage = "Demo sign-in failed: \(error.localizedDescription)"
                    self.showError = true
                } else if success {
                    // Always set demo mode for demo users
                    UserDefaults.standard.set(true, forKey: "isDemoMode")
                    // Post notification that login succeeded
                    NotificationCenter.default.post(name: NSNotification.Name("UserDidLogin"), object: nil)
                    // Force onboarding state update
                    if let splash = UIApplication.shared.connectedScenes
                        .compactMap({ ($0 as? UIWindowScene)?.windows.first?.rootViewController as? UIHostingController<SplashView> })
                        .first {
                        splash.rootView.checkAuthStatus()
                    }
                }
            }
        }
    }
}
