import SwiftUI

struct VerificationGuideView: View {
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Header
                        headerSection
                        
                        // Verification Types
                        verificationTypesSection
                        
                        // Benefits Section
                        benefitsSection
                        
                        // Social Features
                        socialFeaturesSection
                        
                        // Rating System
                        ratingSystemSection
                        
                        Spacer(minLength: 20)
                    }
                    .padding()
                }
            }
            .navigationTitle("Verification Guide")
            .navigationBarTitleDisplayMode(.large)
            .navigationBarItems(trailing: Button("Done") {
                isPresented = false
            })
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("🛡️ Verification System")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text("Build trust and credibility in the Bondfyr community by getting verified!")
                .font(.subheadline)
                .foregroundColor(.gray)
                .lineLimit(nil)
        }
    }
    
    private var verificationTypesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("🎯 Verification Types")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            // Host Verification
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundColor(.green)
                        .font(.title3)
                    Text("Host Verification")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    RequirementRow(
                        icon: "calendar.badge.plus",
                        requirement: "Host 4 successful parties",
                        description: "Organize and host 4 events through Bondfyr"
                    )
                    RequirementRow(
                        icon: "star.fill",
                        requirement: "Maintain good ratings",
                        description: "Keep a positive host rating from guests"
                    )
                }
                .padding(.leading, 40)
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)
            
            // Guest Verification
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "person.badge.shield.checkmark.fill")
                        .foregroundColor(.blue)
                        .font(.title3)
                    Text("Guest Verification")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    RequirementRow(
                        icon: "person.3.fill",
                        requirement: "Attend 8 parties",
                        description: "Check in to 8 events and participate actively"
                    )
                    RequirementRow(
                        icon: "heart.fill",
                        requirement: "Be an engaged member",
                        description: "Receive ratings and connect with other party-goers"
                    )
                }
                .padding(.leading, 40)
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)
        }
    }
    
    private var benefitsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("✨ Verification Benefits")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            VStack(alignment: .leading, spacing: 12) {
                VerificationBenefitRow(
                    icon: "checkmark.seal.fill",
                    benefit: "Trust Badge",
                    description: "Show others you're a reliable community member"
                )
                VerificationBenefitRow(
                    icon: "eye.fill",
                    benefit: "Increased Visibility",
                    description: "Verified profiles get priority in event listings"
                )
                VerificationBenefitRow(
                    icon: "star.circle.fill",
                    benefit: "Special Features",
                    description: "Access to exclusive events and early registration"
                )
                VerificationBenefitRow(
                    icon: "crown.fill",
                    benefit: "Elite Status",
                    description: "Join the verified community of trusted members"
                )
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)
        }
    }
    
    private var socialFeaturesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("❤️ Social Connection System")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            VStack(alignment: .leading, spacing: 12) {
                FeatureRow(
                    icon: "heart.fill",
                    title: "Event Likes",
                    description: "Like other party-goers during events to show appreciation"
                )
                FeatureRow(
                    icon: "person.crop.circle.fill",
                    title: "User Profiles",
                    description: "View detailed profiles showing reputation and verification status"
                )
                FeatureRow(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Reputation Tracking",
                    description: "Build your reputation through positive interactions"
                )
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)
        }
    }
    
    private var ratingSystemSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("⭐ Rating System")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("After each event, hosts and guests can rate each other:")
                    .foregroundColor(.gray)
                
                RatingExplainRow(
                    stars: 5,
                    description: "Outstanding experience, would highly recommend"
                )
                RatingExplainRow(
                    stars: 4,
                    description: "Great experience, very enjoyable"
                )
                RatingExplainRow(
                    stars: 3,
                    description: "Good experience, met expectations"
                )
                RatingExplainRow(
                    stars: 2,
                    description: "Fair experience, some room for improvement"
                )
                RatingExplainRow(
                    stars: 1,
                    description: "Poor experience, significant issues"
                )
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)
        }
    }
}

struct RequirementRow: View {
    let icon: String
    let requirement: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.pink)
                .font(.system(size: 16))
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(requirement)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .lineLimit(nil)
            }
        }
    }
}

struct VerificationBenefitRow: View {
    let icon: String
    let benefit: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.green)
                .font(.system(size: 16))
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(benefit)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .lineLimit(nil)
            }
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.pink)
                .font(.system(size: 16))
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .lineLimit(nil)
            }
        }
    }
}

struct RatingExplainRow: View {
    let stars: Int
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            HStack(spacing: 2) {
                ForEach(1...5, id: \.self) { index in
                    Image(systemName: "star.fill")
                        .foregroundColor(index <= stars ? .yellow : .gray.opacity(0.3))
                        .font(.caption)
                }
            }
            .frame(width: 60)
            
            Text(description)
                .font(.caption)
                .foregroundColor(.gray)
                .lineLimit(nil)
        }
    }
}

#Preview {
    VerificationGuideView(isPresented: .constant(true))
} 