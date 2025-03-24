//
//  Onboarding.swift
//  Bondfyr
//
//  Created by Arjun Varma on 24/03/25.
//

import SwiftUI

struct OnboardingView: View {
    @State private var currentPage = 0
    let totalPages = 3

    var body: some View {
        VStack {
            TabView(selection: $currentPage) {
                OnboardingCard(title: "Discover Events", subtitle: "Explore curated gigs, nightlife and exclusive parties around you.", imageName: "sparkles")
                    .tag(0)
                OnboardingCard(title: "Buy Smart Tickets", subtitle: "Tiered passes, group deals, gender-balanced discounts & more.", imageName: "ticket")
                    .tag(1)
                OnboardingCard(title: "Smooth Entry", subtitle: "QR codes, real-time check-ins & lightning-fast payments.", imageName: "qrcode.viewfinder")
                    .tag(2)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
            .padding(.bottom, 40)

            Button(action: {
                if currentPage < totalPages - 1 {
                    currentPage += 1
                } else {
                    // Go to login
                    UIApplication.shared.windows.first?.rootViewController = UIHostingController(rootView: LoginView())
                }
            }) {
                Text(currentPage < totalPages - 1 ? "Next" : "Get Started")
                    .fontWeight(.bold)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.pink)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .padding(.horizontal)
            }
        }
    }
}

struct OnboardingCard: View {
    let title: String
    let subtitle: String
    let imageName: String

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: imageName)
                .resizable()
                .scaledToFit()
                .frame(height: 120)
                .foregroundColor(.blue)

            Text(title)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)

            Text(subtitle)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.gray)
                .padding(.horizontal, 30)
        }
    }
}
