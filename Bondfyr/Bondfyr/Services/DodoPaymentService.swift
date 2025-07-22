import Foundation
import SwiftUI
import FirebaseFirestore

// MARK: - Clean Dodo Payment Service (Bulletproof Version)

@MainActor
class DodoPaymentService: ObservableObject {
    static let shared = DodoPaymentService()
    
    @Published var isProcessingPayment = false
    @Published var paymentError: String?
    @Published var paymentURL: String?
    
    private init() {}
    
    // MARK: - Configuration
    private let dodoAPIKey: String = "V5NKMaH4W8-DkX1A.oj-tjNdW2_L-CsM-xN2ItGSJFjWqPkqDbPuQ3usa9ykCEwNe"
    private let dodoWebhookSecret: String = "whsec_SkxMTLLPZc7xMtkZJNckk2xa"
    private let dodoEnvironment: DodoEnvironment = .dev
    
    private var baseURL: String {
        return dodoEnvironment.baseURL
    }
    
    // MARK: - Payment Processing (Clean & Simple)
    
    /// Process payment - returns result indicating if Safari is needed
    func processPayment(
        afterparty: Afterparty,
        userId: String,
        userName: String,
        userHandle: String
    ) async throws -> PaymentResult {
        
        print("🚀 PAYMENT: Processing payment for \(userHandle)")
        print("🚀 PAYMENT: Party: \(afterparty.title), Amount: $\(afterparty.ticketPrice)")
        
        isProcessingPayment = true
        defer { isProcessingPayment = false }
        
        do {
            // Create payment intent with Dodo API
            let paymentIntent = try await createDodoPaymentIntent(
                afterparty: afterparty,
                userId: userId,
                userName: userName,
                userHandle: userHandle
            )
            
            print("✅ PAYMENT: Dodo payment intent created")
            print("🌐 PAYMENT: Opening Safari for payment: \(paymentIntent.url)")
            
            // Store payment details
            await MainActor.run {
                self.paymentURL = paymentIntent.url
            }
            
            // Open Safari for payment
            if let url = URL(string: paymentIntent.url) {
                await UIApplication.shared.open(url)
            }
            
            // Start monitoring for payment completion (in background)
            Task {
                await monitorPaymentCompletion(
                    afterparty: afterparty,
                    userId: userId,
                    paymentId: paymentIntent.sessionId
                )
            }
            
            return PaymentResult(
                success: true,
                requiresWebView: true,
                paymentId: paymentIntent.sessionId
            )
            
        } catch {
            print("🔴 PAYMENT: Error creating payment intent: \(error)")
            throw error
        }
    }
    
    // MARK: - Payment Completion Monitoring
    
    /// Monitor for payment completion (simulates webhook for dev)
    private func monitorPaymentCompletion(
        afterparty: Afterparty,
        userId: String,
        paymentId: String
    ) async {
        print("👀 PAYMENT: Starting payment monitoring for \(paymentId)")
        print("👀 PAYMENT: Will complete in 10 seconds...")
        
        // In dev mode, simulate webhook after delay
        // In production, this would be handled by actual Dodo webhook
        
        // Wait for user to potentially complete payment in Safari
        try? await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds
        
        // Simulate webhook completion (since real webhook isn't set up yet)
        print("🔔 PAYMENT: 10 seconds elapsed - simulating webhook completion")
        await handlePaymentSuccess(
            afterparty: afterparty,
            userId: userId,
            paymentId: paymentId
        )
    }
    
    /// Handle successful payment (called by webhook or simulation)
    func handlePaymentSuccess(
        afterparty: Afterparty,
        userId: String,
        paymentId: String
    ) async {
        print("🎉 PAYMENT: Handling payment success")
        print("🎉 PAYMENT: User: \(userId), Payment: \(paymentId)")
        
        do {
            // Complete party membership
            let afterpartyManager = AfterpartyManager.shared
            try await afterpartyManager.completePartyMembershipAfterPayment(
                afterpartyId: afterparty.id,
                userId: userId,
                paymentIntentId: paymentId
            )
            
            print("✅ PAYMENT: Membership completed successfully")
            
            // Refresh UI
            await MainActor.run {
                NotificationCenter.default.post(
                    name: Notification.Name("PaymentCompleted"),
                    object: afterparty.id
                )
                print("🔔 PAYMENT: Posted completion notification")
            }
            
        } catch {
            print("🔴 PAYMENT: Error completing membership: \(error)")
        }
    }
    
    // MARK: - Dodo API Integration
    
    private func createDodoPaymentIntent(
        afterparty: Afterparty,
        userId: String,
        userName: String,
        userHandle: String
    ) async throws -> DodoPaymentIntent {
        
        let platformFee = afterparty.ticketPrice * 0.20
        let hostEarnings = afterparty.ticketPrice * 0.80
        
        let paymentData: [String: Any] = [
            "payment_link": true,
            "amount": afterparty.ticketPrice,
            "currency": "USD",
            "billing": [
                "city": "San Francisco",
                "country": "US",
                "state": "CA",
                "street": "123 Main St",
                "zipcode": "94102"
            ],
            "customer": [
                "email": "\(userHandle.replacingOccurrences(of: "@", with: ""))@bondfyr.com",
                "name": userName
            ],
            "product_cart": [[
                "product_id": "pdt_mPFnouIRiaQerAPmYz1gY",
                "quantity": 1
            ]],
            "return_url": "bondfyr://payment-success?afterpartyId=\(afterparty.id)&userId=\(userId)",
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
        
        var request = URLRequest(url: URL(string: "\(baseURL)/payments")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(dodoAPIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: paymentData)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 || httpResponse.statusCode == 201 else {
            throw DodoPaymentError.apiError("Failed to create payment intent")
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let paymentLink = json?["payment_link"] as? String ?? json?["url"] as? String,
              let paymentId = json?["payment_id"] as? String ?? json?["id"] as? String else {
            throw DodoPaymentError.invalidIntentResponse
        }
        
        return DodoPaymentIntent(url: paymentLink, sessionId: paymentId)
    }
}

// MARK: - Models

struct PaymentResult {
    let success: Bool
    let requiresWebView: Bool
    let paymentId: String
}

struct DodoPaymentIntent {
    let url: String
    let sessionId: String
}

enum DodoEnvironment {
    case dev
    case production
    
    var baseURL: String {
        switch self {
        case .dev: return "https://test.dodopayments.com"
        case .production: return "https://live.dodopayments.com"
        }
    }
}

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
        case .invalidURL: return "Invalid URL configuration"
        case .authenticationFailed: return "Failed to authenticate with Dodo Payments"
        case .intentCreationFailed: return "Failed to create Dodo payment intent"
        case .invalidIntentResponse: return "Invalid response from Dodo payment intent creation"
        case .confirmationFailed: return "Failed to confirm Dodo payment"
        case .refundFailed: return "Failed to process Dodo refund"
        case .networkError(let error): return "Network error: \(error.localizedDescription)"
        case .apiError(let message): return "API error: \(message)"
        }
    }
} 