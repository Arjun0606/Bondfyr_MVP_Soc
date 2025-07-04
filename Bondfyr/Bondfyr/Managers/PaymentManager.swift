import Foundation
import Firebase
import FirebaseFunctions

enum PaymentMethod: String, CaseIterable {
    case free = "free"
    case stripe = "stripe"
}

enum PaymentError: Error {
    case userCountFetchFailed
    case paymentIntentCreationFailed
    case paymentProcessingFailed
    case stripeNotConfigured
    case invalidAmount
    
    var localizedDescription: String {
        switch self {
        case .userCountFetchFailed:
            return "Failed to determine payment method"
        case .paymentIntentCreationFailed:
            return "Failed to create payment intent"
        case .paymentProcessingFailed:
            return "Payment processing failed"
        case .stripeNotConfigured:
            return "Stripe payment not available"
        case .invalidAmount:
            return "Invalid payment amount"
        }
    }
}

struct PaymentConfiguration {
    let userCount: Int
    let paymentMethod: PaymentMethod
    let threshold: Int
}

class PaymentManager: ObservableObject {
    static let shared = PaymentManager()
    
    @Published var currentConfiguration: PaymentConfiguration?
    @Published var isLoading = false
    
    private let functions = Functions.functions()
    private let db = Firestore.firestore()
    
    private init() {}
    
    // MARK: - Payment Configuration
    
    func fetchPaymentConfiguration() async throws -> PaymentConfiguration {
        isLoading = true
        defer { isLoading = false }
        
        let getUserCount = functions.httpsCallable("getUserCount")
        
        do {
            let result = try await getUserCount.call()
            
            guard let data = result.data as? [String: Any],
                  let userCount = data["userCount"] as? Int,
                  let paymentMethodString = data["paymentMethod"] as? String,
                  let threshold = data["threshold"] as? Int,
                  let paymentMethod = PaymentMethod(rawValue: paymentMethodString) else {
                throw PaymentError.userCountFetchFailed
            }
            
            let configuration = PaymentConfiguration(
                userCount: userCount,
                paymentMethod: paymentMethod,
                threshold: threshold
            )
            
            await MainActor.run {
                self.currentConfiguration = configuration
            }
            
            return configuration
        } catch {
            throw PaymentError.userCountFetchFailed
        }
    }
    
    // MARK: - Payment Processing
    
    func processPayment(for ticket: TicketModel, amount: Int? = nil) async throws -> String {
        // First, get current payment configuration
        let config = try await fetchPaymentConfiguration()
        
        switch config.paymentMethod {
        case .free:
            return try await processFreePayment(for: ticket)
        case .stripe:
            guard let amount = amount, amount > 0 else {
                throw PaymentError.invalidAmount
            }
            return try await processStripePayment(for: ticket, amount: amount)
        }
    }
    
    private func processFreePayment(for ticket: TicketModel) async throws -> String {
        let processPayment = functions.httpsCallable("processPayment")
        
        let ticketData: [String: Any] = [
            "event": ticket.event,
            "tier": ticket.tier,
            "count": ticket.count,
            "genders": ticket.genders,
            "prCode": ticket.prCode,
            "phoneNumber": ticket.phoneNumber,
            "ticketId": ticket.ticketId
        ]
        
        let data: [String: Any] = [
            "ticketData": ticketData,
            "paymentMethod": nil
        ]
        
        do {
            let result = try await processPayment.call(data)
            
            guard let responseData = result.data as? [String: Any],
                  let success = responseData["success"] as? Bool,
                  let ticketId = responseData["ticketId"] as? String,
                  success else {
                throw PaymentError.paymentProcessingFailed
            }
            
            return ticketId
        } catch {
            throw PaymentError.paymentProcessingFailed
        }
    }
    
    private func processStripePayment(for ticket: TicketModel, amount: Int) async throws -> String {
        // Create payment intent
        let paymentIntentId = try await createStripePaymentIntent(amount: amount)
        
        // TODO: Integrate with Stripe iOS SDK for actual payment processing
        // For now, we'll simulate a successful payment
        // In a real implementation, you would:
        // 1. Use Stripe iOS SDK to collect payment
        // 2. Confirm payment intent
        // 3. Then call processPayment with the confirmed payment intent
        
        let processPayment = functions.httpsCallable("processPayment")
        
        let ticketData: [String: Any] = [
            "event": ticket.event,
            "tier": ticket.tier,
            "count": ticket.count,
            "genders": ticket.genders,
            "prCode": ticket.prCode,
            "phoneNumber": ticket.phoneNumber,
            "ticketId": ticket.ticketId
        ]
        
        let paymentMethodData: [String: Any] = [
            "stripePaymentIntentId": paymentIntentId
        ]
        
        let data: [String: Any] = [
            "ticketData": ticketData,
            "paymentMethod": paymentMethodData
        ]
        
        do {
            let result = try await processPayment.call(data)
            
            guard let responseData = result.data as? [String: Any],
                  let success = responseData["success"] as? Bool,
                  let ticketId = responseData["ticketId"] as? String,
                  success else {
                throw PaymentError.paymentProcessingFailed
            }
            
            return ticketId
        } catch {
            throw PaymentError.paymentProcessingFailed
        }
    }
    
    private func createStripePaymentIntent(amount: Int) async throws -> String {
        let createPaymentIntent = functions.httpsCallable("createPaymentIntent")
        
        let data: [String: Any] = [
            "amount": amount,
            "currency": "usd"
        ]
        
        do {
            let result = try await createPaymentIntent.call(data)
            
            guard let responseData = result.data as? [String: Any],
                  let paymentIntentId = responseData["paymentIntentId"] as? String else {
                throw PaymentError.paymentIntentCreationFailed
            }
            
            return paymentIntentId
        } catch {
            throw PaymentError.paymentIntentCreationFailed
        }
    }
    
    // MARK: - Utility Methods
    
    func shouldUseStripePayment() async -> Bool {
        do {
            let config = try await fetchPaymentConfiguration()
            return config.paymentMethod == .stripe
        } catch {
            return false
        }
    }
    
    func getUserCountStatus() async -> (current: Int, threshold: Int, remaining: Int)? {
        do {
            let config = try await fetchPaymentConfiguration()
            let remaining = max(0, config.threshold - config.userCount)
            return (config.userCount, config.threshold, remaining)
        } catch {
            return nil
        }
    }
}