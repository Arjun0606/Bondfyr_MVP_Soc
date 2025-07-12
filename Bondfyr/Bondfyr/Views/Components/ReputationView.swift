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
                    Text("\(user.partiesHosted ?? 0)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Text("Hosted")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                // Parties attended
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(user.partiesAttended ?? 0)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Text("Attended")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                // Party hours (more meaningful than fake connections)
                if let partyHours = user.totalPartyHours, partyHours > 0 {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(partyHours)h")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        Text("Party Time")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                
                // Account age
                VStack(alignment: .leading, spacing: 2) {
                    Text(user.accountAgeDisplayText)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Text("Member")
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