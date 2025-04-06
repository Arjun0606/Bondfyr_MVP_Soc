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
    @State private var navigateToMainView = false
    @State private var navigateToProfileForm = false
    @State private var navigateToSignIn = false
    @State private var navigateToOnboarding = false
    
    // Debug flag to force showing GoogleSignInView
    @State private var forceShowSignIn = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            // Always show splash content first
            SplashContent(opacity: opacity)
        }
        .fullScreenCover(isPresented: $navigateToMainView) {
            MainTabView()
        }
        .fullScreenCover(isPresented: $navigateToProfileForm) {
            ProfileFormView()
        }
        .fullScreenCover(isPresented: $navigateToSignIn) {
            GoogleSignInView()
                .environmentObject(authViewModel)
                .onDisappear {
                    print("GoogleSignInView disappeared, checking auth...")
                    // When GoogleSignInView disappears, check if we are logged in
                    // This helps recover from the sign-in loop
                    if Auth.auth().currentUser != nil {
                        checkAuthStatus()
                    }
                }
        }
        .fullScreenCover(isPresented: $navigateToOnboarding) {
            OnboardingView(hasSeenOnboarding: $hasSeenOnboarding)
        }
        .onAppear {
            // For testing, allow direct navigation to sign-in
            if forceShowSignIn {
                navigateToSignIn = true
                return
            }
            
            startSplashAnimation()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("UserDidLogin"))) { _ in
            // Listen for login notification from GoogleSignInView
            checkAuthStatus()
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

    private func checkAuthStatus() {
        print("Checking auth status...")
        
        // Reset navigation state
        navigateToMainView = false
        navigateToProfileForm = false
        navigateToSignIn = false
        navigateToOnboarding = false
        
        if let user = Auth.auth().currentUser {
            print("Found current user: \(user.uid)")
            authViewModel.fetchUserProfile { success in
                if success && authViewModel.currentUser != nil {
                    print("User profile loaded - navigating to main view")
                    navigateToMainView = true
                } else {
                    print("No user profile - navigating to profile form")
                    navigateToProfileForm = true
                }
            }
        } else {
            print("No current user found")
            if !hasSeenOnboarding {
                print("Navigating to onboarding")
                navigateToOnboarding = true
            } else {
                print("Navigating to sign in")
                navigateToSignIn = true
            }
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
