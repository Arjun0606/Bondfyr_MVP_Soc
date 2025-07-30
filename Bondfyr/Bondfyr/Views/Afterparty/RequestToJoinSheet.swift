import SwiftUI
import FirebaseFirestore
import FirebaseStorage

struct RequestToJoinSheet: View {
    let afterparty: Afterparty
    let onRequestSubmitted: (() -> Void)?
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject private var authViewModel: AuthViewModel
    @ObservedObject private var afterpartyManager = AfterpartyManager.shared
    @StateObject private var dodoPaymentService = DodoPaymentService.shared
    
    @State private var introMessage = ""
    @State private var isSubmitting = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var requestSubmitted = false
    @State private var refreshTimer: Timer?
    
    // NEW: Image verification for guest requests
    @State private var verificationImage: UIImage?
    @State private var showingImagePicker = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection
                    
                    // Party Info
                    partyInfoSection
                    
                    if !requestSubmitted {
                        // Request Form
                        requestFormSection
                        
                        // Submit Button
                        submitButton
                    } else {
                        // Success State
                        successSection
                    }
                }
                .padding()
            }
            .background(Color.black.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .principal) {
                    Text("Request to Join")
                        .font(.headline)
                        .foregroundColor(.white)
                }
            }
        }
        .preferredColorScheme(.dark)
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(source: .photoLibrary) { image in
                verificationImage = image
            }
        }
        .onAppear {
            checkUserStatus()
            // Start a timer to periodically check if user has been approved (reduced from 2s to 15s)
            refreshTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { _ in
                checkUserStatus()
            }
        }
        .onDisappear {
            refreshTimer?.invalidate()
            refreshTimer = nil
        }
    }
    
    private func checkUserStatus() {
        guard let currentUserId = authViewModel.currentUser?.uid else { return }
        
        Task {
            do {
                // Get the latest party data
                let updatedParty = try await afterpartyManager.getAfterpartyById(afterparty.id)
                
                // Check if user has a request and if it's approved
                if let request = updatedParty.guestRequests.first(where: { $0.userId == currentUserId }) {
                    if request.approvalStatus == .approved {
                        print("🎉 User has been approved! Dismissing sheet...")
                        DispatchQueue.main.async {
                            presentationMode.wrappedValue.dismiss()
                            onRequestSubmitted?()
                        }
                    }
                }
            } catch {
                print("Error checking user status: \(error)")
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.badge.plus")
                .font(.system(size: 50))
                .foregroundColor(.pink)
            
            Text("Join the Party!")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text("Send a request to @\(afterparty.hostHandle) and wait for approval")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(15)
    }
    
    private var partyInfoSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Party Details")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
            }
            
            VStack(spacing: 8) {
                HStack {
                    Text("Event:")
                    Spacer()
                    Text(afterparty.title)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                
                HStack {
                    Text("Host:")
                    Spacer()
                    Text("@\(afterparty.hostHandle)")
                        .fontWeight(.semibold)
                        .foregroundColor(.pink)
                }
                .foregroundColor(.white)
                
                HStack {
                    Text("Price:")
                    Spacer()
                    Text("$\(Int(afterparty.ticketPrice))")
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                }
                .foregroundColor(.white)
                
                HStack {
                    Text("Location:")
                    Spacer()
                    Text("Will be revealed after approval")
                        .italic()
                        .foregroundColor(.orange)
                }
                .foregroundColor(.white)
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(15)
    }
    
    private var requestFormSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Introduce Yourself")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Brief message to the host:")
                    .foregroundColor(.gray)
                
                TextEditor(text: $introMessage)
                    .frame(height: 100)
                    .padding(12)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(12)
                    .foregroundColor(.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                
                Text("Examples: \"Hey! I'm visiting from NYC and would love to join!\", \"Found your party through the app, looks awesome!\"")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.top, 4)
            }
            
            // Image Verification Section (Host Dependent)
            VStack(alignment: .leading, spacing: 8) {
                Text("Verification Photo (Optional)")
                    .foregroundColor(.white)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text("If the host mentions ID requirement in the party description, upload your ID here")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Button(action: { showingImagePicker = true }) {
                    HStack {
                        Image(systemName: verificationImage != nil ? "checkmark.circle.fill" : "camera")
                            .foregroundColor(verificationImage != nil ? .green : .blue)
                        Text(verificationImage != nil ? "Photo Uploaded" : "Add Verification Photo")
                            .foregroundColor(.white)
                        Spacer()
                        if verificationImage != nil {
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                    }
                    .padding()
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                }
            }
            
            // Flow Explanation
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                    Text("What happens next:")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    Spacer()
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    FlowStepView(number: "1", text: "Submit request to join party")
                    FlowStepView(number: "2", text: "Host reviews your request & profile")
                    FlowStepView(number: "3", text: "If approved: pay host directly (Venmo/Zelle)")
                    FlowStepView(number: "4", text: "Upload payment proof to confirm")
                    FlowStepView(number: "5", text: "Get party details & join the fun! 🎉")
                }
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(12)
        }
    }
    
    private var submitButton: some View {
        Button(action: submitRequest) {
            HStack {
                if isSubmitting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Image(systemName: "paperplane.fill")
                    Text("Send Request")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                introMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 
                LinearGradient(gradient: Gradient(colors: [.gray, .gray]), startPoint: .leading, endPoint: .trailing) : 
                LinearGradient(gradient: Gradient(colors: [.pink, .purple]), startPoint: .leading, endPoint: .trailing)
            )
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(isSubmitting || introMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }
    
    private var successSection: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
            
            Text("Request Submitted!")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text("Your request has been sent to @\(afterparty.hostHandle) for approval")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            
            VStack(spacing: 12) {
                Text("What happens next:")
                    .font(.subheadline)
                    .foregroundColor(.white)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "bell.fill")
                            .foregroundColor(.orange)
                        Text("Host reviews your request")
                        Spacer()
                    }
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("If approved, you'll pay via Dodo")
                        Spacer()
                    }
                    HStack {
                        Image(systemName: "location.fill")
                            .foregroundColor(.blue)
                        Text("Party address will be revealed")
                        Spacer()
                    }
                }
                .foregroundColor(.gray)
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)
            
            Button("Done") {
                presentationMode.wrappedValue.dismiss()
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.green)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
    }
    
    private func submitRequest() {
        guard let currentUser = authViewModel.currentUser else { 
            print("🔴 REQUEST: submitRequest() FAILED - no current user")
            return 
        }
        
        print("🟡 REQUEST: submitRequest() called for party \(afterparty.id)")
        print("🟡 REQUEST: Current user: \(currentUser.name) (\(currentUser.uid))")
        print("🟡 REQUEST: Intro message: '\(introMessage.trimmingCharacters(in: .whitespacesAndNewlines))'")
        print("🟡 REQUEST: Verification image selected: \(verificationImage != nil)")
        
        isSubmitting = true
        
        Task {
            do {
                var verificationImageURL: String? = nil
                
                // NEW: Upload verification image if one was selected
                if let image = verificationImage {
                    print("🔄 REQUEST: Uploading verification image...")
                    verificationImageURL = try await uploadVerificationImage(image: image, userId: currentUser.uid)
                    print("✅ REQUEST: Verification image uploaded successfully: \(verificationImageURL ?? "nil")")
                } else {
                    print("ℹ️ REQUEST: No verification image selected")
                }
                
                // NEW FLOW: Create guest request WITHOUT payment processing
                let guestRequest = GuestRequest(
                    userId: currentUser.uid,
                    userName: currentUser.name,
                    userHandle: currentUser.username ?? currentUser.name,
                    introMessage: introMessage.trimmingCharacters(in: .whitespacesAndNewlines),
                    paymentStatus: .pending, // Will process payment AFTER approval
                    verificationImageURL: verificationImageURL // Pass the uploaded image URL
                )
                
                print("🟡 REQUEST: Created GuestRequest with ID: \(guestRequest.id)")
                print("🟡 REQUEST: Verification URL: \(guestRequest.verificationImageURL ?? "nil")")
                print("🟡 REQUEST: Calling afterpartyManager.submitGuestRequest()...")
                
                // Submit request to Firestore (NO PAYMENT YET)
                try await afterpartyManager.submitGuestRequest(
                    afterpartyId: afterparty.id,
                    guestRequest: guestRequest
                )
                
                print("🟢 REQUEST: submitGuestRequest() SUCCESS - request submitted to Firebase")
                
                await MainActor.run {
                    requestSubmitted = true
                    isSubmitting = false
                    print("🟢 REQUEST: UI updated to show success state")
                    onRequestSubmitted?() // Notify parent that request was submitted
                }
                
            } catch {
                print("🔴 REQUEST: Error submitting request: \(error)")
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showingError = true
                    isSubmitting = false
                }
            }
        }
    }
}

// NEW: Function to upload verification image to Firebase Storage
private func uploadVerificationImage(image: UIImage, userId: String) async throws -> String {
    guard let imageData = image.jpegData(compressionQuality: 0.8) else {
        throw NSError(domain: "ImageUploadError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to data"])
    }
    
    // Create Firebase Storage reference
    let storage = Storage.storage()
    let filename = "verification_\(userId)_\(UUID().uuidString).jpg"
    let storageRef = storage.reference().child("guest_verification/\(filename)")
    
    print("🔄 UPLOAD: Uploading verification image to: \(filename)")
    
    // Upload the image
    let metadata = StorageMetadata()
    metadata.contentType = "image/jpeg"
    
    let _ = try await storageRef.putDataAsync(imageData, metadata: metadata)
    print("✅ UPLOAD: Image uploaded successfully")
    
    // Get download URL
    let downloadURL = try await storageRef.downloadURL()
    print("✅ UPLOAD: Download URL obtained: \(downloadURL.absoluteString)")
    
    return downloadURL.absoluteString
}

struct FlowStepView: View {
    let number: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Text(number)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(Color.blue)
                .clipShape(Circle())
            
            Text(text)
                .font(.caption)
                .foregroundColor(.gray)
            
            Spacer()
        }
    }
} 