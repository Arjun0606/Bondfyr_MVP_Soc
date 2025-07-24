import SwiftUI
import FirebaseStorage

struct P2PPaymentSheet: View {
    let afterparty: Afterparty
    let onPaymentComplete: () -> Void
    
    @Environment(\.presentationMode) var presentationMode
    @State private var isConfirming = false
    @State private var showingConfirmation = false
    @State private var paymentProof: UIImage?
    @State private var showingImagePicker = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    amountSection
                    contactInfoSection
                    instructionsSection
                    proofUploadSection
                    confirmButtonSection
                }
                .padding()
            }
            .navigationTitle("Pay Host")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(source: .photoLibrary) { image in
                paymentProof = image
            }
        }
        .alert("Payment Proof Submitted", isPresented: $showingConfirmation) {
            Button("OK") {
                presentationMode.wrappedValue.dismiss()
                onPaymentComplete()
            }
        } message: {
            Text("Your payment proof has been submitted! The host will verify payment and confirm your attendance.")
        }
    }
    
    private func confirmPayment() {
        guard let paymentProofImage = paymentProof else {
            // This shouldn't happen since button is disabled, but safety check
            return
        }
        
        isConfirming = true
        
        Task {
            do {
                // 1. Upload payment proof image to Firebase Storage
                let paymentProofURL = try await uploadPaymentProof(image: paymentProofImage)
                
                // 2. Update guest request with proof submission
                try await AfterpartyManager.shared.submitPaymentProof(
                    afterpartyId: afterparty.id,
                    paymentProofURL: paymentProofURL
                )
                
                await MainActor.run {
                    isConfirming = false
                    showingConfirmation = true
                }
                
            } catch {
                await MainActor.run {
                    isConfirming = false
                    // Show error alert
                    print("🔴 PAYMENT PROOF: Error submitting proof: \(error)")
                }
            }
        }
    }
    
    private func uploadPaymentProof(image: UIImage) async throws -> String {
        // Convert image to data
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw NSError(domain: "ImageError", code: 400, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to data"])
        }
        
        // Create unique filename
        let filename = "payment_proof_\(UUID().uuidString).jpg"
        let storageRef = Storage.storage().reference().child("payment_proofs/\(filename)")
        
        // Upload to Firebase Storage
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        _ = try await storageRef.putDataAsync(imageData, metadata: metadata)
        let downloadURL = try await storageRef.downloadURL()
        
        print("🟢 PAYMENT PROOF: Uploaded to \(downloadURL.absoluteString)")
        return downloadURL.absoluteString
    }
    
    // MARK: - View Components
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "creditcard.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
            
            Text("Pay Host Directly")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Send payment directly to the host")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .padding(.top)
    }
    
    private var amountSection: some View {
        VStack(spacing: 8) {
            Text("Amount to Pay")
                .font(.headline)
                .foregroundColor(.gray)
            
            Text("$\(String(format: "%.0f", afterparty.ticketPrice))")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.green)
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.1))
        .cornerRadius(12)
    }
    
    private var contactInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Host Contact Info")
                .font(.headline)
                .fontWeight(.bold)
            
            if let phoneNumber = afterparty.phoneNumber {
                ContactInfoRow(
                    icon: "phone.fill",
                    label: "Phone",
                    value: phoneNumber,
                    copyable: true
                )
            }
            
            if let instagram = afterparty.instagramHandle, !instagram.isEmpty {
                ContactInfoRow(
                    icon: "camera.fill",
                    label: "Instagram",
                    value: instagram,
                    copyable: true
                )
            }
            
            if let snapchat = afterparty.snapchatHandle, !snapchat.isEmpty {
                ContactInfoRow(
                    icon: "message.fill",
                    label: "Snapchat",
                    value: snapchat,
                    copyable: true
                )
            }
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.1))
        .cornerRadius(12)
    }
    
    private var instructionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Payment Instructions")
                .font(.headline)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 12) {
                PaymentStep(
                    number: "1",
                    title: "Contact the Host",
                    description: "Use phone or social media to reach the host"
                )
                
                PaymentStep(
                    number: "2",
                    title: "Send Payment",
                    description: "Pay $\(String(format: "%.0f", afterparty.ticketPrice)) via Venmo, Zelle, or Cash App"
                )
                
                PaymentStep(
                    number: "3",
                    title: "Take Screenshot",
                    description: "Screenshot your payment confirmation"
                )
                
                PaymentStep(
                    number: "4",
                    title: "Upload Proof",
                    description: "Upload screenshot below to confirm payment"
                )
            }
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.1))
        .cornerRadius(12)
    }
    
    private var proofUploadSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Upload Payment Proof")
                .font(.headline)
                .fontWeight(.bold)
            
            Button(action: { showingImagePicker = true }) {
                HStack {
                    Image(systemName: paymentProof != nil ? "checkmark.circle.fill" : "camera")
                        .foregroundColor(paymentProof != nil ? .green : .blue)
                    Text(paymentProof != nil ? "Payment Proof Uploaded" : "Upload Payment Screenshot")
                    Spacer()
                    if paymentProof != nil {
                        Image(systemName: "chevron.right")
                            .foregroundColor(.gray)
                    }
                }
                .padding()
                .background(Color(.systemGray6).opacity(0.1))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(paymentProof != nil ? Color.green : Color.gray.opacity(0.3), lineWidth: 1)
                )
            }
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.05))
        .cornerRadius(12)
    }
    
    private var confirmButtonSection: some View {
        Button(action: confirmPayment) {
            HStack {
                if isConfirming {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                    Text("Confirming...")
                } else {
                    Text("Confirm Payment Sent")
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                paymentProof != nil ?
                    AnyView(LinearGradient(gradient: Gradient(colors: [.green, .blue]), startPoint: .leading, endPoint: .trailing)) :
                    AnyView(Color.gray)
            )
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(paymentProof == nil || isConfirming)
    }
}

// MARK: - Supporting Views

struct ContactInfoRow: View {
    let icon: String
    let label: String
    let value: String
    let copyable: Bool
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.gray)
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            Spacer()
            
            if copyable {
                Button(action: {
                    UIPasteboard.general.string = value
                }) {
                    Image(systemName: "doc.on.doc")
                        .foregroundColor(.blue)
                }
            }
        }
    }
}

struct PaymentStep: View {
    let number: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 24, height: 24)
                
                Text(number)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
        }
    }
} 