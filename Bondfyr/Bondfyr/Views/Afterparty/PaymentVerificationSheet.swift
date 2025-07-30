import SwiftUI

/// SAFE PAYMENT VERIFICATION SHEET - Prevents simultaneous actions
struct PaymentVerificationSheet: View {
    let request: GuestRequest
    let partyId: String
    let onVerify: () -> Void
    let onReject: () -> Void
    let onDismiss: () -> Void
    
    @State private var isProcessing = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Guest info header
                VStack(spacing: 12) {
                    Circle()
                        .fill(.blue.gradient)
                        .frame(width: 80, height: 80)
                        .overlay(
                            Text(String(request.userHandle.prefix(1)).uppercased())
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        )
                    
                    Text("@\(request.userHandle)")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(request.userName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // Payment proof section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Payment Proof Submitted:")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    if let proofURL = request.paymentProofImageURL, !proofURL.isEmpty {
                        AsyncImage(url: URL(string: proofURL)) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxHeight: 300)
                                    .cornerRadius(12)
                                    .shadow(radius: 4)
                            case .failure:
                                Rectangle()
                                    .fill(.red.opacity(0.2))
                                    .frame(height: 200)
                                    .cornerRadius(12)
                                    .overlay(
                                        VStack {
                                            Image(systemName: "exclamationmark.triangle")
                                                .font(.title)
                                                .foregroundColor(.red)
                                            Text("Failed to load image")
                                                .font(.caption)
                                                .foregroundColor(.red)
                                        }
                                    )
                            case .empty:
                                Rectangle()
                                    .fill(.gray.opacity(0.2))
                                    .frame(height: 200)
                                    .cornerRadius(12)
                                    .overlay(
                                        ProgressView()
                                            .scaleEffect(1.5)
                                    )
                            @unknown default:
                                EmptyView()
                            }
                        }
                    } else {
                        Rectangle()
                            .fill(.gray.opacity(0.2))
                            .frame(height: 200)
                            .cornerRadius(12)
                            .overlay(
                                Text("No payment proof found")
                                    .foregroundColor(.secondary)
                            )
                    }
                    
                    if let submittedAt = request.proofSubmittedAt {
                        Text("Submitted: \(submittedAt, style: .relative) ago")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Verification actions - SAFE: Only one can be pressed at a time
                if !isProcessing {
                    VStack(spacing: 16) {
                        Text("Does this payment proof look legitimate?")
                            .font(.headline)
                            .multilineTextAlignment(.center)
                        
                        HStack(spacing: 20) {
                            // Reject Button
                            Button(action: handleReject) {
                                VStack(spacing: 8) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(.white)
                                    
                                    Text("Reject")
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.red)
                                .cornerRadius(12)
                            }
                            
                            // Verify Button
                            Button(action: handleVerify) {
                                VStack(spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(.white)
                                    
                                    Text("Verify")
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.green)
                                .cornerRadius(12)
                            }
                        }
                    }
                } else {
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.2)
                        
                        Text("Processing...")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 32)
                }
            }
            .padding()
            .navigationTitle("Payment Verification")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    if !isProcessing {
                        onDismiss()
                    }
                }
                .disabled(isProcessing)
            )
        }
    }
    
    private func handleVerify() {
        print("🟢 SAFE SHEET: User tapped VERIFY button")
        guard !isProcessing else {
            print("🚨 SAFE SHEET: Already processing - ignoring tap")
            return
        }
        
        isProcessing = true
        
        // Small delay to show processing state, then execute
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onVerify()
        }
    }
    
    private func handleReject() {
        print("🔴 SAFE SHEET: User tapped REJECT button")
        guard !isProcessing else {
            print("🚨 SAFE SHEET: Already processing - ignoring tap")
            return
        }
        
        isProcessing = true
        
        // Small delay to show processing state, then execute
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onReject()
        }
    }
}

// MARK: - Preview
struct PaymentVerificationSheet_Previews: PreviewProvider {
    static var previews: some View {
        PaymentVerificationSheet(
            request: GuestRequest(
                id: "test",
                userId: "user1",
                userName: "Test User",
                userHandle: "testuser",
                introMessage: "Payment proof for party!",
                requestedAt: Date(),
                paymentStatus: .proofSubmitted,
                approvalStatus: .approved,
                paypalOrderId: nil,
                paymentProofImageURL: "https://example.com/proof.jpg",
                proofSubmittedAt: Date(),
                verificationImageURL: nil
            ),
            partyId: "test-party",
            onVerify: { print("Verified") },
            onReject: { print("Rejected") },
            onDismiss: { print("Dismissed") }
        )
    }
} 