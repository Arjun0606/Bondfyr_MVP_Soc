import SwiftUI
import SafariServices
import CoreLocation

struct DodoPaymentSheet: View {
    let afterparty: Afterparty
    let onCompletion: () -> Void
    
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var isProcessingPayment = false
    @State private var showingWebView = false
    @State private var paymentURL: URL?
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var paymentIntentId: String?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "creditcard.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.blue)
                    
                    Text("Complete Payment")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("Secure your spot at \(afterparty.title)")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                
                // Payment Details Card
                VStack(spacing: 16) {
                    VStack(spacing: 12) {
                        HStack {
                            Text("Party:")
                            Spacer()
                            Text(afterparty.title)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        
                        HStack {
                            Text("Host:")
                            Spacer()
                            Text("@\(afterparty.hostHandle)")
                                .foregroundColor(.pink)
                        }
                        
                        Divider()
                            .background(Color.gray)
                        
                        HStack {
                            Text("Amount:")
                            Spacer()
                            Text("$\(Int(afterparty.ticketPrice))")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                        }
                        .foregroundColor(.white)
                        
                        Text("Processed securely by Dodo Payments")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .padding()
                .background(Color(.systemGray6).opacity(0.1))
                .cornerRadius(16)
                
                Spacer()
                
                // Payment Button
                Button(action: initiatePayment) {
                    HStack {
                        if isProcessingPayment {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                            Text("Processing...")
                        } else {
                            Image(systemName: "lock.fill")
                            Text("Pay Securely - $\(Int(afterparty.ticketPrice))")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [.blue, .purple]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(.white)
                    .cornerRadius(16)
                }
                .disabled(isProcessingPayment)
                
                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
                .foregroundColor(.gray)
            }
            .padding()
            .background(Color.black.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                trailing: Button("Close") {
                    presentationMode.wrappedValue.dismiss()
                }
                .foregroundColor(.white)
            )
            .onAppear {
                print("🚨🚨🚨 PAYMENT SHEET: APPEARED for party \(afterparty.title)")
                print("🚨🚨🚨 PAYMENT SHEET: This means the sheet binding is working!")
            }
            .onDisappear {
                print("🚨🚨🚨 PAYMENT SHEET: DISAPPEARED for party \(afterparty.title)")
            }
        }
        .sheet(isPresented: $showingWebView) {
            if let url = paymentURL {
                DodoPaymentWebView(
                    url: url,
                    paymentIntentId: paymentIntentId ?? "",
                    afterpartyId: afterparty.id,
                    onCompletion: { success in
                        showingWebView = false
                        if success {
                            presentationMode.wrappedValue.dismiss()
                            onCompletion()
                        }
                    }
                )
            }
        }
        .alert("Payment Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .preferredColorScheme(.dark)
    }
    
    private func initiatePayment() {
        print("🚨🚨🚨 PAYMENT BUTTON CLICKED!")
        print("🚨🚨🚨 INITIATING PAYMENT PROCESS!")
        
        guard let currentUser = authViewModel.currentUser else {
            print("🚨🚨🚨 ERROR: No current user found!")
            errorMessage = "User not found"
            showingError = true
            return
        }
        
        print("🚨🚨🚨 PAYMENT SHEET: Starting payment for user \(currentUser.username ?? "unknown")")
        print("🚨🚨🚨 PAYMENT SHEET: Party: \(afterparty.title), Price: $\(afterparty.ticketPrice)")
        
        Task {
            isProcessingPayment = true
            defer { isProcessingPayment = false }
            
            do {
                print("🚨🚨🚨 ABOUT TO CALL DodoPaymentService...")
                print("🚨🚨🚨 User ID: \(currentUser.uid)")
                print("🚨🚨🚨 User Name: \(currentUser.name)")
                print("🚨🚨🚨 Party ID: \(afterparty.id)")
                print("🚨🚨🚨 DodoPaymentService.shared exists: \(DodoPaymentService.shared)")
                
                // Use clean Dodo payment service
                print("🚨🚨🚨 CALLING processPayment NOW...")
                let result = try await DodoPaymentService.shared.processPayment(
                    afterparty: afterparty,
                    userId: currentUser.uid,
                    userName: currentUser.name,
                    userHandle: currentUser.username ?? "@\(currentUser.name)"
                )
                
                print("🚨🚨🚨 PAYMENT CALL RETURNED: \(result)")
                print("🚨🚨🚨 Payment processing initiated successfully!")
                print("🚨🚨🚨 Safari opened for payment, monitoring for completion...")
                
                await MainActor.run {
                    errorMessage = "🌐 Payment opened in Safari. Complete payment and return to app."
                    showingError = true
                    
                    // Dismiss after showing message - payment completion will be handled by monitoring
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        presentationMode.wrappedValue.dismiss()
                        onCompletion()
                    }
                }
                
            } catch {
                print("🚨🚨🚨 PAYMENT ERROR CAUGHT!")
                print("🚨🚨🚨 Error: \(error)")
                print("🚨🚨🚨 Error type: \(type(of: error))")
                print("🚨🚨🚨 Error description: \(error.localizedDescription)")
                await MainActor.run {
                    print("🔴 PAYMENT SHEET: Error initiating payment: \(error)")
                    print("🔴 PAYMENT SHEET: Error type: \(type(of: error))")
                    print("🔴 PAYMENT SHEET: Error description: \(error.localizedDescription)")
                    if let dodoError = error as? DodoPaymentError {
                        print("🔴 PAYMENT SHEET: Dodo error: \(dodoError)")
                    }
                    errorMessage = "Payment error: \(error.localizedDescription)"
                    showingError = true
                }
            }
        }
    }
}

// MARK: - Payment WebView
struct DodoPaymentWebView: UIViewControllerRepresentable {
    let url: URL
    let paymentIntentId: String
    let afterpartyId: String
    let onCompletion: (Bool) -> Void
    
    func makeUIViewController(context: Context) -> SFSafariViewController {
        let safariVC = SFSafariViewController(url: url)
        safariVC.delegate = context.coordinator
        return safariVC
    }
    
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, SFSafariViewControllerDelegate {
        let parent: DodoPaymentWebView
        
        init(_ parent: DodoPaymentWebView) {
            self.parent = parent
        }
        
        func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
            // User manually closed the payment window
            parent.onCompletion(false)
        }
        
        func safariViewController(_ controller: SFSafariViewController, didCompleteInitialLoad didLoadSuccessfully: Bool) {
            if !didLoadSuccessfully {
                parent.onCompletion(false)
            }
        }
    }
}

#Preview {
    DodoPaymentSheet(
        afterparty: Afterparty(
            userId: "test",
            hostHandle: "@testhost",
            coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0),
            radius: 1000,
            startTime: Date(),
            endTime: Date().addingTimeInterval(3600),
            city: "Test City",
            locationName: "Test Location",
            description: "Test party",
            address: "123 Test St",
            googleMapsLink: "",
            vibeTag: "test",
            createdAt: Date(),
            title: "Test Party",
            ticketPrice: 20.0,
            coverPhotoURL: nil,
            maxGuestCount: 50,
            visibility: .publicFeed,
            approvalType: .manual,
            ageRestriction: nil,
            maxMaleRatio: 1.0,
            legalDisclaimerAccepted: true,
            venmoHandle: nil
        ),
        onCompletion: {}
    )
    .environmentObject(AuthViewModel())
} 