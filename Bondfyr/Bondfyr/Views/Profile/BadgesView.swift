import SwiftUI

struct BadgesView: View {
    let badges: [UserBadge]
    @StateObject private var badgeService = BadgeService.shared
    @State private var selectedBadge: UserBadge?
    @State private var showBadgeDetail = false
    
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection
                    
                    // Verification Status
                    verificationStatusSection
                    
                    // Progress Badges (Almost there!)
                    if !badgeService.getProgressBadges().isEmpty {
                        progressBadgesSection
                    }
                    
                    // All Badges Grid
                    allBadgesSection
                }
                .padding()
            }
            .sheet(item: $selectedBadge) { badge in
                BadgeDetailView(badge: badge)
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("🏆 Achievements")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text("Build your reputation in the Bondfyr community")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
    }
    
    private var verificationStatusSection: some View {
        VStack(spacing: 16) {
            Text("Verification Status")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            HStack(spacing: 16) {
                VerificationBadgeCard(
                    type: .verifiedHost,
                    status: badgeService.verificationStatus,
                    progress: badgeService.badgeProgress.partiesHosted
                )
                
                VerificationBadgeCard(
                    type: .verifiedPartyGoer,
                    status: badgeService.verificationStatus,
                    progress: badgeService.badgeProgress.partiesAttended
                )
            }
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.1))
        .cornerRadius(16)
    }
    
    private var progressBadgesSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("🔥 Almost There!")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.orange)
                Spacer()
            }
            
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(badgeService.getProgressBadges()) { badge in
                    ProgressBadgeCard(badge: badge)
                        .onTapGesture {
                            selectedBadge = badge
                        }
                }
            }
        }
    }
    
    private var allBadgesSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("All Achievements")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Spacer()
                Text("\(badges.filter { $0.isEarned }.count)/\(badges.count)")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            if badges.isEmpty {
                emptyStateView
            } else {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(badges) { badge in
                        BadgeCard(badge: badge)
                            .onTapGesture {
                                selectedBadge = badge
                            }
                    }
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "star.circle")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Badges Yet")
                .font(.title2)
                .foregroundColor(.white)
            
            Text("Start hosting or attending parties to earn your first badge!")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 40)
    }
}

// MARK: - Verification Badge Card
struct VerificationBadgeCard: View {
    let type: BadgeType
    let status: UserVerificationStatus
    let progress: Int
    
    private var isVerified: Bool {
        switch type {
        case .verifiedHost:
            return status.isVerifiedHost
        case .verifiedPartyGoer:
            return status.isVerifiedPartyGoer
        default:
            return false
        }
    }
    
    private var progressPercentage: Double {
        return min(Double(progress) / 4.0, 1.0)
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Badge Icon
            Text(type.emoji)
                .font(.system(size: 40))
                .frame(width: 60, height: 60)
                .background(
                    Circle()
                        .fill(isVerified ? Color.yellow.opacity(0.2) : Color.gray.opacity(0.2))
                )
                .overlay(
                    Circle()
                        .stroke(isVerified ? Color.yellow : Color.gray, lineWidth: 2)
                )
            
            // Badge Title
            Text(type.rawValue)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            
            // Status/Progress
            if isVerified {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Verified")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                }
            } else {
                VStack(spacing: 8) {
                    Text("\(progress)/4")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    ProgressView(value: progressPercentage)
                        .progressViewStyle(LinearProgressViewStyle(tint: .orange))
                        .scaleEffect(y: 1.5)
                    
                    Text("\(4 - progress) more to go!")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isVerified ? Color.yellow.opacity(0.5) : Color.gray.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Progress Badge Card
struct ProgressBadgeCard: View {
    let badge: UserBadge
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(badge.type.emoji)
                    .font(.title2)
                Spacer()
                Text("\(Int(badge.progressPercentage * 100))%")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.orange)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(badge.name)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text(badge.progressText)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            ProgressView(value: badge.progressPercentage)
                .progressViewStyle(LinearProgressViewStyle(tint: .orange))
                .scaleEffect(y: 1.5)
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.5), lineWidth: 1)
        )
    }
}

// MARK: - Badge Card
struct BadgeCard: View {
    let badge: UserBadge
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 12) {
            // Badge Icon
            Text(badge.type.emoji)
                .font(.system(size: 32))
                .frame(width: 60, height: 60)
                .background(
                    Circle()
                        .fill(Color(hex: badge.level.color).opacity(badge.isEarned ? 0.3 : 0.1))
                )
                .overlay(
                    Circle()
                        .stroke(Color(hex: badge.level.color), lineWidth: badge.isEarned ? 2 : 1)
                        .opacity(badge.isEarned ? (isAnimating ? 1.0 : 0.7) : 0.5)
                )
                .scaleEffect(badge.isEarned ? (isAnimating ? 1.1 : 1.0) : 0.9)
                .saturation(badge.isEarned ? 1.0 : 0.3)
            
            // Badge Info
            VStack(spacing: 4) {
                Text(badge.name)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(badge.isEarned ? .white : .gray)
                    .multilineTextAlignment(.center)
                
                if badge.isEarned {
                    Text("Earned!")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                } else {
                    Text(badge.progressText)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            // Progress bar for non-earned badges
            if !badge.isEarned && badge.progress > 0 {
                ProgressView(value: badge.progressPercentage)
                    .progressViewStyle(LinearProgressViewStyle(tint: Color(hex: badge.level.color)))
                    .scaleEffect(y: 1.0)
            }
        }
        .padding()
        .background(Color(.systemGray6).opacity(badge.isEarned ? 0.15 : 0.05))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(hex: badge.level.color).opacity(badge.isEarned ? 0.5 : 0.2), lineWidth: 1)
        )
        .onAppear {
            if badge.isEarned {
                withAnimation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    isAnimating = true
                }
            }
        }
    }
}

// MARK: - Badge Detail View
struct BadgeDetailView: View {
    let badge: UserBadge
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            ScrollView {
                VStack(spacing: 32) {
                    // Close Button
                    HStack {
                        Spacer()
                        Button(action: {
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Image(systemName: "xmark")
                                .foregroundColor(.white)
                                .padding(12)
                                .background(Color.white.opacity(0.2))
                                .clipShape(Circle())
                        }
                    }
                    .padding()
                    
                    // Badge Display
                    VStack(spacing: 24) {
                        Text(badge.type.emoji)
                            .font(.system(size: 80))
                            .frame(width: 140, height: 140)
                            .background(
                                Circle()
                                    .fill(Color(hex: badge.level.color).opacity(badge.isEarned ? 0.3 : 0.1))
                            )
                            .overlay(
                                Circle()
                                    .stroke(Color(hex: badge.level.color), lineWidth: 3)
                            )
                        
                        Text(badge.name)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                        
                        Text(badge.description)
                            .font(.title3)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    // Status Section
                    VStack(spacing: 16) {
                        if badge.isEarned {
                            earnedSection
                        } else {
                            progressSection
                        }
                        
                        // Perks Section
                        perksSection
                    }
                    .padding()
                    .background(Color(.systemGray6).opacity(0.1))
                    .cornerRadius(20)
                    .padding(.horizontal)
                    
                    Spacer(minLength: 40)
                }
            }
        }
    }
    
    private var earnedSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title2)
                Text("Badge Earned!")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
            }
            
            if let earnedDate = badge.earnedDate {
                Text("Earned on \(earnedDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
        }
    }
    
    private var progressSection: some View {
        VStack(spacing: 16) {
            Text("Progress")
                .font(.headline)
                .foregroundColor(.white)
            
            VStack(spacing: 8) {
                HStack {
                    Text(badge.progressText)
                        .font(.subheadline)
                        .foregroundColor(.white)
                    Spacer()
                    Text("\(Int(badge.progressPercentage * 100))%")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                }
                
                ProgressView(value: badge.progressPercentage)
                    .progressViewStyle(LinearProgressViewStyle(tint: .orange))
                    .scaleEffect(y: 2.0)
            }
            
            Text("Keep going! You're \(badge.requirement - badge.progress) away from earning this badge.")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
    }
    
    private var perksSection: some View {
        VStack(spacing: 12) {
            Text("Perks & Benefits")
                .font(.headline)
                .foregroundColor(.white)
            
            Text(badge.type.perk)
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
    }
}

 