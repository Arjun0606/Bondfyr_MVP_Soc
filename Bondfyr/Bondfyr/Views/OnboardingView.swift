//
//  OnboardingView.swift
//  Bondfyr
//
//  Created by Arjun Varma on 24/03/25.
//

import SwiftUI

struct OnboardingView: View {
    @State private var currentPage = 0
    @State private var navigateToSignIn = false
    let totalPages = 3
    @Binding var hasSeenOnboarding: Bool
    @State private var showSignIn = false
    @State private var backgroundOffset: CGFloat = 0
    @State private var showCitySelection = false
    
    // Onboarding data
    let onboardingData = [
        OnboardingPageData(
            title: "Discover Events",
            subtitle: "Explore curated gigs, nightlife and exclusive parties around you.",
            imageName: "logo_screens",
            systemImage: "sparkles",
            color: Color.pink,
            neonColor: Color.pink
        ),
        OnboardingPageData(
            title: "Buy Smart Tickets",
            subtitle: "Tiered passes, group deals, gender-balanced discounts & more.",
            imageName: "logo_screens",
            systemImage: "ticket",
            color: Color.pink.opacity(0.8),
            neonColor: Color.pink
        ),
        OnboardingPageData(
            title: "Smooth Entry",
            subtitle: "QR codes, real-time check-ins & lightning-fast payments.",
            imageName: "logo_screens",
            systemImage: "qrcode.viewfinder",
            color: Color.pink.opacity(0.6),
            neonColor: Color.pink
        )
    ]
    
    var body: some View {
        ZStack {
            // Animated background
            ZStack {
                // Deep black background
                Color.black.ignoresSafeArea()
                
                // Radial gradient like splash screen
                RadialGradient(
                    gradient: Gradient(colors: [Color.pink.opacity(0.2), Color.black]),
                    center: .center,
                    startRadius: 5,
                    endRadius: 500
                )
                .ignoresSafeArea()
                
                // Subtle particles like in splash screen
                ForEach(0..<20) { i in
                    Circle()
                        .fill(Color.pink.opacity(0.3))
                        .frame(width: CGFloat.random(in: 4...10))
                        .position(
                            x: CGFloat.random(in: 0...UIScreen.main.bounds.width),
                            y: CGFloat.random(in: 0...UIScreen.main.bounds.height)
                        )
                        .blur(radius: 2)
                        .opacity(0.3 + (currentPage == i % 3 ? 0.2 : 0))
                }
            }
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 20).repeatForever(autoreverses: true), value: backgroundOffset)
            .onAppear {
                self.backgroundOffset = 100
            }
            
            VStack(spacing: 0) {
                // Progress indicators
                HStack(spacing: 8) {
                    ForEach(0..<totalPages, id: \.self) { index in
                        Capsule()
                            .fill(currentPage == index ? Color.pink : Color.white.opacity(0.3))
                            .frame(width: currentPage == index ? 20 : 8, height: 8)
                            .animation(.spring(), value: currentPage)
                    }
                }
                .padding(.top, 40)
                
                // Page content
                TabView(selection: $currentPage) {
                    ForEach(0..<totalPages, id: \.self) { index in
                        OnboardingCardView(data: onboardingData[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentPage)
                
                // Action button
                Button(action: {
                    if currentPage < totalPages - 1 {
                        withAnimation {
                            currentPage += 1
                        }
                    } else {
                        // Mark onboarding as seen
                        UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
                        hasSeenOnboarding = true
                        // Show Google Sign-In first
                        showSignIn = true
                    }
                }) {
                    HStack {
                        Text(currentPage < totalPages - 1 ? "Next" : "Get Started")
                            .font(.headline)
                            .fontWeight(.bold)
                        Image(systemName: currentPage < totalPages - 1 ? "chevron.right" : "arrow.right")
                            .font(.footnote)
                    }
                    .foregroundColor(.white)
                    .frame(height: 56)
                    .frame(maxWidth: .infinity)
                    .background(
                        ZStack {
                            Color.black.opacity(0.7)
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.pink.opacity(0.08))
                                .blur(radius: 4)
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.pink.opacity(0.5), lineWidth: 1)
                        }
                    )
                    .cornerRadius(16)
                    .shadow(color: Color.pink.opacity(0.3), radius: 8, x: 0, y: 0)
                    .padding(.horizontal, 24)
                }
                .padding(.bottom, 50)
                .padding(.top, 30)
            }
        }
        .fullScreenCover(isPresented: $showSignIn) {
            GoogleSignInView()
        }
        .fullScreenCover(isPresented: $showCitySelection) {
            CitySelectionView { _ in
                showCitySelection = false
                showSignIn = true
            }
        }
    }
}

// Data structure for each onboarding page
struct OnboardingPageData {
    let title: String
    let subtitle: String
    let imageName: String
    let systemImage: String
    let color: Color
    let neonColor: Color
}

// Individual onboarding card with enhanced visuals
struct OnboardingCardView: View {
    let data: OnboardingPageData
    @State private var isAnimating = false
    @State private var glowIntensity: CGFloat = 0.8
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // Icon container with animations
            ZStack {
                // Outer glow - matching splash screen style
                Circle()
                    .fill(data.neonColor.opacity(0.15))
                    .frame(width: 200, height: 200)
                    .blur(radius: 20)
                    .opacity(glowIntensity)
                
                // Main icon with glow effect
                ZStack {
                    // Glow effect - matching splash screen style
                    Image(systemName: data.systemImage)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 80)
                        .foregroundColor(data.neonColor)
                        .blur(radius: 8)
                        .opacity(0.7)
                    
                    // Main icon
                    Image(systemName: data.systemImage)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 70)
                        .foregroundColor(.white)
                }
                .scaleEffect(isAnimating ? 1.05 : 1.0)
                
                // Small logo
                Image(data.imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40)
                    .opacity(0.8)
                    .offset(y: -70)
            }
            .padding(.bottom, 50)
            
            // Text content with subtle styling
            VStack(spacing: 16) {
                Text(data.title)
                    .font(.custom("Avenir-Black", size: 28))
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .shadow(color: data.neonColor.opacity(0.6), radius: 8, x: 0, y: 0)
                
                Text(data.subtitle)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(Color.gray.opacity(0.9))
                    .padding(.horizontal, 30)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
        .onAppear {
            withAnimation(Animation.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                isAnimating = true
                glowIntensity = 1.0
            }
        }
    }
}
