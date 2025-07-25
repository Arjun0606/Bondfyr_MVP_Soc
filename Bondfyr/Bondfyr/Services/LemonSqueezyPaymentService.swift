import Foundation
import SwiftUI
import FirebaseFirestore

// MARK: - LemonSqueezy Payment Service (Clean & Working!)

@MainActor
class LemonSqueezyPaymentService: ObservableObject {
    static let shared = LemonSqueezyPaymentService()
    
    @Published var isProcessingPayment = false
    @Published var paymentError: String?
    @Published var checkoutURL: String?
    
    private init() {}
    
    // MARK: - Configuration
    private let storeId = "194650"
    private let apiKey = "eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9.eyJhdWQiOiI5NGQ1OWNlZi1kYmI4LTRlYTUtYjE3OC1kMjU0MGZjZDY5MTkiLCJqdGkiOiJkMTRlZjFjOTZlOWZmYzJlOWU4ZWYyNTU5Zjg4ZjUwOWVmYzI4ZjBiZjVkN2U5YzU0M2NhYjdkOGRiNjliMzk1YWI2M2UxZGFhMTY5MGQ1MyIsImlhdCI6MTc1MzQzNTg3NC41MjY5NzYsIm5iZiI6MTc1MzQzNTg3NC41MjY5NzksImV4cCI6MjA2ODk2ODY3NC40ODczNzQsInN1YiI6IjUwOTk4NjQiLCJzY29wZXMiOltdfQ.lEBsgmhKJSk1uPv188OvIDtHWCUU9gqdrq3Y7XS77wiZrLX_WkDdjzn3Bnl_478KOj5G86dCJ2bJwKqGdiJ9PTAinDMnPLmCISC9TigBE8MXh92IPryqwYjN1LqZ-0GG_jajHah56KOcLkKLuZfaZ5hWvmjciegERgx7ob_8fuq41oKiTFKzf5SAuSxx2sR3MO1evw_rP3oOSjmZ0aAVv4CAVxEeeTMVFcuzFxs9ac4cK9qw75DxMm4QOjzb_kQ8LbrrSr6EgEly__6aEPFOd8L259V_UvKzDWMJg8c8VEQ3cJZ4so6lYXCcEve3jriCcsAzOKmeU_0dF4rf5rPVPLjz_ht8TroQ6osv0skoXddOjyDSIiAy4kCLQ9kifpA4bFRRA-U8rHuCocJtnsKLKbWCLerMqcT201j8xXtFaRVJBBGPnS8rxNX_Zq1e8cBISiJBhDUitDnhck2cDpMT7Z2FCDxiHEUBSGaj6p79TVN3Xgi8rl7E64szdgXstqkS"
    private let variantId = "918065"
    private let baseURL = "https://api.lemonsqueezy.com/v1"
    
    // MARK: - Payment Processing (Clean & Simple)
    
    /// Process payment - creates checkout and opens in Safari
    func processPayment(
        afterparty: Afterparty,
        userId: String,
        userName: String,
        userHandle: String
    ) async throws -> PaymentResult {
        
        print("🍋 LEMONSQUEEZY: Processing payment for \(userHandle)")
        print("🍋 LEMONSQUEEZY: Party: \(afterparty.title), Amount: $\(afterparty.ticketPrice)")
        
        isProcessingPayment = true
        defer { isProcessingPayment = false }
        
        do {
            // Create checkout with LemonSqueezy API
            let checkout = try await createCheckout(
                afterparty: afterparty,
                userId: userId,
                userName: userName,
                userHandle: userHandle
            )
            
            print("✅ LEMONSQUEEZY: Checkout created successfully")
            print("🌐 LEMONSQUEEZY: Opening Safari for payment: \(checkout.url)")
            
                        // Store checkout URL and map checkout ID to party data
            await MainActor.run {
                self.checkoutURL = checkout.url
            }
            
            // Store mapping in Firebase for webhook lookup
            try await storeCheckoutMapping(
                checkoutId: checkout.id,
                afterpartyId: afterparty.id,
                userId: userId,
                userName: userName,
                userHandle: userHandle
            )
            
            // Open Safari for payment
                if let url = URL(string: checkout.url) {
            await UIApplication.shared.open(url)
        }
            
            return PaymentResult(
                success: true,
                requiresWebView: true,
                paymentId: checkout.id
            )
            
        } catch {
            print("🔴 LEMONSQUEEZY: Error creating checkout: \(error)")
            throw error
        }
    }
    
    // MARK: - Checkout Mapping Storage
    
    private func storeCheckoutMapping(
        checkoutId: String,
        afterpartyId: String,
        userId: String,
        userName: String,
        userHandle: String
    ) async throws {
        let db = Firestore.firestore()
        
        let mappingData: [String: Any] = [
            "checkoutId": checkoutId,
            "afterpartyId": afterpartyId,
            "userId": userId,
            "userName": userName,
            "userHandle": userHandle,
            "createdAt": Timestamp(),
            "status": "pending"
        ]
        
        try await db.collection("checkoutMappings").document(checkoutId).setData(mappingData)
        print("✅ LEMONSQUEEZY: Stored checkout mapping for \(checkoutId)")
    }
    
    // MARK: - LemonSqueezy API Integration
    
    private func createCheckout(
        afterparty: Afterparty,
        userId: String,
        userName: String,
        userHandle: String
    ) async throws -> LemonSqueezyCheckout {
        
        let platformFee = afterparty.ticketPrice * 0.20
        let hostEarnings = afterparty.ticketPrice * 0.80
        
        // Round up listing fee to avoid decimal issues
        let roundedAmount = ceil(afterparty.ticketPrice)
        
        // Convert to cents (LemonSqueezy uses cents)
        let amountInCents = Int(roundedAmount * 100)
        
        let checkoutData: [String: Any] = [
            "data": [
                "type": "checkouts",
                "attributes": [
                    "checkout_data": [
                        "email": "\(userHandle.replacingOccurrences(of: "@", with: ""))@bondfyr.com",
                        "name": userName,
                        "custom": [
                            "afterpartyId": afterparty.id,
                            "userId": userId,
                            "userName": userName,
                            "userHandle": userHandle,
                            "hostId": afterparty.userId,
                            "platformFee": String(format: "%.2f", platformFee),
                            "hostEarnings": String(format: "%.2f", hostEarnings)
                        ],
                        "variant_quantities": [
                            [
                                "variant_id": Int(variantId) ?? 918065,
                                "quantity": 1,
                                "custom_price": amountInCents
                            ]
                        ]
                    ],
                                                                   "product_options": [
                        "name": "Bondfyr Listing Fee - \(afterparty.title)",
                        "description": "Listing fee for hosting party: \(afterparty.title)",
                        "media": []
                    ],
                    "custom_price": amountInCents,
                    "checkout_options": [
                        "embed": false,
                        "media": false,
                        "logo": true,
                        "desc": true,
                        "discount": false,
                        "dark": false,
                        "subscription_preview": false,
                        "button_color": "#7C3AED"
                    ],
                    "expires_at": nil,
                    "preview": false,
                    "test_mode": true
                ],
                "relationships": [
                    "store": [
                        "data": [
                            "type": "stores",
                            "id": storeId
                        ]
                    ],
                    "variant": [
                        "data": [
                            "type": "variants",
                            "id": variantId
                        ]
                    ]
                ]
            ]
        ]
        
        // Log request details for debugging
        print("🔍 LEMONSQUEEZY API Request URL: \(baseURL)/checkouts")
        print("🔍 LEMONSQUEEZY Calculated Amount: $\(afterparty.ticketPrice) -> \(amountInCents) cents")
        print("🔍 LEMONSQUEEZY API Request Data: \(checkoutData)")
        
        var request = URLRequest(url: URL(string: "\(baseURL)/checkouts")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.api+json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/vnd.api+json", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONSerialization.data(withJSONObject: checkoutData)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LemonSqueezyError.invalidResponse
        }
        
        // Log the actual response for debugging
        if let responseString = String(data: data, encoding: .utf8) {
            print("🔍 LEMONSQUEEZY API Response (\(httpResponse.statusCode)): \(responseString)")
        }
        
                    guard httpResponse.statusCode == 200 || httpResponse.statusCode == 201 else {
                // Get the actual error message from LemonSqueezy
                let errorMessage: String
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    print("🔴 LEMONSQUEEZY ERROR JSON: \(json)")
                    if let errors = json["errors"] as? [[String: Any]],
                       let firstError = errors.first,
                       let detail = firstError["detail"] as? String {
                        errorMessage = detail
                    } else {
                        errorMessage = "HTTP \(httpResponse.statusCode): \(json)"
                    }
                } else if let responseString = String(data: data, encoding: .utf8) {
                    errorMessage = "HTTP \(httpResponse.statusCode): \(responseString)"
                } else {
                    errorMessage = "HTTP \(httpResponse.statusCode): Unknown error"
                }
                throw LemonSqueezyError.apiError(errorMessage)
            }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let dataObject = json?["data"] as? [String: Any],
              let attributes = dataObject["attributes"] as? [String: Any],
              let checkoutURL = attributes["url"] as? String,
              let checkoutId = dataObject["id"] as? String else {
            throw LemonSqueezyError.invalidCheckoutResponse
        }
        
        return LemonSqueezyCheckout(url: checkoutURL, id: checkoutId)
    }
    
    // MARK: - Webhook Handler
    
    /// Handle successful payment (called by webhook)
    func handlePaymentSuccess(
        afterpartyId: String,
        userId: String,
        checkoutId: String
    ) async {
        print("🍋 LEMONSQUEEZY: Handling payment success")
        print("🍋 LEMONSQUEEZY: Party: \(afterpartyId), User: \(userId), Checkout: \(checkoutId)")
        
        do {
            // Complete party creation from pending data
            try await createPartyFromPendingData(
                afterpartyId: afterpartyId,
                checkoutId: checkoutId
            )
            
            print("✅ LEMONSQUEEZY: Party created successfully from pending data")
            
            // Refresh UI
            await MainActor.run {
                NotificationCenter.default.post(
                    name: Notification.Name("PaymentCompleted"),
                    object: afterpartyId
                )
                print("🔔 LEMONSQUEEZY: Posted completion notification")
            }
            
        } catch {
            print("🔴 LEMONSQUEEZY: Error completing party creation: \(error)")
        }
    }
    
    private func createPartyFromPendingData(
        afterpartyId: String,
        checkoutId: String
    ) async throws {
        let db = Firestore.firestore()
        
        // Get pending party data
        let pendingDoc = try await db.collection("pendingParties").document(afterpartyId).getDocument()
        
        guard let pendingData = pendingDoc.data() else {
            throw LemonSqueezyError.pendingPartyNotFound
        }
        
        // Create the actual party
        var partyData = pendingData
        partyData["listingFeePaid"] = true
        partyData["paidAt"] = Timestamp()
        partyData["createdAt"] = Timestamp()
        partyData["updatedAt"] = Timestamp()
        partyData["status"] = "active"
        partyData["lemonSqueezyCheckoutId"] = checkoutId
        
        // Add host to activeUsers
        if let hostId = partyData["hostId"] as? String {
            partyData["activeUsers"] = [hostId]
        }
        
        // Create party document
        try await db.collection("afterparties").document(afterpartyId).setData(partyData)
        
        // Delete pending party data
        try await db.collection("pendingParties").document(afterpartyId).delete()
        
        // Send notification to host
        if let hostId = partyData["hostId"] as? String,
           let partyTitle = partyData["title"] as? String {
            await sendPartyCreatedNotification(hostId: hostId, partyTitle: partyTitle)
        }
    }
    
    private func sendPartyCreatedNotification(hostId: String, partyTitle: String) async {
        // Use FCM to notify host that party was created
        await FCMNotificationManager.shared.sendPushNotification(
            to: hostId,
            title: "🎉 Party Created!",
            body: "Your party '\(partyTitle)' is now live and accepting guests!",
            data: [
                "type": "party_created",
                "partyTitle": partyTitle
            ]
        )
    }
}

// MARK: - Models

struct LemonSqueezyCheckout {
    let url: String
    let id: String
}

enum LemonSqueezyError: LocalizedError {
    case invalidResponse
    case invalidCheckoutResponse
    case pendingPartyNotFound
    case networkError(Error)
    case apiError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Invalid response from LemonSqueezy"
        case .invalidCheckoutResponse: return "Invalid checkout response from LemonSqueezy"
        case .pendingPartyNotFound: return "Pending party data not found"
        case .networkError(let error): return "Network error: \(error.localizedDescription)"
        case .apiError(let message): return "LemonSqueezy API error: \(message)"
        }
    }
}

// MARK: - PaymentResult struct removed (shared with DodoPaymentService) 