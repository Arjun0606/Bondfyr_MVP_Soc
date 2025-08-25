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
    @State private var errorMessage: String? = nil
    @State private var showError = false
    @State private var logoScale: CGFloat = 1.0
    @State private var backgroundAnimation = false
    
    // Email/Password sign-in states
    @State private var email = ""
    @State private var password = ""
    @State private var showEmailSignIn = false

    @State private var showReviewerGuide = false
    
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
                
                // App Store Reviewer Info
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.blue)
                        Text("For App Store Reviewers")
                            .font(.caption)
                            .foregroundColor(.white)
                            .fontWeight(.medium)
                        Spacer()
                    }
                    
                    Text("Use demo account provided in App Review Information section")
                        .font(.caption2)
                        .foregroundColor(.blue)
                        .multilineTextAlignment(.leading)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                )
                .padding(.bottom, 10)
                
                // Sign in buttons with enhanced styling
                VStack(spacing: 16) {
                    // Apple Sign-In removed for faster App Store submission
                    
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
                    
                    // Email/Password sign-in button
                    Button(action: { showEmailSignIn.toggle() }) {
                        HStack(spacing: 12) {
                            Image(systemName: "envelope.circle.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 22, height: 22)
                                .foregroundColor(.white)
                            
                            Text("Sign in with Email")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                        }
                        .frame(height: 55)
                        .frame(maxWidth: 300)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.green.opacity(0.8), Color.green.opacity(0.9)]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(LinearGradient(
                                    gradient: Gradient(colors: [Color.green.opacity(0.8), Color.green.opacity(0.4)]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ), lineWidth: 1.5)
                        )
                        .cornerRadius(12)
                        .shadow(color: Color.green.opacity(0.3), radius: 10, x: 0, y: 4)
                    }
                    .disabled(isLoading)
                    
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
                    
                    // Email/Password sign-in form
                    if showEmailSignIn {
                        emailPasswordForm
                    }
                }
                
                Spacer()
                
                // App Store Reviewer Guide Button
                Button(action: { showReviewerGuide = true }) {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.blue)
                        Text("App Store Reviewer Guide")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                .padding(.bottom, 10)
                
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
        .sheet(isPresented: $showReviewerGuide) {
            AppStoreReviewerGuideView()
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
                    print("✅ Google Sign-In successful!")
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
    
    // Apple Sign-In functions removed for streamlined authentication
    

    
    // MARK: - Email/Password Sign-In Form
    
    private var emailPasswordForm: some View {
        VStack(spacing: 16) {
            VStack(spacing: 12) {
                // Email field
                VStack(alignment: .leading, spacing: 4) {
                    Text("Email")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    TextField("Enter your email", text: $email)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
                
                // Password field
                VStack(alignment: .leading, spacing: 4) {
                    Text("Password")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    SecureField("Enter your password", text: $password)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                // Demo account hint
                VStack(spacing: 4) {
                    Text("App Store Reviewers:")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.orange)
                    
                    Text("Use credentials from App Review Information")
                        .font(.caption2)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 4)
            }
            
            // Sign in button
            Button(action: handleEmailPasswordSignIn) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "envelope.fill")
                            .foregroundColor(.white)
                        Text("Sign In")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .frame(height: 50)
                .frame(maxWidth: .infinity)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.blue.opacity(0.8), Color.blue.opacity(0.9)]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
                .shadow(color: Color.blue.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .disabled(isLoading || email.isEmpty || password.isEmpty)
            
            // Cancel button
            Button("Cancel") {
                showEmailSignIn = false
                email = ""
                password = ""
            }
            .font(.caption)
            .foregroundColor(.gray)
        }
        .padding(20)
        .background(Color.black.opacity(0.8))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal, 20)
        .transition(.opacity.combined(with: .scale))
    }
    
    // MARK: - Email/Password Sign-In Handler
    
    func handleEmailPasswordSignIn() {
        guard !email.isEmpty, !password.isEmpty else { return }
        
        isLoading = true
        
        authViewModel.signInWithEmail(email: email, password: password) { success, error in
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error = error {
                    self.errorMessage = error.localizedDescription
                    self.showError = true
                } else if success {
                    print("✅ Email/Password sign-in successful!")
                    // Check if this is the demo account
                    if self.email == AppStoreDemoManager.demoEmail {
                        AppStoreDemoManager.shared.isDemoAccount = true
                        print("🎭 Demo account signed in successfully")
                    }
                    
                    // Post notification that login succeeded
                    NotificationCenter.default.post(name: NSNotification.Name("UserDidLogin"), object: nil)
                    
                    // Reset form
                    self.email = ""
                    self.password = ""
                    self.showEmailSignIn = false
                }
            }
        }
    }
}
