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
                        
                        // Achievement Milestones
                        achievementMilestonesSection
                        
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
            
            // Host Verification (updated threshold)
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("🏆")
                        .font(.title3)
                    Text("Host Verification")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    RequirementRow(
                        icon: "calendar.badge.plus",
                        requirement: "Host 3 successful parties",
                        description: "Organize and host 3 events through Bondfyr"
                    )
                    RequirementRow(
                        icon: "checkmark.circle.fill",
                        requirement: "Complete party requirements",
                        description: "Ensure guests have a great experience"
                    )
                }
                .padding(.leading, 40)
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)
            
            // Guest Verification (updated threshold)
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("⭐")
                        .font(.title3)
                    Text("Guest Verification")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    RequirementRow(
                        icon: "person.3.fill",
                        requirement: "Attend 5 parties",
                        description: "Check in to 5 events and participate actively"
                    )
                    RequirementRow(
                        icon: "checkmark.circle.fill",
                        requirement: "Complete party check-ins",
                        description: "Successfully check in and out at each party"
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
    
    private var achievementMilestonesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("🏆 Achievement Milestones")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Celebrate your Bondfyr journey with meaningful milestones:")
                    .foregroundColor(.gray)
                
                AchievementMilestoneRow(
                    emoji: "🎉",
                    title: "First Host",
                    description: "Successfully host your first afterparty"
                )
                AchievementMilestoneRow(
                    emoji: "🕺",
                    title: "Party Goer",
                    description: "Attend your first afterparty"
                )
                AchievementMilestoneRow(
                    emoji: "🏆",
                    title: "Verified Host",
                    description: "Become a verified, trusted host"
                )
                AchievementMilestoneRow(
                    emoji: "⭐",
                    title: "Verified Guest",
                    description: "Become a verified community member"
                )
                AchievementMilestoneRow(
                    emoji: "💎",
                    title: "Party Legend",
                    description: "Reach major party milestones (10, 25, 50+)"
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

struct AchievementMilestoneRow: View {
    let emoji: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(emoji)
                .font(.title3)
                .foregroundColor(.pink)
            
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

#Preview {
    VerificationGuideView(isPresented: .constant(true))
} 