import SwiftUI

struct SimpleAchievementsView: View {
    let achievements: [SimpleAchievement]
    @Environment(\.presentationMode) var presentationMode
    
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 16) {
                    if achievements.isEmpty {
                        emptyStateView
                    } else {
                        achievementGrid
                    }
                }
            }
            .navigationTitle("Achievements")
            .navigationBarTitleDisplayMode(.large)
            .navigationBarItems(
                trailing: Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Text("🏆")
                .font(.system(size: 60))
            
            Text("No Achievements Yet")
                .font(.title2)
                .foregroundColor(.white)
            
            Text("Attend or host your first party to get started!")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Spacer()
        }
    }
    
    private var achievementGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(achievements) { achievement in
                    SimpleAchievementGridCell(achievement: achievement)
                }
            }
            .padding()
        }
    }
}

struct SimpleAchievementGridCell: View {
    let achievement: SimpleAchievement
    
    var body: some View {
        VStack(spacing: 12) {
            // Achievement Emoji
            Text(achievement.emoji)
                .font(.system(size: 50))
                .background(
                    Circle()
                        .fill(Color.purple.opacity(0.2))
                        .frame(width: 80, height: 80)
                )
            
            // Achievement Title
            Text(achievement.displayTitle)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            
            // Achievement Description
            Text(achievement.description)
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .lineLimit(3)
            
            // Earned Date
            Text("Earned \(achievement.earnedDate.formatted(date: .abbreviated, time: .omitted))")
                .font(.caption2)
                .foregroundColor(.gray.opacity(0.8))
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(15)
    }
}

struct SimpleAchievementToastView: View {
    let achievement: SimpleAchievement
    @Binding var isPresented: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            // Achievement Emoji
            Text(achievement.emoji)
                .font(.system(size: 40))
                .background(
                    Circle()
                        .fill(Color.purple.opacity(0.3))
                        .frame(width: 60, height: 60)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Achievement Unlocked!")
                    .font(.caption)
                    .foregroundColor(.purple)
                    .fontWeight(.semibold)
                
                Text(achievement.displayTitle)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text(achievement.description)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .lineLimit(2)
            }
            
            Spacer()
            
            Button(action: {
                withAnimation {
                    isPresented = false
                }
            }) {
                Image(systemName: "xmark")
                    .foregroundColor(.gray)
                    .padding(8)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color.black.opacity(0.9))
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(Color.purple.opacity(0.5), lineWidth: 1)
                )
        )
        .padding(.horizontal)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
} 