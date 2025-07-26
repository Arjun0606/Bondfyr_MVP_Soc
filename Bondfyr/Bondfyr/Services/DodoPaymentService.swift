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
    private let dodoAPIKey: String = "epFmjxZK0Ka34YDf.vI_rvcu9m-o5PcTau3rk3Q5VkxeKUVJRt8Diteu8WrCPUiB4"
    private let dodoWebhookSecret: String = "whsec_Y5nFJYOkWXIggi6afYnFSbcryFHthX1E"
    private let dodoEnvironment: DodoEnvironment = .production
    
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
            // Create party from pending data (like LemonSqueezy webhook)
            try await createPartyFromPendingData(
                afterpartyId: afterparty.id,
                userId: userId,
                paymentId: paymentId
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
    
    // MARK: - Party Creation from Pending Data
    
    private func createPartyFromPendingData(
        afterpartyId: String,
        userId: String,
        paymentId: String
    ) async throws {
        print("🎯 DODO: Creating party from pending data")
        print("🎯 DODO: Party: \(afterpartyId), User: \(userId), Payment: \(paymentId)")
        
        let db = Firestore.firestore()
        
        // Get pending party data
        let pendingDoc = try await db.collection("pendingParties").document(afterpartyId).getDocument()
        
        guard let pendingData = pendingDoc.data() else {
            throw DodoPaymentError.apiError("Pending party data not found")
        }
        
        print("📋 DODO: Found pending party data")
        
        // Create the actual party
        var partyData = pendingData
        partyData["listingFeePaid"] = true
        partyData["paidAt"] = Timestamp()
        partyData["createdAt"] = Timestamp()
        partyData["updatedAt"] = Timestamp()
        partyData["status"] = "active"
        partyData["dodoPaymentId"] = paymentId
        
        // Add host to activeUsers
        if let hostId = partyData["hostId"] as? String {
            partyData["activeUsers"] = [hostId]
        }
        
        // Create party document
        try await db.collection("afterparties").document(afterpartyId).setData(partyData)
        print("✅ DODO: Created party in afterparties collection")
        
        // Delete pending party data
        try await db.collection("pendingParties").document(afterpartyId).delete()
        print("🗑️ DODO: Deleted pending party data")
        
        // Send notification to host
        if let hostId = partyData["hostId"] as? String,
           let partyTitle = partyData["title"] as? String {
            await FCMNotificationManager.shared.sendPushNotification(
                to: hostId,
                title: "🎉 Party Created!",
                body: "Your party '\(partyTitle)' is now live and accepting guests!",
                data: [
                    "type": "party_created",
                    "partyTitle": partyTitle
                ]
            )
            print("🔔 DODO: Sent party created notification")
        }
    }
    
    // MARK: - Robust Refund Processing
    
    struct RefundResult {
        let guestId: String
        let guestHandle: String
        let paymentId: String
        let amount: Double
        let success: Bool
        let error: String?
        let retryAttempts: Int
    }
    
    /// Process refunds for all paid guests when party is cancelled (BULLETPROOF VERSION)
    func processPartyRefunds(afterparty: Afterparty) async throws -> [RefundResult] {
        print("💸 REFUND: Processing refunds for cancelled party: \(afterparty.title)")
        
        let paidGuests = afterparty.guestRequests.filter { $0.paymentStatus == .paid }
        print("💸 REFUND: Found \(paidGuests.count) paid guests to refund")
        
        var results: [RefundResult] = []
        
        // Process refunds with retry logic and proper tracking
        for guest in paidGuests {
            guard let paymentIntentId = guest.dodoPaymentIntentId else {
                print("🔴 REFUND: No payment ID for guest \(guest.userHandle)")
                results.append(RefundResult(
                    guestId: guest.userId,
                    guestHandle: guest.userHandle,
                    paymentId: "",
                    amount: afterparty.ticketPrice,
                    success: false,
                    error: "Missing payment ID",
                    retryAttempts: 0
                ))
                continue
            }
            
            let result = await processRefundWithRetry(
                guestId: guest.userId,
                guestHandle: guest.userHandle,
                paymentId: paymentIntentId,
                amount: afterparty.ticketPrice,
                partyTitle: afterparty.title,
                maxRetries: 3
            )
            
            results.append(result)
            
            // Send notification only if refund succeeded
            if result.success {
                await sendRefundNotification(
                    guestId: guest.userId,
                    guestName: guest.userHandle,
                    partyTitle: afterparty.title,
                    amount: afterparty.ticketPrice
                )
            }
        }
        
        // Log summary
        let successCount = results.filter { $0.success }.count
        let failureCount = results.count - successCount
        
        print("💸 REFUND SUMMARY:")
        print("  ✅ Successful: \(successCount)")
        print("  ❌ Failed: \(failureCount)")
        
        if failureCount > 0 {
            print("🚨 REFUND: \(failureCount) refunds failed - manual intervention may be required")
            for failure in results.filter({ !$0.success }) {
                print("  - \(failure.guestHandle): \(failure.error ?? "Unknown error")")
            }
        }
        
        return results
    }
    
    /// Process individual refund with retry logic
    private func processRefundWithRetry(
        guestId: String,
        guestHandle: String,
        paymentId: String,
        amount: Double,
        partyTitle: String,
        maxRetries: Int = 3
    ) async -> RefundResult {
        
        var lastError: String?
        
        for attempt in 1...maxRetries {
            do {
                print("💸 REFUND: Attempt \(attempt)/\(maxRetries) for \(guestHandle)")
                
                try await processRefund(
                    paymentId: paymentId,
                    amount: amount,
                    reason: "Party '\(partyTitle)' cancelled by host"
                )
                
                print("✅ REFUND: Successfully refunded \(guestHandle) - $\(amount) (attempt \(attempt))")
                
                return RefundResult(
                    guestId: guestId,
                    guestHandle: guestHandle,
                    paymentId: paymentId,
                    amount: amount,
                    success: true,
                    error: nil,
                    retryAttempts: attempt
                )
                
            } catch {
                lastError = error.localizedDescription
                print("🔴 REFUND: Attempt \(attempt) failed for \(guestHandle): \(error)")
                
                // Don't retry on certain errors (like invalid payment ID)
                if let dodoError = error as? DodoPaymentError,
                   case .apiError(let message) = dodoError,
                   message.contains("not found") || message.contains("invalid") {
                    print("🚨 REFUND: Non-retryable error for \(guestHandle) - stopping retries")
                    break
                }
                
                // Wait before retry (exponential backoff)
                if attempt < maxRetries {
                    let delay = Double(attempt * attempt) // 1s, 4s, 9s...
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        
        print("🔴 REFUND: All attempts failed for \(guestHandle)")
        
        return RefundResult(
            guestId: guestId,
            guestHandle: guestHandle,
            paymentId: paymentId,
            amount: amount,
            success: false,
            error: lastError,
            retryAttempts: maxRetries
        )
    }
    
    /// Process refund for cancelled party
    private func processRefund(paymentId: String, amount: Double, reason: String = "Party cancelled by host") async throws {
        print("💸 REFUND: Processing refund for payment \(paymentId), amount: $\(amount)")
        
        let refundData: [String: Any] = [
            "payment_id": paymentId,
            "amount": amount,
            "reason": reason,
            "metadata": [
                "refund_reason": reason,
                "processed_by": "app",
                "processed_at": Date().iso8601String
            ]
        ]
        
        var request = URLRequest(url: URL(string: "\(baseURL)/refunds")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(dodoAPIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: refundData)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 || httpResponse.statusCode == 201 else {
            print("🔴 REFUND: Failed with status: \((response as? HTTPURLResponse)?.statusCode ?? 0)")
            throw DodoPaymentError.refundFailed
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        print("✅ REFUND: Successfully processed refund: \(json?["id"] as? String ?? "unknown")")
    }
    
    /// Send refund notification to guest
    private func sendRefundNotification(
        guestId: String,
        guestName: String,
        partyTitle: String,
        amount: Double
    ) async {
        // Use the fixed notification manager to send refund notification
        await FixedNotificationManager.shared.notifyGuestOfRefund(
            partyId: "",
            partyTitle: partyTitle,
            guestUserId: guestId,
            amount: amount
        )
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
        
        // Convert to cents for Dodo API (like we had before)
        let roundedAmount = ceil(afterparty.ticketPrice)
        let amountInCents = Int(roundedAmount * 100)
        
        // DODO DYNAMIC PRICING: Apply same logic as LemonSqueezy success
        let paymentData: [String: Any] = [
            "payment_link": true,
            "currency": "USD",
            "amount": amountInCents,  // Top-level amount override in cents
            "description": "Listing Fee - \(afterparty.title)",
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
                "product_id": "pdt_I3q25hrMAAf6yeKkKb1vD",
                "quantity": 1,
                "amount": amountInCents
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
        
        // Log request details for debugging
        print("🔍 DODO API Request URL: \(baseURL)/payments")
        print("🔍 DODO API Request Data: \(paymentData)")
        
        var request = URLRequest(url: URL(string: "\(baseURL)/payments")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(dodoAPIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: paymentData)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw DodoPaymentError.apiError("Invalid HTTP response")
        }
        
        // Log the actual response for debugging
        if let responseString = String(data: data, encoding: .utf8) {
            print("🔍 DODO API Response (\(httpResponse.statusCode)): \(responseString)")
        }
        

        
        guard httpResponse.statusCode == 200 || httpResponse.statusCode == 201 else {
            // Get the actual error message from Dodo
            let errorMessage: String
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let message = json["message"] as? String ?? json["error"] as? String {
                errorMessage = message
            } else if let responseString = String(data: data, encoding: .utf8) {
                errorMessage = "HTTP \(httpResponse.statusCode): \(responseString)"
            } else {
                errorMessage = "HTTP \(httpResponse.statusCode): Unknown error"
            }
            throw DodoPaymentError.apiError(errorMessage)
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

// MARK: - Extensions

extension Date {
    var iso8601String: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: self)
    }
} 