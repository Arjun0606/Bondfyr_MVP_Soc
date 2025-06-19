import Foundation
import SwiftUI

// MARK: - Payment Service for Stripe Integration
@MainActor
class PaymentService: ObservableObject {
    static let shared = PaymentService()
    
    @Published var isProcessingPayment = false
    @Published var paymentError: String?
    
    private init() {}
    
    // MARK: - Placeholder Stripe Methods
    
    /// Shows a placeholder Stripe payment sheet for joining an afterparty
    func requestAfterpartyAccess(
        afterparty: Afterparty,
        userId: String,
        userName: String,
        userHandle: String
    ) async throws -> Bool {
        isProcessingPayment = true
        defer { isProcessingPayment = false }
        
        // Simulate payment processing delay
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // For now, we'll just show an alert and save the request
        await showPaymentPlaceholderAlert(price: afterparty.ticketPrice)
        
        // Create guest request with pending payment status
        let guestRequest = GuestRequest(
            userId: userId,
            userName: userName,
            userHandle: userHandle,
            paymentStatus: .pending,
            stripePaymentIntentId: "pi_placeholder_\(UUID().uuidString)"
        )
        
        // In a real implementation, we would:
        // 1. Create Stripe PaymentIntent
        // 2. Present payment sheet
        // 3. Process payment
        // 4. Update Firestore with payment status
        
        return true
    }
    
    /// Placeholder for creating a Stripe payment intent
    private func createPaymentIntent(
        amount: Double,
        currency: String = "usd",
        description: String
    ) async throws -> String {
        // Placeholder implementation
        // In real app: POST to your backend to create PaymentIntent
        return "pi_placeholder_\(UUID().uuidString)"
    }
    
    /// Process refund when host cancels party
    func processRefund(paymentIntentId: String) async throws {
        // Placeholder for Stripe refund
        print("Processing refund for payment: \(paymentIntentId)")
        
        // In real implementation:
        // 1. Call Stripe refund API
        // 2. Update payment status in Firestore
        // 3. Send notification to user
    }
    
    /// Calculate platform fee (12%)
    func calculateBondfyrFee(from totalAmount: Double) -> Double {
        return totalAmount * 0.12
    }
    
    /// Calculate host earnings (88%)
    func calculateHostEarnings(from totalAmount: Double) -> Double {
        return totalAmount * 0.88
    }
    
    // MARK: - Placeholder UI Alert
    
    private func showPaymentPlaceholderAlert(price: Double) async {
        await MainActor.run {
            let alert = UIAlertController(
                title: "Payment Coming Soon! 💳",
                message: "Stripe integration launching soon!\n\nYour card won't be charged yet.\nPrice: $\(Int(price))",
                preferredStyle: .alert
            )
            
            alert.addAction(UIAlertAction(title: "Got it!", style: .default))
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootViewController = window.rootViewController {
                rootViewController.present(alert, animated: true)
            }
        }
    }
}

// MARK: - Payment Models

struct PaymentIntent: Codable {
    let id: String
    let amount: Double
    let currency: String
    let status: PaymentIntentStatus
    let clientSecret: String?
}

enum PaymentIntentStatus: String, Codable {
    case requiresPaymentMethod = "requires_payment_method"
    case requiresConfirmation = "requires_confirmation"
    case processing = "processing"
    case succeeded = "succeeded"
    case canceled = "canceled"
}

// MARK: - Transaction History

struct Transaction: Identifiable, Codable {
    let id: String
    let afterpartyId: String
    let afterpartyTitle: String
    let amount: Double
    let type: TransactionType
    let status: PaymentStatus
    let createdAt: Date
    let stripePaymentIntentId: String?
    
    enum TransactionType: String, Codable {
        case purchase = "purchase"
        case refund = "refund"
        case payout = "payout" // For hosts
    }
}

// MARK: - Earnings Dashboard Models

struct HostEarnings: Codable {
    let totalEarnings: Double
    let totalAfterparties: Int
    let totalGuests: Int
    let averagePartySize: Double
    let thisMonth: Double
    let lastMonth: Double
    let pendingPayouts: Double
    let transactions: [Transaction]
} 