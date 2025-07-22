import SwiftUI

// MARK: - Fixed Guest Row Components
struct FixedPendingGuestRow: View {
    let request: GuestRequest
    let onApprove: () -> Void
    let onDeny: () -> Void
    
    @State private var showingUserProfile = false
    @State private var showingFullMessage = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // User Header with FIXED profile button
            HStack(spacing: 12) {
                // Profile Image/Icon
                Button(action: {
                    print("🔍 PROFILE: Opening profile for \(request.userName)")
                    showingUserProfile = true
                }) {
                    Image(systemName: "person.circle.fill")
                        .font(.title2)
                        .foregroundColor(.orange)
                }
                .buttonStyle(BorderlessButtonStyle()) // CRITICAL: Prevents area expansion
                
                // User Info
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(request.userName)
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        // Secondary profile button for redundancy
                        Button(action: {
                            print("🔍 PROFILE: Opening profile (secondary) for \(request.userName)")
                            showingUserProfile = true
                        }) {
                            Image(systemName: "info.circle")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                    }
                    
                    Text("@\(request.userHandle)")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Text(formatTimeAgo(request.requestedAt))
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
            }
            
            // Intro Message
            if !request.introMessage.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Message:")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.gray)
                    
                    Text(request.introMessage)
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .lineLimit(showingFullMessage ? nil : 3)
                        .onTapGesture {
                            showingFullMessage.toggle()
                        }
                }
                .padding(12)
                .background(Color.white.opacity(0.05))
                .cornerRadius(8)
            }
            
            // CRITICAL: Clear separator to prevent touch conflicts
            Divider()
                .background(Color.gray.opacity(0.3))
                .padding(.vertical, 4)
            
            // Action Buttons - COMPLETELY ISOLATED
            HStack(spacing: 16) {
                // Approve Button
                Button(action: {
                    print("✅ APPROVE: Button tapped for \(request.userHandle)")
                    onApprove()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Approve")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .buttonStyle(BorderlessButtonStyle())
                
                // Deny Button
                Button(action: {
                    print("❌ DENY: Button tapped for \(request.userHandle)")
                    onDeny()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "xmark.circle.fill")
                        Text("Deny")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .buttonStyle(BorderlessButtonStyle())
            }
        }
        .padding(.vertical, 8)
        .sheet(isPresented: $showingUserProfile) {
            UserInfoView(userId: request.userId)
        }
    }
    
    private func formatTimeAgo(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .named
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Fixed Approved Guest Row
struct FixedApprovedGuestRow: View {
    let request: GuestRequest
    @State private var showingUserProfile = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Profile Button - PROPERLY ISOLATED
            Button(action: {
                print("🔍 PROFILE: Opening approved guest profile for \(request.userName)")
                showingUserProfile = true
            }) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.green)
            }
            .buttonStyle(BorderlessButtonStyle())
            
            // User Info
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(request.userName)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    // Additional profile access
                    Button(action: {
                        print("🔍 PROFILE: Opening approved guest profile (alt) for \(request.userName)")
                        showingUserProfile = true
                    }) {
                        Image(systemName: "person.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }
                
                Text("@\(request.userHandle)")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                if let approvedAt = request.approvedAt {
                    Text("Approved \(formatTimeAgo(approvedAt))")
                        .font(.caption)
                        .foregroundColor(.green)
                }
                
                // Payment Status
                HStack {
                    Image(systemName: paymentStatusIcon)
                        .foregroundColor(paymentStatusColor)
                    Text(paymentStatusText)
                        .font(.caption)
                        .foregroundColor(paymentStatusColor)
                }
            }
            
            Spacer()
            
            // Status Badge
            Text("✅ Approved")
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.green.opacity(0.2))
                .foregroundColor(.green)
                .cornerRadius(6)
        }
        .padding(.vertical, 8)
        .sheet(isPresented: $showingUserProfile) {
            UserInfoView(userId: request.userId)
        }
    }
    
    private var paymentStatusIcon: String {
        switch request.paymentStatus {
        case .pending: return "clock.fill"
        case .paid: return "checkmark.circle.fill"
        case .refunded: return "arrow.counterclockwise.circle.fill"
        }
    }
    
    private var paymentStatusColor: Color {
        switch request.paymentStatus {
        case .pending: return .orange
        case .paid: return .green
        case .refunded: return .red
        }
    }
    
    private var paymentStatusText: String {
        switch request.paymentStatus {
        case .pending: return "Payment Pending"
        case .paid: return "✅ PAID - Attending!"
        case .refunded: return "Refunded"
        }
    }
    
    private func formatTimeAgo(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .named
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Preview Support
struct FixedGuestRows_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            FixedPendingGuestRow(
                request: GuestRequest.preview,
                onApprove: { print("Approved") },
                onDeny: { print("Denied") }
            )
            
            FixedApprovedGuestRow(request: GuestRequest.approvedPreview)
        }
        .padding()
        .background(Color.black)
    }
}

// MARK: - Preview Data
extension GuestRequest {
    static var preview: GuestRequest {
        GuestRequest(
            userId: "user123",
            userName: "John Doe",
            userHandle: "johndoe",
            introMessage: "Hey! I'm visiting from NYC and would love to join this party. It looks awesome!",
            paymentStatus: .pending,
            approvalStatus: .pending
        )
    }
    
    static var approvedPreview: GuestRequest {
        GuestRequest(
            userId: "user456",
            userName: "Jane Smith",
            userHandle: "janesmith",
            introMessage: "Excited to attend!",
            paymentStatus: .pending,
            approvalStatus: .approved,
            approvedAt: Date()
        )
    }
} 