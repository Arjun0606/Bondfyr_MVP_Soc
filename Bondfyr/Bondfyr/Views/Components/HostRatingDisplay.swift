import SwiftUI

struct HostRatingDisplay: View {
    let hostId: String
    let isVerified: Bool
    let hostedPartiesCount: Int
    let averageRating: Double?
    
    var body: some View {
        HStack(spacing: 8) {
            // Verification Badge
            if isVerified {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.pink)
                        .font(.caption)
                    Text("Verified Host")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.pink)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.pink.opacity(0.15))
                .cornerRadius(8)
            }
            
            // Rating Display
            if let rating = averageRating, rating > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                        .font(.caption2)
                    Text(String(format: "%.1f", rating))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                }
            }
            
            // Hosted Count
            Text("\(hostedPartiesCount) parties")
                .font(.caption2)
                .foregroundColor(.gray)
        }
    }
}

// Convenience initializer for use with AppUser
struct HostRatingDisplay_FromUser: View {
    let user: AppUser?
    
    var body: some View {
        HostRatingDisplay(
            hostId: user?.uid ?? "",
            isVerified: user?.isHostVerified ?? false,
            hostedPartiesCount: user?.hostedPartiesCount ?? 0,
            averageRating: nil // Could be calculated from user's party history
        )
    }
}

#Preview {
    VStack(spacing: 16) {
        HostRatingDisplay(
            hostId: "test123",
            isVerified: true,
            hostedPartiesCount: 8,
            averageRating: 4.7
        )
        
        HostRatingDisplay(
            hostId: "test456",
            isVerified: false,
            hostedPartiesCount: 2,
            averageRating: 3.8
        )
        
        HostRatingDisplay(
            hostId: "newhost",
            isVerified: false,
            hostedPartiesCount: 0,
            averageRating: nil
        )
    }
    .padding()
    .background(Color.black)
} 