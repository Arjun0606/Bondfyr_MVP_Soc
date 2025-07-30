import SwiftUI

// MARK: - Fixed Guest Row Components
struct FixedPendingGuestRow: View {
    let request: GuestRequest
    let partyId: String
    let onApprove: () -> Void
    let onDeny: () -> Void
    
    @State private var showingUserProfile = false
    @State private var showingApprovalSheet = false
    @State private var showingFullMessage = false
    @State private var showingPaymentVerification = false
    
    @ObservedObject private var afterpartyManager = AfterpartyManager.shared
    
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
            
            // NEW: Single Review Button that opens proper approval sheet
            Button(action: {
                print("🎯 REVIEW: Opening new approval sheet for \(request.userHandle)")
                showingApprovalSheet = true
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "person.badge.plus")
                    Text("Review Request")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .buttonStyle(BorderlessButtonStyle())
        }
        .padding(.vertical, 8)
        .sheet(isPresented: $showingUserProfile) {
            UserInfoView(userId: request.userId)
        }
        .sheet(isPresented: $showingApprovalSheet) {
            NewApprovalActionSheet(
                request: request,
                onApproveWithPayment: {
                    showingApprovalSheet = false
                    onApprove()
                },
                onApproveWithoutPayment: {
                    showingApprovalSheet = false
                    handleVIPApproval()
                },
                onDeny: {
                    showingApprovalSheet = false
                    onDeny()
                },
                onDismiss: {
                    showingApprovalSheet = false
                }
            )
        }
        .sheet(isPresented: $showingPaymentVerification) {
            PaymentVerificationSheet(
                request: request,
                partyId: partyId,
                onVerify: {
                    showingPaymentVerification = false
                    handleVerifyPayment()
                },
                onReject: {
                    showingPaymentVerification = false
                    handleRejectPayment()
                },
                onDismiss: {
                    showingPaymentVerification = false
                }
            )
        }
    }
    
    private func formatTimeAgo(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .named
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    private func handleVIPApproval() {
        print("🌟 VIP APPROVAL: Starting VIP approval for \(request.userHandle)")
        
        Task {
            do {
                try await afterpartyManager.approveGuestRequestFree(
                    afterpartyId: partyId,
                    guestRequestId: request.id
                )
                print("✅ VIP APPROVAL: Successfully approved \(request.userHandle) as VIP")
            } catch {
                print("🔴 VIP APPROVAL: Error approving \(request.userHandle) as VIP: \(error)")
            }
        }
    }
    
    private func handleVerifyPayment() {
        print("✅ SAFE VERIFY: Verifying payment proof for \(request.userHandle)")
        
        Task {
            do {
                try await afterpartyManager.verifyPaymentProof(
                    afterpartyId: partyId,
                    guestRequestId: request.id,
                    approved: true
                )
                print("✅ SAFE VERIFY: Payment verified for \(request.userHandle)")
            } catch {
                print("🔴 SAFE VERIFY: Error verifying payment: \(error)")
            }
        }
    }
    
    private func handleRejectPayment() {
        print("❌ SAFE REJECT: Rejecting payment proof for \(request.userHandle)")
        
        Task {
            do {
                try await afterpartyManager.verifyPaymentProof(
                    afterpartyId: partyId,
                    guestRequestId: request.id,
                    approved: false
                )
                print("❌ SAFE REJECT: Payment rejected for \(request.userHandle)")
            } catch {
                print("🔴 SAFE REJECT: Error rejecting payment: \(error)")
            }
        }
    }
}

// MARK: - Fixed Approved Guest Row
struct FixedApprovedGuestRow: View {
    let request: GuestRequest
    let onVerifyPayment: (() -> Void)?
    let onRejectPayment: (() -> Void)?
    @State private var showingUserProfile = false
    @State private var showingPaymentProof = false
    @State private var showingPaymentVerification = false
    
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
                
                // Payment Verification Section (NEW)
                if request.paymentStatus == .proofSubmitted {
                    VStack(alignment: .leading, spacing: 4) {
                        if let proofURL = request.paymentProofImageURL, !proofURL.isEmpty {
                            Button(action: { 
                                showingPaymentProof = true
                            }) {
                                HStack {
                                    Image(systemName: "photo")
                                    Text("View Payment Screenshot")
                                }
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(8)
                            }
                        }
                    }
                    .padding(.top, 4)
                }
            }
            
            Spacer()
            
            // Action Buttons or Status Badge
            if request.paymentStatus == .proofSubmitted {
                // NEW: Single Review Payment Button (no more simultaneous actions!)
                Button(action: {
                    print("🎯 PAYMENT REVIEW: Opening payment verification for \(request.userHandle)")
                    showingPaymentVerification = true
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: "creditcard.and.123")
                            .font(.title3)
                        Text("Review Payment")
                            .font(.caption2)
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(width: 70, height: 50)
                    .background(.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(BorderlessButtonStyle())
            } else {
                // Regular Status Badge
                Text("✅ Approved")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.2))
                    .foregroundColor(.green)
                    .cornerRadius(6)
            }
        }
        .padding(.vertical, 8)
        .sheet(isPresented: $showingUserProfile) {
            UserInfoView(userId: request.userId)
        }
        .sheet(isPresented: $showingPaymentProof) {
            if let proofURL = request.paymentProofImageURL {
                NavigationView {
                    VStack {
                        Text("Payment Proof")
                            .font(.title2)
                            .fontWeight(.bold)
                            .padding()
                        
                        AsyncImage(url: URL(string: proofURL)) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .cornerRadius(12)
                            case .failure:
                                Text("Failed to load image")
                                    .foregroundColor(.red)
                            case .empty:
                                ProgressView()
                                    .frame(height: 200)
                            @unknown default:
                                EmptyView()
                            }
                        }
                        .padding()
                        
                        Spacer()
                    }
                    .navigationBarItems(
                        trailing: Button("Done") {
                            showingPaymentProof = false
                        }
                    )
                }
            }
        }
        .sheet(isPresented: $showingPaymentVerification) {
            PaymentVerificationSheet(
                request: request,
                partyId: "",  // Will need to pass this properly
                onVerify: {
                    showingPaymentVerification = false
                    onVerifyPayment?()
                },
                onReject: {
                    showingPaymentVerification = false
                    onRejectPayment?()
                },
                onDismiss: {
                    showingPaymentVerification = false
                }
            )
        }
    }
    
    private var paymentStatusIcon: String {
        switch request.paymentStatus {
        case .pending: return "clock.fill"
        case .proofSubmitted: return "hourglass.tophalf.filled"
        case .paid: return "checkmark.circle.fill"
        case .free: return "star.fill"
        case .refunded: return "arrow.counterclockwise.circle.fill"
        }
    }
    
    private var paymentStatusColor: Color {
        switch request.paymentStatus {
        case .pending: return .orange
        case .proofSubmitted: return .yellow
        case .paid: return .green
        case .free: return .purple
        case .refunded: return .red
        }
    }
    
    private var paymentStatusText: String {
        switch request.paymentStatus {
        case .pending: return "Payment Pending"
        case .proofSubmitted: return "⏳ Payment Proof Submitted"
        case .paid: return "✅ PAID - Attending!"
        case .free: return "⭐ VIP - Free Entry!"
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
                partyId: "sample-party-id",
                onApprove: { print("Approved") },
                onDeny: { print("Denied") }
            )
            
            FixedApprovedGuestRow(
                request: GuestRequest.preview,
                onVerifyPayment: { print("Verified") },
                onRejectPayment: { print("Rejected") }
            )
        }
        .padding()
        .background(Color.black)
    }
}

// MARK: - GuestRequest Preview Data
extension GuestRequest {
    static var preview: GuestRequest {
        GuestRequest(
            id: "preview-id",
            userId: "user-123",
            userName: "Jane Doe",
            userHandle: "janedoe",
            introMessage: "Hi! Would love to join your party!",
            requestedAt: Date(),
            paymentStatus: .pending,
            approvalStatus: .pending,
            paypalOrderId: nil,
            paidAt: nil,
            approvedAt: nil,
            paymentProofImageURL: nil,
            proofSubmittedAt: nil,
            verificationImageURL: "example-url"
        )
    }
} 