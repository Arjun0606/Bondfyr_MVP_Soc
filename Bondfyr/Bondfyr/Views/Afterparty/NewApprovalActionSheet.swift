import SwiftUI

/// SIMPLE APPROVAL ACTION SHEET - 3 clear options for hosts
struct NewApprovalActionSheet: View {
    let request: GuestRequest
    let onApproveWithPayment: () -> Void
    let onApproveWithoutPayment: () -> Void
    let onDeny: () -> Void
    let onDismiss: () -> Void
    
    @State private var isProcessing = false
    @State private var showingIDPhoto = false
    
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
                
                // Guest message
                if !request.introMessage.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Message:")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Text("\"\(request.introMessage)\"")
                            .font(.body)
                            .italic()
                            .padding(12)
                            .background(.blue.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
                
                // ID verification indicator - FIXED
                if let idURL = request.verificationImageURL, !idURL.isEmpty {
                    HStack {
                        Image(systemName: "doc.text.image.fill")
                            .foregroundColor(.green)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("ID Verification Uploaded")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("Tap to view ID photo")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        
                        Button(action: {
                            showingIDPhoto = true
                        }) {
                            Image(systemName: "eye.fill")
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(12)
                    .background(.green.opacity(0.1))
                    .cornerRadius(8)
                    .onTapGesture {
                        showingIDPhoto = true
                    }
                } else {
                    // Debug: Show when NO ID is uploaded
                    HStack {
                        Image(systemName: "doc.text")
                            .foregroundColor(.gray)
                        Text("No ID verification uploaded")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(12)
                    .background(.gray.opacity(0.1))
                    .cornerRadius(8)
                }
                
                // Approval options
                VStack(spacing: 16) {
                    Text("Choose an action:")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    // Option 1: Approve with Payment
                    actionButton(
                        title: "Approve with Payment",
                        subtitle: "Guest must pay to attend",
                        icon: "creditcard.fill",
                        color: .green,
                        action: {
                            handleAction(onApproveWithPayment)
                        }
                    )
                    
                                    // Option 2: VIP Approval
                actionButton(
                    title: "Approve as VIP",
                    subtitle: "Free entry • Perfect for special guests",
                    icon: "star.fill",
                    color: .purple,
                    action: {
                        handleAction(onApproveWithoutPayment)
                    }
                )
                    
                    // Option 3: Deny
                    actionButton(
                        title: "Deny Request",
                        subtitle: "Guest cannot attend this party",
                        icon: "xmark.circle.fill",
                        color: .red,
                        action: {
                            handleAction(onDeny)
                        }
                    )
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Guest Request")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                trailing: Button("Cancel") {
                    onDismiss()
                }
            )
            .sheet(isPresented: $showingIDPhoto) {
                if let idURL = request.verificationImageURL {
                    NavigationView {
                        VStack {
                            Text("ID Verification")
                                .font(.title2)
                                .fontWeight(.bold)
                                .padding()
                            
                            AsyncImage(url: URL(string: idURL)) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .cornerRadius(12)
                                case .failure:
                                    Text("Failed to load ID")
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
                                showingIDPhoto = false
                            }
                        )
                    }
                }
            }
        }
        .disabled(isProcessing)
    }
    
    private func actionButton(
        title: String,
        subtitle: String,
        icon: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(color)
                    .cornerRadius(10)
                
                // Text
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                // Loading or chevron
                if isProcessing {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
            }
            .padding(16)
            .background(.ultraThinMaterial)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(color.opacity(0.3), lineWidth: 2)
            )
        }
        .disabled(isProcessing)
        .buttonStyle(PlainButtonStyle())
    }
    
    private func handleAction(_ action: @escaping () -> Void) {
        print("🎯 NEW ACTION SHEET: Processing action for \(request.userHandle)")
        isProcessing = true
        
        // Small delay to show processing state
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            action()
        }
    }
}

// MARK: - Preview
struct NewApprovalActionSheet_Previews: PreviewProvider {
    static var previews: some View {
        NewApprovalActionSheet(
            request: GuestRequest(
                id: "test",
                userId: "user1",
                userName: "Test User",
                userHandle: "testuser",
                introMessage: "Hey! Would love to join your party, looks amazing!",
                requestedAt: Date(),
                paymentStatus: .pending,
                approvalStatus: .pending,
                paypalOrderId: nil,
                paymentProofImageURL: nil,
                proofSubmittedAt: nil,
                verificationImageURL: "test-url"
            ),
            onApproveWithPayment: { print("Approved with payment") },
            onApproveWithoutPayment: { print("Approved VIP") },
            onDeny: { print("Denied") },
            onDismiss: { print("Dismissed") }
        )
    }
} 
