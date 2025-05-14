import SwiftUI
import BondfyrPhotos

struct BadgesView: View {
    let badges: [PhotoBadge]
    @State private var selectedBadge: PhotoBadge?
    @State private var showBadgeDetail = false
    
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 16) {
                // Header
                Text("Achievements")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.top)
                
                if badges.isEmpty {
                    emptyStateView
                } else {
                    badgeGrid
                }
            }
            .sheet(item: $selectedBadge) { badge in
                BadgeDetailView(badge: badge)
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "star.circle")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Badges Yet")
                .font(.title2)
                .foregroundColor(.white)
            
            Text("Participate in the community to earn badges!")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Spacer()
        }
    }
    
    private var badgeGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(badges) { badge in
                    BadgeCell(badge: badge)
                        .onTapGesture {
                            selectedBadge = badge
                        }
                }
            }
            .padding()
        }
    }
}

struct BadgeCell: View {
    let badge: PhotoBadge
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 8) {
            // Badge Icon
            AsyncImage(url: URL(string: badge.imageURL)) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                case .failure:
                    Image(systemName: "star.circle.fill")
                        .font(.system(size: 30))
                @unknown default:
                    EmptyView()
                }
            }
            .frame(width: 60, height: 60)
            .background(
                Circle()
                    .fill(Color(hex: badge.level.color))
                    .opacity(0.2)
            )
            .overlay(
                Circle()
                    .stroke(Color(hex: badge.level.color), lineWidth: 2)
                    .opacity(isAnimating ? 0.8 : 0.4)
            )
            .scaleEffect(isAnimating ? 1.1 : 1.0)
            
            // Badge Name
            Text(badge.name)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            
            // Level Indicator
            Text(badge.level.rawValue)
                .font(.caption2)
                .foregroundColor(Color(hex: badge.level.color))
        }
        .frame(height: 120)
        .onAppear {
            withAnimation(Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
}

struct BadgeDetailView: View {
    let badge: PhotoBadge
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 24) {
                // Close Button
                HStack {
                    Spacer()
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.white.opacity(0.2))
                            .clipShape(Circle())
                    }
                }
                .padding()
                
                // Badge Image
                AsyncImage(url: URL(string: badge.imageURL)) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    case .failure:
                        Image(systemName: "star.circle.fill")
                            .font(.system(size: 60))
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(width: 120, height: 120)
                .background(
                    Circle()
                        .fill(Color(hex: badge.level.color))
                        .opacity(0.2)
                )
                .overlay(
                    Circle()
                        .stroke(Color(hex: badge.level.color), lineWidth: 3)
                )
                
                // Badge Info
                VStack(spacing: 12) {
                    Text(badge.name)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text(badge.description)
                        .font(.body)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Text(badge.level.rawValue)
                        .font(.headline)
                        .foregroundColor(Color(hex: badge.level.color))
                    
                    // Progress Bar
                    ProgressView(value: badge.progress)
                        .progressViewStyle(LinearProgressViewStyle(tint: Color(hex: badge.level.color)))
                        .frame(width: 200)
                    
                    Text("Earned \(badge.earnedDate.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
            }
        }
    }
}

// Helper extension to create Color from hex string
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
} 