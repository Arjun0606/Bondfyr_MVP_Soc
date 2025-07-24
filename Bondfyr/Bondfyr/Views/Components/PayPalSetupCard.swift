import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct PayPalSetupCard: View {
    @Binding var isCompleted: Bool
    @State private var paypalEmail = ""
    @State private var confirmEmail = ""
    @State private var isLoading = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    private var isValid: Bool {
        !paypalEmail.isEmpty && 
        paypalEmail == confirmEmail && 
        paypalEmail.contains("@") && 
        paypalEmail.contains(".")
    }
    
    var body: some View {
        VStack(spacing: 20) {
            headerSection
            
            if !isCompleted {
                formSection
                setupButton
            } else {
                completedSection
            }
            
            infoSection
        }
        .padding()
        .background(Color.black.opacity(0.3))
        .cornerRadius(16)
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - Header
    private var headerSection: some View {
        HStack {
            Image(systemName: "p.circle.fill")
                .font(.title)
                .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("PayPal Payouts")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text(isCompleted ? "✅ Ready to receive earnings" : "Setup required to get paid")
                    .font(.caption)
                    .foregroundColor(isCompleted ? .green : .orange)
            }
            
            Spacer()
            
            if isCompleted {
                Button("Edit") {
                    isCompleted = false
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
        }
    }
    
    // MARK: - Form Section
    private var formSection: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("PayPal Email")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                
                TextField("john@example.com", text: $paypalEmail)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .padding()
                    .background(Color.black.opacity(0.2))
                    .cornerRadius(8)
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Confirm Email")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                
                TextField("john@example.com", text: $confirmEmail)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .padding()
                    .background(Color.black.opacity(0.2))
                    .cornerRadius(8)
                    .foregroundColor(.white)
            }
        }
    }
    
    // MARK: - Setup Button
    private var setupButton: some View {
        Button(action: setupPayPal) {
            HStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                }
                Text(isLoading ? "Setting up..." : "Setup PayPal")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(isValid ? Color.blue : Color.gray)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(!isValid || isLoading)
    }
    
    // MARK: - Completed Section
    private var completedSection: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("PayPal Connected")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                
                Text(paypalEmail.isEmpty ? "••••@••••.com" : maskEmail(paypalEmail))
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Text("80% of earnings")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.green)
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(8)
    }
    
    // MARK: - Info Section
    private var infoSection: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(.blue)
                Text("How PayPal payouts work")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                PayPalInfoRow(icon: "dollarsign.circle", text: "You earn 80% of every ticket sale")
                PayPalInfoRow(icon: "calendar", text: "Payouts every Friday at 6 PM")
                PayPalInfoRow(icon: "clock", text: "Money arrives instantly in PayPal")
                PayPalInfoRow(icon: "shield", text: "Secure & encrypted connection")
            }
        }
    }
    
    // MARK: - Actions
    private func setupPayPal() {
        Task {
            await savePayPalInfo()
        }
    }
    
    private func savePayPalInfo() async {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            // MVP: PayPal setup disabled - using simplified P2P payment model
            // TODO: Implement PayPal integration in future version
            print("PayPal setup attempted but disabled in MVP")
            
            // For MVP, just mark as setup completed
            print("✅ PAYPAL: PayPal setup simulation completed for MVP")
            
            // Mark as completed
            await MainActor.run {
                isCompleted = true
            }
            
        } catch {
            print("🔴 PAYPAL: Error saving PayPal info: \(error)")
            errorMessage = "Failed to setup PayPal. Please try again."
            showingError = true
        }
    }
    
    // MVP: PayPal earnings update disabled - using simplified P2P payment model
    private func updateHostEarningsForPayPal(hostId: String) async throws {
        // TODO: Implement PayPal earnings tracking in future version
        print("PayPal earnings update skipped in MVP")
        return
        
        /*
        let db = Firestore.firestore()
        let earningsRef = db.collection("hostEarnings").document(hostId)
        
        try await db.runTransaction { (transaction, errorPointer) -> Any? in
            do {
                let earningsDoc = try transaction.getDocument(earningsRef)
                
                if earningsDoc.exists {
                    // Update existing earnings
                    transaction.updateData(["bankAccountSetup": true], forDocument: earningsRef)
                } else {
                    // Create new earnings record
                    let hostName = Auth.auth().currentUser?.displayName ?? "Host"
                    var newEarnings = HostEarnings(hostId: hostId, hostName: hostName)
                    newEarnings.bankAccountSetup = true
                    
                    try transaction.setData(from: newEarnings, forDocument: earningsRef)
                }
                return nil
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }
        }
        */
    }
    
    private func maskEmail(_ email: String) -> String {
        let components = email.components(separatedBy: "@")
        guard components.count == 2 else { return email }
        
        let username = components[0]
        let domain = components[1]
        
        let maskedUsername = username.count > 2 ? 
            String(username.prefix(2)) + "••••" : 
            "••••"
        
        return "\(maskedUsername)@\(domain)"
    }
}

// MARK: - PayPal Info Row Component
struct PayPalInfoRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.blue)
                .frame(width: 16)
            
            Text(text)
                .font(.caption)
                .foregroundColor(.gray)
            
            Spacer()
        }
    }
}

// MARK: - Preview
struct PayPalSetupCard_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            PayPalSetupCard(isCompleted: .constant(false))
            PayPalSetupCard(isCompleted: .constant(true))
        }
        .padding()
        .background(Color.black)
        .preferredColorScheme(.dark)
    }
} 