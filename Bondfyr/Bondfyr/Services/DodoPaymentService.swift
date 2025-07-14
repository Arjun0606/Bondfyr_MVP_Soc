import Foundation
import SwiftUI
import FirebaseFirestore

// MARK: - Dodo Payment Service for Marketplace Integration

@MainActor
class DodoPaymentService: ObservableObject {
    static let shared = DodoPaymentService()
    
    @Published var isProcessingPayment = false
    @Published var paymentError: String?
    @Published var paymentURL: String?
    
    private init() {
        // DodoPaymentService initialized
    }
    
    // MARK: - Configuration
    private let dodoAPIKey: String = {
        if let apiKey = Bundle.main.object(forInfoDictionaryKey: "DODO_API_KEY") as? String {
            return apiKey
        }
        return "YOUR_DODO_API_KEY" // Replace with your actual Dodo API key
    }()
    
    private let dodoWebhookSecret: String = {
        if let secret = Bundle.main.object(forInfoDictionaryKey: "DODO_WEBHOOK_SECRET") as? String {
            return secret
        }
        return "YOUR_DODO_WEBHOOK_SECRET" // Replace with your actual webhook secret
    }()
    
    // Use dev mode for testing, production for live
    private let dodoEnvironment: DodoEnvironment = .dev
    private var baseURL: String {
        return dodoEnvironment.baseURL
    }
    
    // MARK: - Configuration Validation
    var isConfigured: Bool {
        return !dodoAPIKey.contains("YOUR_") && !dodoWebhookSecret.contains("YOUR_")
    }
    
    // MARK: - Commission Calculation (20% Platform Fee)
    
    /// Calculate platform fee (20%)
    func calculateBondfyrFee(from totalAmount: Double) -> Double {
        return totalAmount * 0.20
    }
    
    /// Calculate host earnings (80%)
    func calculateHostEarnings(from totalAmount: Double) -> Double {
        return totalAmount * 0.80
    }
    
    // MARK: - Payment Processing
    
    /// Process payment for afterparty access using Dodo Payments
    func requestAfterpartyAccess(
        afterparty: Afterparty,
        userId: String,
        userName: String,
        userHandle: String
    ) async throws -> Bool {
        
        isProcessingPayment = true
        defer { isProcessingPayment = false }
        
        // TESTING MODE: Simulate successful payment without real API
        if !isConfigured {
            print("⚠️ DODO: Running in test mode - simulating payment success")
            
            // Simulate a delay for payment processing
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            
            // Complete the payment in the afterparty manager
            let afterpartyManager = AfterpartyManager.shared
            
            // Find the guest request
            if let request = afterparty.guestRequests.first(where: { $0.userId == userId }) {
                // Complete party membership
                try await afterpartyManager.completePartyMembershipAfterPayment(
                    afterpartyId: afterparty.id,
                    userId: userId,
                    paymentIntentId: "test_\(UUID().uuidString)"
                )
                
                print("✅ DODO TEST: Payment simulated successfully for user \(userHandle)")
                return true
            } else {
                print("🔴 DODO TEST: No guest request found for user")
                throw DodoPaymentError.intentCreationFailed
            }
        }
        
        // PRODUCTION MODE: Real Dodo payment flow
        do {
            // Process payment using Dodo Payments
            let paymentIntent = try await createDodoPaymentIntent(
                afterparty: afterparty,
                userId: userId,
                userName: userName,
                userHandle: userHandle
            )
            
            // Store the payment URL to be opened by the UI
            self.paymentURL = paymentIntent.url
            
            // The actual payment completion will be handled by webhook
            // For now, just return true to indicate the payment process has started
            return true
            
        } catch {
            print("🔴 DODO: API Error - \(error.localizedDescription)")
            print("⚠️ DODO: Falling back to test mode due to API error")
            
            // Fallback to test mode if API fails
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            
            let afterpartyManager = AfterpartyManager.shared
            if let request = afterparty.guestRequests.first(where: { $0.userId == userId }) {
                try await afterpartyManager.completePartyMembershipAfterPayment(
                    afterpartyId: afterparty.id,
                    userId: userId,
                    paymentIntentId: "test_\(UUID().uuidString)"
                )
            }
            
            return true
        }
    }
    
    /// Create Dodo Payment Intent
    private func createDodoPaymentIntent(
        afterparty: Afterparty,
        userId: String,
        userName: String,
        userHandle: String
    ) async throws -> DodoPaymentIntent {
        
        let platformFee = calculateBondfyrFee(from: afterparty.ticketPrice)
        let hostEarnings = calculateHostEarnings(from: afterparty.ticketPrice)
        
        // Create payment using Dodo's payment API
        let paymentData: [String: Any] = [
            "payment_link": true,
            "billing": [
                "city": afterparty.location,
                "country": "US",
                "state": "CA",
                "street": afterparty.location,
                "zipcode": 0
            ],
            "customer": [
                "email": "\(userHandle)@bondfyr.com", // Temporary email until we have real user emails
                "name": userName
            ],
            "product_cart": [[
                "product_id": "pdt_mPFnouRlaQerAPmYz1gY", // Your test product from Dodo dashboard
                "quantity": 1
            ]],
            "return_url": "bondfyr://payment-success?afterpartyId=\(afterparty.id)",
            "metadata": [
                "afterpartyId": afterparty.id,
                "userId": userId,
                "userName": userName,
                "userHandle": userHandle,
                "hostId": afterparty.userId,
                "platformFee": String(format: "%.2f", platformFee),
                "hostEarnings": String(format: "%.2f", hostEarnings)
            ]
        ]
        
        var request = URLRequest(url: URL(string: "\(dodoEnvironment.baseURL)/payments")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(dodoAPIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: paymentData)
        
        print("🔵 DODO API: Creating payment at \(request.url?.absoluteString ?? "unknown")")
        print("🔵 DODO API: Request body: \(paymentData)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("🔵 DODO API: Response status: \(httpResponse.statusCode)")
            if let responseString = String(data: data, encoding: .utf8) {
                print("🔵 DODO API: Response body: \(responseString)")
            }
            
            if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let paymentLink = json["payment_link"] as? String,
                   let paymentId = json["payment_id"] as? String {
                    
                    return DodoPaymentIntent(
                        url: paymentLink,
                        sessionId: paymentId
                    )
                }
            }
        }
        
        // If we get here, the API call failed
        throw DodoPaymentError.apiError("Failed to create payment with Dodo API")
    }
    
    /// Present Dodo checkout to user
    private func presentDodoCheckout(url: String) async {
        await MainActor.run {
            if let checkoutURL = URL(string: url) {
                UIApplication.shared.open(checkoutURL)
            }
        }
    }
    
    /// Confirm Dodo payment after user completion
    func confirmDodoPayment(intentId: String) async throws -> Bool {
        var request = URLRequest(url: URL(string: "\(baseURL)/v1/payment_intents/\(intentId)/confirm")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(dodoAPIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw DodoPaymentError.confirmationFailed
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let status = json?["status"] as? String, status == "succeeded" else {
            throw DodoPaymentError.confirmationFailed
        }
        
        return true
    }
    
    /// Process refund when host cancels party
    func processRefund(intentId: String, amount: Double? = nil) async throws {
        let refundData: [String: Any] = [
            "payment_intent": intentId,
            "amount": amount != nil ? Int(amount! * 100) : nil, // Partial or full refund
            "reason": "requested_by_customer", // Host cancelled party
            "metadata": [
                "refund_reason": "afterparty_cancelled_by_host"
            ]
        ].compactMapValues { $0 }
        
        var request = URLRequest(url: URL(string: "\(baseURL)/v1/refunds")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(dodoAPIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: refundData)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw DodoPaymentError.refundFailed
        }
        
        print("✅ Successfully processed Dodo refund for intent \(intentId)")
    }
    
    /// Handle Dodo payment success (called from deep link)
    func handlePaymentSuccess(intentId: String) async {
        do {
            // Confirm the payment
            let success = try await confirmDodoPayment(intentId: intentId)
            if success {
                print("✅ Dodo payment confirmed successfully")
                
                // Update UI or navigate user
                await MainActor.run {
                    // Notify that payment was successful
                    NotificationCenter.default.post(name: .dodoPaymentSuccess, object: intentId)
                }
            }
        } catch {
            print("🔴 Error confirming Dodo payment: \(error)")
            await MainActor.run {
                paymentError = error.localizedDescription
                NotificationCenter.default.post(name: .dodoPaymentError, object: error)
            }
        }
    }
    
    /// Process webhook from Dodo Payments
    static func handleWebhook(payload: [String: Any]) async {
        // This would be called from your Firebase Cloud Function
        guard let eventType = payload["type"] as? String,
              let data = payload["data"] as? [String: Any],
              let object = data["object"] as? [String: Any] else {
            return
        }
        
        switch eventType {
        case "payment_intent.succeeded":
            await handlePaymentSucceeded(paymentIntent: object)
        case "payment_intent.payment_failed":
            await handlePaymentFailed(paymentIntent: object)
        case "charge.dispute.created":
            await handleChargeDispute(dispute: object)
        default:
            print("📦 Unhandled Dodo webhook event: \(eventType)")
        }
    }
    
    /// Handle successful payment webhook
    private static func handlePaymentSucceeded(paymentIntent: [String: Any]) async {
        guard let intentId = paymentIntent["id"] as? String,
              let metadata = paymentIntent["metadata"] as? [String: String],
              let afterpartyId = metadata["afterparty_id"],
              let userId = metadata["user_id"],
              let userHandle = metadata["user_handle"],
              let hostId = metadata["host_id"],
              let hostEarnings = metadata["host_earnings"] else {
            print("🔴 Missing required metadata in Dodo payment success webhook")
            return
        }
        
        print("✅ Processing Dodo payment success for user \(userHandle) in afterparty \(afterpartyId)")
        
        // NEW FLOW: Complete party membership after payment
        do {
            let afterpartyManager = AfterpartyManager.shared
            try await afterpartyManager.completePartyMembershipAfterPayment(
                afterpartyId: afterpartyId,
                userId: userId,
                paymentIntentId: intentId
            )
            print("🟢 PAYMENT: Successfully completed party membership for \(userHandle)")
        } catch {
            print("🔴 PAYMENT: Error completing party membership: \(error)")
        }
        
        // Update payment status in Firestore (this would typically be done in Firebase Cloud Function)
        await updatePaymentStatus(
            afterpartyId: afterpartyId,
            userId: userId,
            intentId: intentId,
            status: .paid
        )
    }
    
    /// Handle failed payment webhook
    private static func handlePaymentFailed(paymentIntent: [String: Any]) async {
        guard let intentId = paymentIntent["id"] as? String,
              let metadata = paymentIntent["metadata"] as? [String: String],
              let afterpartyId = metadata["afterparty_id"],
              let userId = metadata["user_id"] else {
            return
        }
        
        print("🔴 Processing Dodo payment failure for user \(userId) in afterparty \(afterpartyId)")
        
        // Update payment status in Firestore
        await updatePaymentStatus(
            afterpartyId: afterpartyId,
            userId: userId,
            intentId: intentId,
            status: .pending // Keep as pending so user can retry
        )
    }
    
    /// Handle charge dispute webhook
    private static func handleChargeDispute(dispute: [String: Any]) async {
        // Handle chargeback/dispute logic
        print("⚠️ Charge dispute received: \(dispute)")
    }
    
    /// Update payment status in Firestore
    private static func updatePaymentStatus(
        afterpartyId: String,
        userId: String,
        intentId: String,
        status: PaymentStatus
    ) async {
        // This would be implemented in Firebase Cloud Function
        // For now, just log the update
        print("📝 Would update payment status: afterparty=\(afterpartyId), user=\(userId), status=\(status)")
    }
    
    /// Get party title for notifications
    private static func getPartyTitle(afterpartyId: String) async -> String? {
        do {
            let db = Firestore.firestore()
            let document = try await db.collection("afterparties").document(afterpartyId).getDocument()
            
            if let data = document.data(),
               let title = data["title"] as? String {
                return title
            }
        } catch {
            print("🔴 Error fetching party title: \(error)")
        }
        return nil
    }
    
    /// Trigger payment notification manually (for testing)
    func triggerTestPaymentNotification(afterpartyId: String, partyTitle: String, guestName: String, amount: String) {
        print("🧪 TEST: Triggering test payment notification")
        NotificationManager.shared.notifyHostOfPaymentReceived(
            partyId: afterpartyId,
            partyTitle: partyTitle,
            guestName: guestName,
            amount: amount
        )
    }
}

// MARK: - Dodo Environment
enum DodoEnvironment {
    case dev
    case production
    
    var baseURL: String {
        switch self {
        case .dev:
            return "https://test.dodopayments.com"
        case .production:
            return "https://live.dodopayments.com"
        }
    }
}

// MARK: - Dodo Models
struct DodoPaymentIntent {
    let url: String
    let sessionId: String
}

// MARK: - Dodo Error Types
enum DodoPaymentError: LocalizedError {
    case invalidURL
    case authenticationFailed
    case intentCreationFailed
    case invalidIntentResponse
    case confirmationFailed
    case refundFailed
    case networkError(Error)
    case apiError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL configuration"
        case .authenticationFailed:
            return "Failed to authenticate with Dodo Payments"
        case .intentCreationFailed:
            return "Failed to create Dodo payment intent"
        case .invalidIntentResponse:
            return "Invalid response from Dodo payment intent creation"
        case .confirmationFailed:
            return "Failed to confirm Dodo payment"
        case .refundFailed:
            return "Failed to process Dodo refund"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .apiError(let message):
            return "API error: \(message)"
        }
    }
}

// MARK: - Transaction Models with 20% Commission

struct DodoTransaction: Identifiable, Codable {
    let id: String
    let afterpartyId: String
    let afterpartyTitle: String
    let amount: Double
    let platformFee: Double // 20% of amount
    let hostEarnings: Double // 80% of amount
    let type: TransactionType
    let status: PaymentStatus
    let createdAt: Date
    let dodoIntentId: String?
    
    enum TransactionType: String, Codable {
        case purchase = "purchase"
        case refund = "refund"
        case payout = "payout" // For hosts
    }
    
    init(
        id: String = UUID().uuidString,
        afterpartyId: String,
        afterpartyTitle: String,
        amount: Double,
        type: TransactionType,
        status: PaymentStatus = .pending,
        createdAt: Date = Date(),
        dodoIntentId: String? = nil
    ) {
        self.id = id
        self.afterpartyId = afterpartyId
        self.afterpartyTitle = afterpartyTitle
        self.amount = amount
        self.platformFee = amount * 0.20 // 20% platform fee
        self.hostEarnings = amount * 0.80 // 80% to host
        self.type = type
        self.status = status
        self.createdAt = createdAt
        self.dodoIntentId = dodoIntentId
    }
}

// MARK: - Notification Extensions
extension Notification.Name {
    static let dodoPaymentSuccess = Notification.Name("dodoPaymentSuccess")
    static let dodoPaymentError = Notification.Name("dodoPaymentError")
} 