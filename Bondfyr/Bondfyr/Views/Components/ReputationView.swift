import SwiftUI

struct ReputationView: View {
    let user: AppUser
    
    // Simplified verification thresholds
    private let partiesToVerifyHost = 3    // Lowered from 4
    private let partiesToVerifyGuest = 5   // Lowered from 8

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                // User's name
                Text(user.name)
                    .foregroundColor(.white)
                    .font(.headline)
                
                // Guest verification badge
                if user.isGuestVerified == true {
                    Text("⭐")
                        .help("Verified Guest")
                }
                
                // Host verification badge
                if user.isHostVerified == true {
                    Text("🏆")
                        .help("Verified Host")
                }
            }
            
            // Simple Stats Display
            HStack(spacing: 16) {
                // Parties hosted
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(user.hostedPartiesCount ?? 0)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Text("Hosted")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                // Parties attended
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(user.attendedPartiesCount ?? 0)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Text("Attended")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                // Verification badges
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        if user.isHostVerified == true {
                            Text("🏆")
                                .font(.title3)
                        }
                        if user.isGuestVerified == true {
                            Text("⭐")
                                .font(.title3)
                        }
                        if user.isHostVerified != true && user.isGuestVerified != true {
                            Text("👤")
                                .font(.title3)
                                .foregroundColor(.gray)
                        }
                    }
                    Text("Badges")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            // Verification Progress
            VStack(alignment: .leading, spacing: 8) {
                // Guest verification progress
                if user.isGuestVerified != true {
                    let attendedCount = user.partiesAttended ?? 0
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Guest Verification")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Spacer()
                            Text("\(attendedCount)/\(partiesToVerifyGuest)")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        ProgressView(value: Double(attendedCount), total: Double(partiesToVerifyGuest))
                            .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                            .scaleEffect(y: 0.7)
                    }
                }
                
                // Host verification progress  
                if user.isHostVerified != true {
                    let hostedCount = user.partiesHosted ?? 0
                    if hostedCount > 0 {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Host Verification")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                Spacer()
                                Text("\(hostedCount)/\(partiesToVerifyHost)")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            
                            ProgressView(value: Double(hostedCount), total: Double(partiesToVerifyHost))
                                .progressViewStyle(LinearProgressViewStyle(tint: .purple))
                                .scaleEffect(y: 0.7)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
} 