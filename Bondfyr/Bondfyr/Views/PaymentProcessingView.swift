import SwiftUI
import Combine

struct PaymentProcessingView: View {
    let ticket: TicketModel
    let onSuccess: () -> Void
    
    @State private var timer: Timer?
    @State private var isProcessing = true
    @State private var processingStep = 0
    @State private var isSuccess = false
    @State private var errorMessage: String? = nil
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Header
                Text("Processing Payment")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                if isProcessing {
                    // Processing state
                    VStack(spacing: 30) {
                        // Progress indicator
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .pink))
                            .scaleEffect(1.5)
                        
                        // Current step
                        Text(processingSteps[min(processingStep, processingSteps.count - 1)])
                            .foregroundColor(.gray)
                    }
                    .padding(40)
                } else if isSuccess {
                    // Success state
                    VStack(spacing: 25) {
                        Image(systemName: "checkmark.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 100, height: 100)
                            .foregroundColor(.green)
                        
                        Text("Payment Successful!")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("Your ticket has been confirmed")
                            .foregroundColor(.gray)
                        
                        Button(action: {
                            presentationMode.wrappedValue.dismiss()
                            onSuccess()
                        }) {
                            Text("View My Tickets")
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.pink)
                                .cornerRadius(12)
                                .padding(.horizontal)
                        }
                        .padding(.top, 20)
                    }
                } else {
                    // Error state
                    VStack(spacing: 25) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 100, height: 100)
                            .foregroundColor(.red)
                        
                        Text("Payment Failed")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text(errorMessage ?? "There was an error processing your payment. Please try again.")
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                        
                        Button(action: {
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Text("Go Back")
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.pink)
                                .cornerRadius(12)
                                .padding(.horizontal)
                        }
                        .padding(.top, 20)
                    }
                }
            }
            .padding()
            .background(Color.black)
            .onAppear {
                startPaymentSimulation()
            }
            .onDisappear {
                timer?.invalidate()
            }
        }
    }
    
    private func startPaymentSimulation() {
        isProcessing = true
        processingStep = 0
        
        // Simulate processing steps with a timer
        timer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { timer in
            processingStep += 1
            
            if processingStep >= processingSteps.count {
                timer.invalidate()
                
                // Always succeed for now (in a real app you'd handle actual payment)
                isProcessing = false
                isSuccess = true
                
                if isSuccess {
                    // Add ticket to storage
                    TicketStorage.save(ticket)
                }
            }
        }
    }
    
    private let processingSteps = [
        "Connecting to payment gateway...",
        "Verifying payment details...",
        "Processing your payment...",
        "Finalizing transaction...",
        "Generating your ticket..."
    ]
}

struct PaymentProcessingView_Previews: PreviewProvider {
    static var previews: some View {
        PaymentProcessingView(ticket: TicketModel(
            event: "Sample Event",
            tier: "VIP",
            count: 2,
            genders: ["Male", "Female"],
            prCode: "",
            timestamp: ISO8601DateFormatter().string(from: Date()),
            ticketId: UUID().uuidString,
            phoneNumber: "1234567890"
        ), onSuccess: {})
    }
} 