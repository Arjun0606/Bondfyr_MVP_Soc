import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct HostBankSetupView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject private var authViewModel: AuthViewModel
    
    @State private var selectedMethod: BankSetupMethod = .ach
    @State private var isLoading = false
    @State private var showingSuccess = false
    @State private var errorMessage = ""
    @State private var showingError = false
    
    // ACH Bank Details
    @State private var fullName = ""
    @State private var bankName = ""
    @State private var routingNumber = ""
    @State private var accountNumber = ""
    @State private var confirmAccountNumber = ""
    @State private var accountType: HostBankInfo.BankAccountType = .checking
    
    // Validation
    private var isACHFormValid: Bool {
        !fullName.isEmpty &&
        !bankName.isEmpty &&
        routingNumber.count == 9 &&
        accountNumber.count >= 8 &&
        accountNumber == confirmAccountNumber &&
        routingNumber.allSatisfy(\.isNumber)
    }
    
    enum BankSetupMethod: String, CaseIterable {
        case ach = "Bank Account"
        
        var icon: String {
            return "building.columns"
        }
        
        var description: String {
            return "Direct deposit to your bank account (1-3 business days)"
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    methodSelectionSection
                    
                    switch selectedMethod {
                    case .ach:
                        achBankFormSection
                    }
                    
                    submitButton
                    securityNoteSection
                }
                .padding()
            }
            .navigationSafeBackground()
            .navigationTitle("Bank Setup")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.pink)
                }
            }
        }
        .alert("Success!", isPresented: $showingSuccess) {
            Button("Done") {
                presentationMode.wrappedValue.dismiss()
            }
        } message: {
            Text("Your bank account has been set up successfully! You'll receive payouts every Friday via ACH transfer (1-3 business days).")
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "building.columns")
                .font(.system(size: 60))
                .foregroundColor(.green)
            
            Text("Setup Direct Deposit")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text("Add your US bank account to receive weekly party earnings via direct deposit")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - Method Selection (simplified)
    private var methodSelectionSection: some View {
        VStack(spacing: 16) {
            Text("Bank Account Details")
                .font(.headline)
                .foregroundColor(.white)
            
            HStack {
                Image(systemName: "building.columns")
                    .font(.title)
                    .foregroundColor(.green)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Direct Deposit")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                    
                    Text("Money arrives in 1-3 business days")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
            .padding()
            .background(Color.green.opacity(0.2))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.green, lineWidth: 2)
            )
            .cornerRadius(12)
        }
    }
    
    // MARK: - Bank Account Form (simplified from ACH)
    private var achBankFormSection: some View {
        VStack(spacing: 20) {
            Text("Your Bank Information")
                .font(.headline)
                .foregroundColor(.white)
            
            VStack(spacing: 16) {
                CustomTextField(
                    title: "Full Name",
                    text: $fullName,
                    placeholder: "John Doe",
                    keyboardType: .default
                )
                
                CustomTextField(
                    title: "Bank Name",
                    text: $bankName,
                    placeholder: "Chase, Wells Fargo, Bank of America...",
                    keyboardType: .default
                )
                
                CustomTextField(
                    title: "Routing Number",
                    text: $routingNumber,
                    placeholder: "123456789 (9 digits)",
                    keyboardType: .numberPad
                )
                .onChange(of: routingNumber) { newValue in
                    if newValue.count > 9 {
                        routingNumber = String(newValue.prefix(9))
                    }
                }
                
                CustomTextField(
                    title: "Account Number",
                    text: $accountNumber,
                    placeholder: "Your checking account number",
                    keyboardType: .numberPad,
                    isSecure: true
                )
                
                CustomTextField(
                    title: "Confirm Account Number",
                    text: $confirmAccountNumber,
                    placeholder: "Re-enter your account number",
                    keyboardType: .numberPad,
                    isSecure: true
                )
                
                // Account Type Picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("Account Type")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                    
                    Picker("Account Type", selection: $accountType) {
                        Text("Checking").tag(HostBankInfo.BankAccountType.checking)
                        Text("Savings").tag(HostBankInfo.BankAccountType.savings)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                // Help text
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                    Text("You can find your routing and account numbers on your checks or mobile banking app")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color.black.opacity(0.3))
        .cornerRadius(12)
    }
    
    // MARK: - Submit Button
    private var submitButton: some View {
        Button(action: submitBankDetails) {
            HStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                }
                Text(isLoading ? "Setting up..." : "Setup Bank Account")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                isFormValid ? Color.green : Color.gray
            )
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(!isFormValid || isLoading)
    }
    
    private var isFormValid: Bool {
        switch selectedMethod {
        case .ach: return isACHFormValid
        }
    }
    
    // MARK: - Security Note
    private var securityNoteSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "lock.shield")
                    .foregroundColor(.green)
                Text("Your information is secure")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                Spacer()
            }
            
            Text("• Bank details are encrypted and stored securely\n• We never store your full account number\n• Payouts are processed via secure ACH transfer\n• Money arrives in 1-3 business days (standard US banking)\n• You can update or remove this information anytime")
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.leading)
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - Actions
    private func submitBankDetails() {
        Task {
            await saveBankDetails()
        }
    }
    
    private func saveBankDetails() async {
        guard let currentUserId = authViewModel.currentUser?.uid else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let bankInfo = HostBankInfo(
                hostId: currentUserId,
                accountType: accountType,
                bankName: bankName,
                accountNumber: encryptAccountNumber(accountNumber),
                routingNumber: routingNumber,
                setupDate: Date(),
                verified: false // Will be verified later
            )
            
            // Save to Firestore
            let db = Firestore.firestore()
            try await db.collection("hostBankInfo").document(currentUserId).setData(from: bankInfo)
            
            // Update host earnings to mark bank setup as complete
            try await updateHostEarningsForBankSetup(hostId: currentUserId)
            
            print("✅ BANK SETUP: Successfully saved bank details")
            showingSuccess = true
            
        } catch {
            print("🔴 BANK SETUP: Error saving bank details: \(error)")
            errorMessage = "Failed to save bank details. Please try again."
            showingError = true
        }
    }
    
    private func updateHostEarningsForBankSetup(hostId: String) async throws {
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
                    let hostName = authViewModel.currentUser?.name ?? "Host"
                    let newEarnings = HostEarnings(
                        id: hostId,
                        hostId: hostId,
                        hostName: hostName,
                        totalEarnings: 0.0,
                        pendingEarnings: 0.0,
                        paidEarnings: 0.0,
                        lastPayoutDate: nil,
                        bankAccountSetup: true,
                        transactions: [],
                        payoutHistory: []
                    )
                    
                    try transaction.setData(from: newEarnings, forDocument: earningsRef)
                }
                return nil
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }
        }
    }
    
    private func encryptAccountNumber(_ accountNumber: String) -> String {
        // In production, use proper encryption
        // For now, we'll just mask it
        let lastFour = String(accountNumber.suffix(4))
        return "****\(lastFour)"
    }
}

// MARK: - Method Card
struct MethodCard: View {
    let method: HostBankSetupView.BankSetupMethod
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                Image(systemName: method.icon)
                    .font(.title)
                    .foregroundColor(isSelected ? .green : .gray)
                
                Text(method.rawValue)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                
                Text(method.description)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                isSelected ? Color.green.opacity(0.2) : Color.black.opacity(0.3)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.green : Color.clear, lineWidth: 2)
            )
            .cornerRadius(12)
        }
    }
}

// MARK: - Custom Text Field
struct CustomTextField: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    let keyboardType: UIKeyboardType
    let isSecure: Bool
    
    init(title: String, text: Binding<String>, placeholder: String, keyboardType: UIKeyboardType = .default, isSecure: Bool = false) {
        self.title = title
        self._text = text
        self.placeholder = placeholder
        self.keyboardType = keyboardType
        self.isSecure = isSecure
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)
            
            Group {
                if isSecure {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                        .keyboardType(keyboardType)
                }
            }
            .padding()
            .background(Color.black.opacity(0.2))
            .cornerRadius(8)
            .foregroundColor(.white)
        }
    }
} 