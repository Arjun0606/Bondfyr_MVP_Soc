import Foundation
import SwiftUI

// MARK: - Payment Service for PayPal Integration
// TESTFLIGHT VERSION: Payment processing disabled for validation
// TODO: Restore payment processing after TestFlight validation

@MainActor
class PaymentService: ObservableObject {
    static let shared = PaymentService()
    
    @Published var isProcessingPayment = false
    @Published var paymentError: String?
    
    private init() {
        print("🧪 TestFlight: PaymentService initialized but disabled")
    }
    
    // MARK: - Configuration Validation
    var isConfigured: Bool {
        // Always return false for TestFlight version
        return false
    }
    
    // TESTFLIGHT: All payment methods disabled
    /*
    
    // MARK: - PayPal Configuration
    private let paypalClientID: String = {
        // For production, use Bundle.main.object(forInfoDictionaryKey: "PAYPAL_CLIENT_ID")
        if let clientID = Bundle.main.object(forInfoDictionaryKey: "PAYPAL_CLIENT_ID") as? String {
            return clientID
        }
        return "YOUR_SANDBOX_CLIENT_ID" // Replace with your actual PayPal Client ID
    }()
    
    private let paypalClientSecret: String = {
        if let clientSecret = Bundle.main.object(forInfoDictionaryKey: "PAYPAL_CLIENT_SECRET") as? String {
            return clientSecret
        }
        return "YOUR_SANDBOX_CLIENT_SECRET" // Replace with your actual PayPal Client Secret
    }()
    
    // Use sandbox for testing, production for live
    private let paypalEnvironment: PayPalEnvironment = .sandbox
    private let baseURL: String = "https://api.sandbox.paypal.com" // Use https://api.paypal.com for production
    
    // MARK: - Configuration Validation
    var isConfigured: Bool {
        return !paypalClientID.contains("YOUR_") && !paypalClientSecret.contains("YOUR_")
    }
    
    // MARK: - PayPal Integration Methods
    
    /// Process payment for afterparty access using PayPal
    func requestAfterpartyAccess(
        afterparty: Afterparty,
        userId: String,
        userName: String,
        userHandle: String
    ) async throws -> Bool {
        isProcessingPayment = true
        defer { isProcessingPayment = false }
        
        do {
            // 1. Get PayPal access token
            let accessToken = try await getPayPalAccessToken()
            
            // 2. Create PayPal payment order
            let paymentOrder = try await createPayPalOrder(
                afterparty: afterparty,
                userId: userId,
                userName: userName,
                userHandle: userHandle,
                accessToken: accessToken
            )
            
            // 3. Open PayPal checkout in web view or Safari
            if let approvalURL = paymentOrder.approvalURL {
                await presentPayPalCheckout(url: approvalURL)
            }
            
            // 4. Create guest request with pending status (webhook will update to paid)
            let guestRequest = GuestRequest(
                userId: userId,
                userName: userName,
                userHandle: userHandle,
                paymentStatus: .pending,
                paypalOrderId: paymentOrder.id
            )
            
            return true
            
        } catch {
            paymentError = error.localizedDescription
            throw error
        }
    }
    
    /// Get PayPal Access Token
    private func getPayPalAccessToken() async throws -> String {
        let credentials = "\(paypalClientID):\(paypalClientSecret)"
        let credentialsData = credentials.data(using: .utf8)
        let base64Credentials = credentialsData?.base64EncodedString() ?? ""
        
        var request = URLRequest(url: URL(string: "\(baseURL)/v1/oauth2/token")!)
        request.httpMethod = "POST"
        request.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = "grant_type=client_credentials".data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw PaymentError.authenticationFailed
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let accessToken = json?["access_token"] as? String else {
            throw PaymentError.invalidTokenResponse
        }
        
        return accessToken
    }
    
    /// Create PayPal Order
    private func createPayPalOrder(
        afterparty: Afterparty,
        userId: String,
        userName: String,
        userHandle: String,
        accessToken: String
    ) async throws -> PayPalOrder {
        
        let orderData: [String: Any] = [
            "intent": "CAPTURE",
            "purchase_units": [
                [
                    "reference_id": afterparty.id,
                    "description": "Access to \(afterparty.title)",
                    "custom_id": "\(userId)|\(afterparty.id)|\(userHandle)",
                    "soft_descriptor": "BONDFYR",
                    "amount": [
                        "currency_code": "USD",
                        "value": String(format: "%.2f", afterparty.ticketPrice)
                    ],
                    "items": [
                        [
                            "name": afterparty.title,
                            "description": "Afterparty access at \(afterparty.locationName)",
                            "sku": "PARTY-\(afterparty.id)",
                            "unit_amount": [
                                "currency_code": "USD",
                                "value": String(format: "%.2f", afterparty.ticketPrice)
                            ],
                            "quantity": "1",
                            "category": "DIGITAL_GOODS"
                        ]
                    ]
                ]
            ],
            "application_context": [
                "cancel_url": "bondfyr://payment-cancelled",
                "return_url": "bondfyr://payment-success",
                "brand_name": "Bondfyr",
                "locale": "en-US",
                "landing_page": "BILLING",
                "shipping_preference": "NO_SHIPPING",
                "user_action": "PAY_NOW"
            ]
        ]
        
        var request = URLRequest(url: URL(string: "\(baseURL)/v2/checkout/orders")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        request.httpBody = try JSONSerialization.data(withJSONObject: orderData)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 201 else {
            throw PaymentError.orderCreationFailed
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let orderId = json?["id"] as? String,
              let links = json?["links"] as? [[String: Any]] else {
            throw PaymentError.invalidOrderResponse
        }
        
        // Find approval URL
        var approvalURL: String?
        for link in links {
            if let rel = link["rel"] as? String, rel == "approve",
               let href = link["href"] as? String {
                approvalURL = href
                break
            }
        }
        
        return PayPalOrder(id: orderId, approvalURL: approvalURL)
    }
    
    /// Process refund when host cancels party
    func processRefund(orderID: String) async throws {
        let accessToken = try await getPayPalAccessToken()
        
        // First, get the order details to find the capture ID
        var getOrderRequest = URLRequest(url: URL(string: "\(baseURL)/v2/checkout/orders/\(orderID)")!)
        getOrderRequest.httpMethod = "GET"
        getOrderRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        getOrderRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (orderData, orderResponse) = try await URLSession.shared.data(for: getOrderRequest)
        
        guard let httpOrderResponse = orderResponse as? HTTPURLResponse,
              httpOrderResponse.statusCode == 200 else {
            throw PaymentError.refundFailed
        }
        
        let orderJson = try JSONSerialization.jsonObject(with: orderData) as? [String: Any]
        guard let purchaseUnits = orderJson?["purchase_units"] as? [[String: Any]],
              let firstUnit = purchaseUnits.first,
              let payments = firstUnit["payments"] as? [String: Any],
              let captures = payments["captures"] as? [[String: Any]],
              let firstCapture = captures.first,
              let captureId = firstCapture["id"] as? String else {
            throw PaymentError.refundFailed
        }
        
        // Create refund
        let refundData: [String: Any] = [
            "amount": [
                "value": firstCapture["amount"]?["value"] as? String ?? "0.00",
                "currency_code": "USD"
            ],
            "note_to_payer": "Afterparty cancelled by host"
        ]
        
        var refundRequest = URLRequest(url: URL(string: "\(baseURL)/v2/payments/captures/\(captureId)/refund")!)
        refundRequest.httpMethod = "POST"
        refundRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        refundRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        refundRequest.setValue("return=representation", forHTTPHeaderField: "Prefer")
        refundRequest.httpBody = try JSONSerialization.data(withJSONObject: refundData)
        
        let (_, refundResponse) = try await URLSession.shared.data(for: refundRequest)
        
        guard let httpRefundResponse = refundResponse as? HTTPURLResponse,
              httpRefundResponse.statusCode == 201 else {
            throw PaymentError.refundFailed
        }
        
        print("✅ PayPal refund processed successfully for order: \(orderID)")
    }
    
    /// Present PayPal checkout to user
    private func presentPayPalCheckout(url: String) async {
        await MainActor.run {
            if let checkoutURL = URL(string: url) {
                UIApplication.shared.open(checkoutURL)
            }
        }
    }
    
    /// Capture PayPal payment after user approval
    func capturePayPalPayment(orderId: String) async throws -> Bool {
        let accessToken = try await getPayPalAccessToken()
        
        var request = URLRequest(url: URL(string: "\(baseURL)/v2/checkout/orders/\(orderId)/capture")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 201 else {
            throw PaymentError.captureFailure
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let status = json?["status"] as? String, status == "COMPLETED" else {
            throw PaymentError.captureFailure
        }
        
        print("✅ PayPal payment captured successfully for order: \(orderId)")
        return true
    }
    
    /// Handle PayPal payment success (called from deep link)
    func handlePaymentSuccess(payerId: String, paymentId: String, token: String) async {
        do {
            // Capture the payment
            let success = try await capturePayPalPayment(orderId: paymentId)
            if success {
                print("✅ Payment captured successfully")
                // Update UI or navigate user
                await MainActor.run {
                    // Notify that payment was successful
                    NotificationCenter.default.post(name: .paymentSuccess, object: paymentId)
                }
            }
        } catch {
            print("❌ Failed to capture payment: \(error)")
            await MainActor.run {
                paymentError = error.localizedDescription
                NotificationCenter.default.post(name: .paymentError, object: error)
            }
        }
    }
    
    /// Process webhook from PayPal
    static func handleWebhook(payload: [String: Any]) async {
        // This would be called from your Firebase Cloud Function
        guard let eventType = payload["event_type"] as? String,
              let resource = payload["resource"] as? [String: Any] else {
            return
        }
        
        switch eventType {
        case "PAYMENT.CAPTURE.COMPLETED":
            await handlePaymentCaptured(resource: resource)
        case "PAYMENT.CAPTURE.REFUNDED":
            await handlePaymentRefunded(resource: resource)
        case "CHECKOUT.ORDER.APPROVED":
            await handleOrderApproved(resource: resource)
        default:
            print("Unhandled PayPal webhook event: \(eventType)")
        }
    }
    
    /// Handle successful payment capture webhook
    private static func handlePaymentCaptured(resource: [String: Any]) async {
        guard let customId = resource["custom_id"] as? String else { return }
        
        // Parse custom_id: "userId|afterpartyId|userHandle"
        let components = customId.components(separatedBy: "|")
        guard components.count == 3 else { return }
        
        let userId = components[0]
        let afterpartyId = components[1]
        let userHandle = components[2]
        
        // Update payment status in Firestore
        // This would typically be done in a Firebase Cloud Function
        print("✅ PayPal payment captured for user \(userId) in afterparty \(afterpartyId)")
    }
    
    /// Handle order approved webhook
    private static func handleOrderApproved(resource: [String: Any]) async {
        // Handle order approval
        print("✅ PayPal order approved: \(resource)")
    }
    
    /// Handle refund webhook
    private static func handlePaymentRefunded(resource: [String: Any]) async {
        // Handle refund processing
        print("✅ PayPal payment refunded: \(resource)")
    }
    

    
    /// Calculate platform fee (12%)
    func calculateBondfyrFee(from totalAmount: Double) -> Double {
        return totalAmount * 0.12
    }
    
    /// Calculate host earnings (88%)
    func calculateHostEarnings(from totalAmount: Double) -> Double {
        return totalAmount * 0.88
    }
    */
}

// MARK: - PayPal Environment
enum PayPalEnvironment {
    case sandbox
    case production
    
    var baseURL: String {
        switch self {
        case .sandbox:
            return "https://api.sandbox.paypal.com"
        case .production:
            return "https://api.paypal.com"
        }
    }
}

// MARK: - PayPal Models
struct PayPalOrder: Codable {
    let id: String
    let approvalURL: String?
}

// MARK: - Payment Error Types
enum PaymentError: LocalizedError {
    case invalidURL
    case authenticationFailed
    case invalidTokenResponse
    case orderCreationFailed
    case invalidOrderResponse
    case captureFailure
    case refundFailed
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL configuration"
        case .authenticationFailed:
            return "Failed to authenticate with PayPal"
        case .invalidTokenResponse:
            return "Invalid response from PayPal authentication"
        case .orderCreationFailed:
            return "Failed to create PayPal order"
        case .invalidOrderResponse:
            return "Invalid response from PayPal order creation"
        case .captureFailure:
            return "Failed to capture PayPal payment"
        case .refundFailed:
            return "Failed to process PayPal refund"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
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
    let paypalOrderId: String?
    
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

// MARK: - Notification Extensions

extension Notification.Name {
    static let paymentSuccess = Notification.Name("paymentSuccess")
    static let paymentError = Notification.Name("paymentError")
    static let paymentCancelled = Notification.Name("paymentCancelled")
}

// MARK: - Extensions

extension Date {
    var iso8601String: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: self)
    }
} 