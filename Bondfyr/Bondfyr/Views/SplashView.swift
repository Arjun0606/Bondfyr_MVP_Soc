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
    @State private var opacity: Double = 0
    @State private var navigateToMainView = false
    @State private var navigateToProfileForm = false
    @State private var navigateToSignIn = false
    @State private var forceShowSocialLink = false
    
    @State private var forceShowSignIn = false

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color.black, Color(red: 0.2, green: 0.08, blue: 0.3)]),
                startPoint: .top,
                endPoint: .bottom
            ).ignoresSafeArea()
            
            // Always show splash content first
            SplashContent(opacity: opacity)
        }
        .fullScreenCover(isPresented: $navigateToMainView) {
            MainTabView()
                .environmentObject(AppStoreDemoManager.shared)
        }
        .fullScreenCover(isPresented: $navigateToProfileForm) {
            ProfileFormView()
                .interactiveDismissDisabled(true)
        }
        .fullScreenCover(isPresented: $navigateToSignIn) {
            GoogleSignInView()
                .environmentObject(authViewModel)
                .onDisappear {
                    // When GoogleSignInView disappears, check if we are logged in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        if let user = Auth.auth().currentUser {
                            // Check for profile completion
                            let hasUsername = (self.authViewModel.currentUser?.username?.isEmpty == false)
                            let hasCity = (self.authViewModel.currentUser?.city?.isEmpty == false)
                            if hasUsername && hasCity {
                                self.navigateToMainView = true
                            } else {
                                self.navigateToProfileForm = true
                            }
                        } else {
                            // If we get here with no user, we need to ensure the sign-in view stays presented
                            if !navigateToMainView && !navigateToProfileForm {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    navigateToSignIn = true
                                }
                            }
                        }
                    }
                }
        }

        .onAppear {
            startSplashAnimation()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("UserDidLogin"))) { _ in
            // Listen for login notification from GoogleSignInView
            checkAuthStatus()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("UserProfileCompleted"))) { _ in
            // Navigate immediately when profile is completed
            self.navigateToMainView = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("UserDidLogout"))) { _ in
            // Listen for logout notification
            // First ensure we're not showing other screens
            navigateToMainView = false
            navigateToProfileForm = false
            
            // Clear auth state in view model
            DispatchQueue.main.async {
                authViewModel.currentUser = nil
                authViewModel.isLoggedIn = false
            }
            
            // Force sign out from Firebase
            if Auth.auth().currentUser != nil {
                do {
                    try Auth.auth().signOut()
                } catch {
                    // Silent error handling
                }
            }
            
            // Allow any pending dismiss animations to complete
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                // Force show sign in view
                navigateToSignIn = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("UserWasDeleted"))) { _ in
            // Account deleted: reset navigation flags and present sign-in immediately
            navigateToMainView = false
            navigateToProfileForm = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                navigateToSignIn = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("UserProfileCancelled"))) { _ in
            // User opted not to finish profile right now; return to sign-in
            navigateToMainView = false
            navigateToProfileForm = false
            navigateToSignIn = true
        }
    }
    
    private func startSplashAnimation() {
        // Show splash with animation
        withAnimation(.easeIn(duration: 1.0)) {
            opacity = 1.0
        }

        // After delay, fade out and check auth
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeOut(duration: 0.8)) {
                opacity = 0
            }

            // Start checking auth status during fade-out animation
            // instead of waiting for it to complete
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                checkAuthStatus()
            }
        }
    }

    func checkAuthStatus() {
        // Reset all navigation flags
        navigateToMainView = false
        navigateToProfileForm = false
        navigateToSignIn = false
        
        // For App Store reviewers: Force clean slate by clearing any existing auth
        // This ensures the app always starts with the sign-in screen
        print("🔍 Checking auth status - Current user: \(Auth.auth().currentUser?.uid ?? "none")")
        print("🔍 AuthViewModel logged in: \(authViewModel.isLoggedIn)")
        print("🔍 AuthViewModel current user: \(authViewModel.currentUser?.username ?? "none")")
        


        // Normal authentication flow - no force logout
        // Let users sign in naturally
        
        // Give the AuthStateListener a moment to update AuthViewModel
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { 
            // Check if we have a complete user profile first
            if let currentUser = self.authViewModel.currentUser,
               let username = currentUser.username, !username.isEmpty,
               let gender = currentUser.gender, !gender.isEmpty,
               let city = currentUser.city, !city.isEmpty,
               self.authViewModel.isLoggedIn && Auth.auth().currentUser != nil {
                // User is fully set up, go to main app
                print("✅ User fully authenticated, navigating to main app")
                self.navigateToMainView = true
            } else if self.authViewModel.isLoggedIn && Auth.auth().currentUser != nil {
                // User is logged in but needs to complete profile
                print("⚠️ User logged in but profile incomplete, fetching profile")
                // Trust local completion flag as fast-path to avoid loop when reads are blocked
                let uid = Auth.auth().currentUser?.uid ?? ""
                if UserDefaults.standard.bool(forKey: "profileCompleted_\(uid)") {
                    print("✅ Using local profileCompleted flag; navigating to main app")
                    self.navigateToMainView = true
                } else {
                    self.authViewModel.fetchUserProfile { success in 
                        if success {
                            self.evaluateProfileAndNavigate()
                        } else {
                            self.navigateToProfileForm = true
                        }
                    }
                }
            } else {
                // User not logged in, show sign-in options
                print("🔑 No user logged in, showing sign-in screen")
                self.navigateToSignIn = true
            }
        }
    }

    private func evaluateProfileAndNavigate() {
        guard let user = authViewModel.currentUser else {
            navigateToProfileForm = true
            return
        }

        // DEMO MODE: Skip profile checks for demo account
        if user.email == "appstore.reviewer@bondfyr.demo" {
            print("🎭 Demo account detected - bypassing profile checks")
            navigateToMainView = true
            return
        }

        let hasUsername = (user.username?.isEmpty == false)
        let hasGender = (user.gender?.isEmpty == false)
        let hasCity = (user.city?.isEmpty == false)

        if hasUsername && hasGender && hasCity {
            navigateToMainView = true
        } else {
            navigateToProfileForm = true
        }
    }
}

// Extracted splash screen content
struct SplashContent: View {
    var opacity: Double
    @State private var logoScale: CGFloat = 0.8
    @State private var textOpacity: Double = 0
    @State private var glowOpacity: Double = 0
    
    var body: some View {
        ZStack {
            // Background gradient
            RadialGradient(
                gradient: Gradient(colors: [Color.pink.opacity(0.3), Color.black]),
                center: .center,
                startRadius: 5,
                endRadius: 500
            )
            .ignoresSafeArea()
            
            // Animated particles
            ForEach(0..<20) { i in
                Circle()
                    .fill(Color.pink.opacity(0.3))
                    .frame(width: CGFloat.random(in: 4...10))
                    .position(
                        x: CGFloat.random(in: 0...UIScreen.main.bounds.width),
                        y: CGFloat.random(in: 0...UIScreen.main.bounds.height)
                    )
                    .blur(radius: 2)
                    .opacity(opacity)
            }
            
            // Logo with glow effect
            ZStack {
                // Glow effect
                Image("logo_screens")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 180)
                    .blur(radius: 10)
                    .opacity(glowOpacity * 0.7)
                    .foregroundColor(.pink)
                
                // Main logo
                Image("logo_screens")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 170)
            }
            .scaleEffect(logoScale)
            
            // App title with animation
            VStack(spacing: 0) {
                Spacer()
                
                Text("Bondfyr")
                    .font(.custom("Avenir-Black", size: 40))
                    .fontWeight(.black)
                    .foregroundColor(.white)
                    .padding(.bottom, 50)
                    .opacity(textOpacity)
                    .blur(radius: textOpacity < 0.8 ? 2 : 0)
            }
        }
        .opacity(opacity)
        .onAppear {
            withAnimation(.easeOut(duration: 1.2)) {
                logoScale = 1.0
                glowOpacity = 1.0
            }
            
            withAnimation(.easeIn(duration: 1.0).delay(0.7)) {
                textOpacity = 1.0
            }
        }
    }
} 