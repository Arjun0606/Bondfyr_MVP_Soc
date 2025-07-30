import SwiftUI

struct NewPaymentVerificationSheet: View {
    let request: GuestRequest
    let onVerifyPayment: () -> Void
    let onRejectPayment: () -> Void
    let onDismiss: () -> Void
    
    @State private var isProcessing = false
    @State private var hasImageLoaded = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    guestInfoSection
                    paymentProofSection
                    verificationActionsSection
                    Spacer(minLength: 50)
                }
                .padding()
            }
            .navigationTitle("Payment Verification")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Close") {
                    print("🖼️ VERIFICATION SHEET: Close button tapped")
                    onDismiss()
                }
            )
        }
        .disabled(isProcessing)
    }
    
    // MARK: - View Components
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "creditcard.and.123")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("Payment Verification")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Review the payment proof submitted by the guest")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var guestInfoSection: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(request.userHandle)
                        .font(.title3)
                        .fontWeight(.bold)
                    
                    Text(request.userName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if let submittedAt = request.proofSubmittedAt {
                        Text("Submitted \(timeAgoString(from: submittedAt))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "hourglass.circle.fill")
                    .font(.title2)
                    .foregroundColor(.orange)
            }
            .padding()
            .background(Color.orange.opacity(0.1))
            .cornerRadius(12)
        }
    }
    
    private var paymentProofSection: some View {
        VStack(spacing: 16) {
            Text("Payment Proof")
                .font(.headline)
            
            if let proofURL = request.paymentProofImageURL, !proofURL.isEmpty {
                paymentImageView(url: proofURL)
            } else {
                // This should never happen, but just in case
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 40))
                        .foregroundColor(.red)
                    
                    Text("No payment proof image found")
                        .font(.subheadline)
                        .foregroundColor(.red)
                }
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(12)
            }
        }
    }
    
    private func paymentImageView(url: String) -> some View {
        VStack(spacing: 12) {
            AsyncImage(url: URL(string: url)) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 400)
                        .cornerRadius(12)
                        .onAppear {
                            hasImageLoaded = true
                            print("🖼️ VERIFICATION: ✅ Payment proof image loaded successfully")
                        }
                        
                case .failure(let error):
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.red)
                        
                        Text("Failed to load image")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        Text(error.localizedDescription)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(12)
                    .onAppear {
                        print("🖼️ VERIFICATION: ❌ Failed to load payment proof: \(error)")
                    }
                    
                case .empty:
                    VStack(spacing: 12) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                        
                        Text("Loading payment proof...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                    .onAppear {
                        print("🖼️ VERIFICATION: 🔄 Loading payment proof image...")
                    }
                    
                @unknown default:
                    EmptyView()
                }
            }
            
            Text("Payment proof submitted by @\(request.userHandle)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var verificationActionsSection: some View {
        VStack(spacing: 16) {
            Text("Verify Payment")
                .font(.headline)
                .padding(.top)
            
            Text("Does this payment proof look legitimate?")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            HStack(spacing: 16) {
                // Reject Button
                Button(action: {
                    handleRejectPayment()
                }) {
                    VStack(spacing: 8) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.white)
                        
                        Text("Reject")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        
                        Text("Invalid proof")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(isProcessing ? Color.gray : Color.red)
                    .cornerRadius(16)
                }
                .disabled(isProcessing)
                
                // Verify Button
                Button(action: {
                    handleVerifyPayment()
                }) {
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.white)
                        
                        Text("Verify")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        
                        Text("Approve guest")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(isProcessing ? Color.gray : Color.green)
                    .cornerRadius(16)
                }
                .disabled(isProcessing)
            }
            
            if isProcessing {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Processing...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top)
            }
        }
    }
    
    // MARK: - Actions
    
    private func handleVerifyPayment() {
        print("🟢 VERIFY ACTION: User tapped VERIFY button")
        print("🟢 VERIFY ACTION: Processing payment verification for \(request.userHandle)")
        
        guard !isProcessing else {
            print("🚨 VERIFY ACTION: Already processing - ignoring tap")
            return
        }
        
        isProcessing = true
        
        // Add a small delay to show the processing state
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            onVerifyPayment()
        }
    }
    
    private func handleRejectPayment() {
        print("🔴 REJECT ACTION: User tapped REJECT button")
        print("🔴 REJECT ACTION: Processing payment rejection for \(request.userHandle)")
        
        guard !isProcessing else {
            print("🚨 REJECT ACTION: Already processing - ignoring tap")
            return
        }
        
        isProcessing = true
        
        // Add a small delay to show the processing state
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            onRejectPayment()
        }
    }
    
    private func timeAgoString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Preview
struct NewPaymentVerificationSheet_Previews: PreviewProvider {
    static var previews: some View {
        NewPaymentVerificationSheet(
            request: GuestRequest(
                id: "test",
                userId: "user1",
                userName: "Test User",
                userHandle: "testuser",
                introMessage: "Payment sent!",
                requestedAt: Date(),
                paymentStatus: .proofSubmitted,
                approvalStatus: .approved,
                paypalOrderId: nil,
                paymentProofImageURL: "https://example.com/payment-proof.jpg",
                proofSubmittedAt: Date(),
                verificationImageURL: nil
            ),
            onVerifyPayment: {
                print("Preview: Verify tapped")
            },
            onRejectPayment: {
                print("Preview: Reject tapped")
            },
            onDismiss: {
                print("Preview: Dismiss tapped")
            }
        )
    }
} 