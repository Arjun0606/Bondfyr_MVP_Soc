//
//  AppStoreReviewerGuideView.swift
//  Bondfyr
//
//  Created by Claude AI for App Store Review
//

import SwiftUI

struct AppStoreReviewerGuideView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.green)
                                .font(.title2)
                            Text("App Store Reviewer Guide")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                        
                        Text("Complete walkthrough for App Store review")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .padding(.bottom, 10)
                    
                    // Authentication Compliance
                    GuideSection(
                        title: "🍎 Authentication (Guideline 4.8)",
                        items: [
                            "✅ Sign in with Apple: Privacy-first authentication",
                            "✅ Google Sign-In: Alternative option available", 
                            "✅ Demo Mode: Full functionality without real accounts",
                            "✅ No data collection beyond name and email",
                            "✅ Email privacy protection via Apple's private relay"
                        ]
                    )
                    
                    // Demo Mode Instructions
                    GuideSection(
                        title: "🎭 Demo Mode Instructions (Guideline 2.1)",
                        items: [
                            "1. Toggle 'Demo Mode' to ON",
                            "2. Tap 'Continue as Demo User'", 
                            "3. Profile auto-filled with demo data",
                            "4. Access to 6 diverse demo parties",
                            "5. Full host and guest functionality",
                            "6. No real payments or external dependencies"
                        ]
                    )
                    
                    // Key Features
                    GuideSection(
                        title: "🎉 Key Features to Review",
                        items: [
                            "🏠 Host parties with guest management",
                            "👥 Join parties as a guest",
                            "💳 P2P payments (Venmo, PayPal, Apple Pay)",
                            "🌍 Location-based party discovery", 
                            "⭐ Rating and review system",
                            "🛡️ Safety features and reporting",
                            "📱 Push notifications for updates"
                        ]
                    )
                    
                    // Monetization
                    GuideSection(
                        title: "💰 Monetization (App Store Compliant)",
                        items: [
                            "💡 Hosts pay listing fees via external web portal",
                            "🔄 P2P guest payments (bypasses Apple IAP)",
                            "🚫 No in-app purchases required",
                            "✅ Complies with App Store guidelines 3.1.1"
                        ]
                    )
                    
                    // Privacy & Safety
                    GuideSection(
                        title: "🛡️ Privacy & Safety",
                        items: [
                            "🔒 Minimal data collection",
                            "📍 Location used only for party discovery",
                            "🔞 Age verification (18+ required)",
                            "🚨 Report functionality for safety",
                            "✅ Privacy policy and terms accessible"
                        ]
                    )
                    
                    // Contact
                    VStack(alignment: .leading, spacing: 8) {
                        Text("📧 Questions or Issues?")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text("Contact: karjunvarma2001@gmail.com")
                            .font(.subheadline)
                            .foregroundColor(.pink)
                        
                        Text("This demo provides full app functionality without requiring real user accounts, payments, or external services.")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .italic()
                    }
                    .padding()
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(12)
                }
                .padding()
            }
            .background(Color.black.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.pink)
                }
            }
        }
    }
}

struct GuideSection: View {
    let title: String
    let items: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
            
            VStack(alignment: .leading, spacing: 6) {
                ForEach(items, id: \.self) { item in
                    HStack(alignment: .top) {
                        Text("•")
                            .foregroundColor(.pink)
                            .fontWeight(.bold)
                        Text(item)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        Spacer()
                    }
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
}

#Preview {
    AppStoreReviewerGuideView()
}
