import SwiftUI

struct ReputationView: View {
    let user: AppUser
    
    // Verification thresholds
    private let partiesToVerifyHost = 4
    private let partiesToVerifyGuest = 8

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                // User's name
                Text(user.name)
                    .foregroundColor(.white)
                    .font(.headline)
                
                // Guest verification badge
                if user.isGuestVerified == true {
                    Text("✨")
                        .help("Verified Guest")
                }
                
                // Host verification badge
                if user.isHostVerified == true {
                    Text("👑")
                        .help("Verified Host")
                }
            }
            
            // Guest progress
            if !(user.isGuestVerified == true) {
                let attendedCount = user.attendedPartiesCount ?? 0
                ProgressView(value: Double(attendedCount), total: Double(partiesToVerifyGuest)) {
                    Text("Guest: \(attendedCount)/\(partiesToVerifyGuest) parties attended")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .accentColor(.pink)
            }
            
            // Host progress
            if !(user.isHostVerified == true) {
                 let hostedCount = user.hostedPartiesCount ?? 0
                 if hostedCount > 0 {
                     ProgressView(value: Double(hostedCount), total: Double(partiesToVerifyHost)) {
                        Text("Host: \(hostedCount)/\(partiesToVerifyHost) parties hosted")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .accentColor(.purple)
                 }
            }
            
            // Ratings
            HStack(spacing: 12) {
                if let guestRating = user.guestRating, guestRating > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                        Text(String(format: "%.1f", guestRating))
                            .foregroundColor(.white)
                        Text("(\(user.guestRatingsCount ?? 0))")
                            .foregroundColor(.gray)
                    }
                    .font(.caption)
                    .help("Average Guest Rating")
                }
                
                if let hostRating = user.hostRating, hostRating > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                        Text(String(format: "%.1f", hostRating))
                            .foregroundColor(.white)
                         Text("(\(user.hostRatingsCount ?? 0))")
                            .foregroundColor(.gray)
                    }
                    .font(.caption)
                    .help("Average Host Rating")
                }
            }
        }
    }
} 