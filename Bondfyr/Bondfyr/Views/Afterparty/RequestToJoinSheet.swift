import SwiftUI
import FirebaseFirestore

struct RequestToJoinSheet: View {
    let afterparty: Afterparty
    let onRequestSubmitted: (() -> Void)?
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject private var authViewModel: AuthViewModel
    @StateObject private var afterpartyManager = AfterpartyManager.shared
    
    @State private var introMessage = ""
    @State private var isSubmitting = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var requestSubmitted = false
    
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
                    FlowStepView(number: "1", text: "Your request goes to the host")
                    FlowStepView(number: "2", text: "Host reviews and approves/denies")
                    FlowStepView(number: "3", text: "If approved: address & Venmo details revealed")
                    FlowStepView(number: "4", text: "Send payment via Venmo to secure spot")
                    FlowStepView(number: "5", text: "Show up and party! 🎉")
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
            
            Text("Request Sent!")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text("Your request has been sent to @\(afterparty.hostHandle)")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            
            VStack(spacing: 12) {
                Text("You'll be notified when:")
                    .font(.subheadline)
                    .foregroundColor(.white)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "bell.fill")
                            .foregroundColor(.green)
                        Text("Host approves your request")
                        Spacer()
                    }
                    HStack {
                        Image(systemName: "location.fill")
                            .foregroundColor(.blue)
                        Text("Address & payment details are revealed")
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
        guard let currentUser = authViewModel.currentUser else { return }
        
        isSubmitting = true
        
        Task {
            do {
                let guestRequest = GuestRequest(
                    userId: currentUser.uid,
                    userName: currentUser.name,
                    userHandle: currentUser.username ?? currentUser.name,
                    introMessage: introMessage.trimmingCharacters(in: .whitespacesAndNewlines),
                    paymentStatus: .pending
                )
                
                // Add request to Firestore
                try await afterpartyManager.submitGuestRequest(
                    afterpartyId: afterparty.id,
                    guestRequest: guestRequest
                )
                
                await MainActor.run {
                    requestSubmitted = true
                    isSubmitting = false
                    onRequestSubmitted?() // Notify parent that request was submitted
                }
                
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showingError = true
                    isSubmitting = false
                }
            }
        }
    }
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