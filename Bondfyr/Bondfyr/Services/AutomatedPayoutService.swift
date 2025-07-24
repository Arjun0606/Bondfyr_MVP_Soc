import Foundation
import FirebaseFirestore

// MARK: - Automated Payout Service

@MainActor
class AutomatedPayoutService: ObservableObject {
    static let shared = AutomatedPayoutService()
    
    private let db = Firestore.firestore()
    
    // Payout configuration
    private let minimumPayoutAmount: Double = 10.0
    private let payoutSchedule = PayoutSchedule.weekly // Every Friday
    
    enum PayoutSchedule {
        case weekly    // Every Friday
        case biweekly  // Every other Friday  
        case monthly   // 1st of month
    }
    
    private init() {
        setupAutomatedPayouts()
    }
    
    /// Setup automated payout schedule
    private func setupAutomatedPayouts() {
        // In production, this would be a Firebase Cloud Function
        // triggered by Cloud Scheduler (cron job)
        
        print("🤖 AUTOMATION: Automated payout service initialized")
        print("🤖 AUTOMATION: Payouts run every Friday at 6 PM PST")
        print("🤖 AUTOMATION: Minimum payout: $\(minimumPayoutAmount)")
    }
    
    /// Process automated weekly payouts (called by Firebase Cloud Function)
    func processWeeklyPayouts() async throws {
        print("🤖 AUTOMATION: Starting weekly payout process...")
        
        // Get all hosts with pending earnings above minimum
        let hostsToPayOut = try await getHostsReadyForPayout()
        
        print("🤖 AUTOMATION: Found \(hostsToPayOut.count) hosts ready for payout")
        
        var successCount = 0
        var failureCount = 0
        
        // Process each host payout
        for hostEarnings in hostsToPayOut {
            do {
                try await processHostPayout(hostEarnings)
                successCount += 1
                print("✅ AUTOMATION: Processed payout for \(hostEarnings.hostName)")
            } catch {
                failureCount += 1
                print("🔴 AUTOMATION: Failed payout for \(hostEarnings.hostName): \(error)")
            }
        }
        
        print("🤖 AUTOMATION: Weekly payouts completed!")
        print("🤖 AUTOMATION: ✅ Success: \(successCount), ❌ Failed: \(failureCount)")
        
        // Send admin summary
        await sendPayoutSummaryToAdmin(success: successCount, failed: failureCount)
    }
    
    /// Get hosts ready for payout
    private func getHostsReadyForPayout() async throws -> [HostEarnings] {
        let query = db.collection("hostEarnings")
            .whereField("pendingEarnings", isGreaterThanOrEqualTo: minimumPayoutAmount)
            .whereField("bankAccountSetup", isEqualTo: true)
        
        let snapshot = try await query.getDocuments()
        
        return try snapshot.documents.compactMap { document in
            try document.data(as: HostEarnings.self)
        }
    }
    
    /// Process individual host payout
    private func processHostPayout(_ hostEarnings: HostEarnings) async throws {
        print("💸 AUTOMATION: Processing $\(hostEarnings.pendingEarnings) payout for \(hostEarnings.hostName)")
        
        // Get host bank info
        guard let bankInfo = try await getHostBankInfo(hostId: hostEarnings.hostId) else {
            throw PayoutError.bankInfoNotFound
        }
        
        // Process payout based on method
        let payoutResult = try await processPayoutViaMethod(
            amount: hostEarnings.pendingEarnings,
            bankInfo: bankInfo,
            hostName: hostEarnings.hostName
        )
        
        // Record payout in database
        try await recordSuccessfulPayout(
            hostEarnings: hostEarnings,
            payoutResult: payoutResult
        )
        
        // Send confirmation to host
        await sendPayoutConfirmationToHost(
            hostEarnings: hostEarnings,
            payoutResult: payoutResult
        )
    }
    
    /// Process payout via different methods
    private func processPayoutViaMethod(
        amount: Double,
        bankInfo: HostBankInfo,
        hostName: String
    ) async throws -> PayoutResult {
        
        switch bankInfo.accountType {
        case .checking, .savings:
            // ACH Bank Transfer (MVP: only supporting ACH transfers for US banks)
            return try await processACHTransfer(
                amount: amount,
                routingNumber: bankInfo.routingNumber,
                accountNumber: bankInfo.accountNumber,
                accountType: bankInfo.accountType,
                recipientName: hostName
            )
        }
    }
    
    /// Process ACH bank transfer (most common in US)
    private func processACHTransfer(
        amount: Double,
        routingNumber: String,
        accountNumber: String,
        accountType: HostBankInfo.BankAccountType,
        recipientName: String
    ) async throws -> PayoutResult {
        
        print("🏦 ACH: Processing $\(amount) ACH transfer to \(recipientName)")
        
        // Integration with Stripe for ACH transfers
        let stripeTransferData: [String: Any] = [
            "amount": Int(amount * 100), // Stripe uses cents
            "currency": "usd",
            "destination": [
                "account_number": accountNumber,
                "routing_number": routingNumber,
                "account_type": accountType == .checking ? "checking" : "savings"
            ],
            "description": "Bondfyr host payout - \(Date().formatted(.dateTime.month().day()))"
        ]
        
        // TODO: Replace with actual Stripe API call
        // let transfer = try await StripeService.createACHTransfer(stripeTransferData)
        
        // Simulate successful transfer for now
        let transferId = "txn_\(UUID().uuidString)"
        
        print("✅ ACH: Transfer successful - ID: \(transferId)")
        
        return PayoutResult(
            id: transferId,
            amount: amount,
            method: .achTransfer,
            status: .processing,
            estimatedArrival: Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date(),
            fee: amount * 0.008 // 0.8% ACH fee
        )
    }
    
    /// Process PayPal transfer
    private func processPayPalTransfer(
        amount: Double,
        paypalEmail: String,
        recipientName: String
    ) async throws -> PayoutResult {
        
        print("💙 PAYPAL: Processing $\(amount) PayPal transfer to \(paypalEmail)")
        
        // Integration with PayPal Payouts API
        let paypalData: [String: Any] = [
            "sender_batch_header": [
                "sender_batch_id": "batch_\(UUID().uuidString)",
                "email_subject": "Your Bondfyr earnings have arrived!"
            ],
            "items": [[
                "recipient_type": "EMAIL",
                "amount": [
                    "value": String(format: "%.2f", amount),
                    "currency": "USD"
                ],
                "receiver": paypalEmail,
                "note": "Bondfyr host payout",
                "sender_item_id": "item_\(UUID().uuidString)"
            ]]
        ]
        
        // TODO: Replace with actual PayPal API call
        // let payout = try await PayPalService.createPayout(paypalData)
        
        // Simulate successful transfer for now
        let payoutId = "pp_\(UUID().uuidString)"
        
        print("✅ PAYPAL: Transfer successful - ID: \(payoutId)")
        
        return PayoutResult(
            id: payoutId,
            amount: amount,
            method: .paypal,
            status: .completed,
            estimatedArrival: Date(), // PayPal is usually instant
            fee: amount * 0.02 // 2% PayPal fee
        )
    }
    
    /// Process Wise international transfer
    private func processWiseTransfer(
        amount: Double,
        bankInfo: HostBankInfo,
        recipientName: String
    ) async throws -> PayoutResult {
        
        print("🌍 WISE: Processing $\(amount) international transfer to \(recipientName)")
        
        // Wise transfer simulation
        let transferId = "wise_\(UUID().uuidString)"
        
        return PayoutResult(
            id: transferId,
            amount: amount,
            method: .wise,
            status: .processing,
            estimatedArrival: Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date(),
            fee: amount * 0.006 // 0.6% Wise fee
        )
    }
    
    /// Get host bank information
    private func getHostBankInfo(hostId: String) async throws -> HostBankInfo? {
        let doc = try await db.collection("hostBankInfo").document(hostId).getDocument()
        
        if doc.exists {
            return try doc.data(as: HostBankInfo.self)
        } else {
            return nil
        }
    }
    
    /// Record successful payout
    private func recordSuccessfulPayout(
        hostEarnings: HostEarnings,
        payoutResult: PayoutResult
    ) async throws {
        
        let payoutRecord = PayoutRecord(
            id: payoutResult.id,
            amount: payoutResult.amount,
            payoutDate: Date(),
            payoutMethod: payoutResult.method.toPayoutMethod(),
            status: payoutResult.status.toPayoutStatus(),
            transactionIds: hostEarnings.transactions.map { $0.id },
            notes: "Automated weekly payout"
        )
        
        // Update host earnings
        let updatedEarnings = HostEarnings(
            id: hostEarnings.id,
            hostId: hostEarnings.hostId,
            hostName: hostEarnings.hostName,
            totalEarnings: hostEarnings.totalEarnings,
            pendingEarnings: 0.0, // Reset to 0
            paidEarnings: hostEarnings.paidEarnings + hostEarnings.pendingEarnings,
            lastPayoutDate: Date(),
            bankAccountSetup: hostEarnings.bankAccountSetup,
            transactions: hostEarnings.transactions,
            payoutHistory: hostEarnings.payoutHistory + [payoutRecord]
        )
        
        try await db.collection("hostEarnings")
            .document(hostEarnings.hostId)
            .setData(from: updatedEarnings)
        
        print("✅ AUTOMATION: Updated earnings record for \(hostEarnings.hostName)")
    }
    
    /// Send payout confirmation to host
    private func sendPayoutConfirmationToHost(
        hostEarnings: HostEarnings,
        payoutResult: PayoutResult
    ) async {
        // Send push notification and email to host
        print("📧 AUTOMATION: Sending payout confirmation to \(hostEarnings.hostName)")
        
        // TODO: Implement FCM notification
        // TODO: Implement email notification
    }
    
    /// Send payout summary to admin
    private func sendPayoutSummaryToAdmin(success: Int, failed: Int) async {
        print("📊 AUTOMATION: Sending admin summary - Success: \(success), Failed: \(failed)")
        
        // TODO: Send summary email/notification to admin
    }
}

// MARK: - Payout Models

struct PayoutResult {
    let id: String
    let amount: Double
    let method: PayoutMethod
    let status: PayoutStatus
    let estimatedArrival: Date
    let fee: Double
    
    enum PayoutMethod {
        case achTransfer
        case paypal
        case wise
        case instantTransfer
        
        func toPayoutMethod() -> PayoutRecord.PayoutMethod {
            switch self {
            case .achTransfer: return .ach
            case .paypal: return .paypal
            case .wise: return .wise
            case .instantTransfer: return .ach
            }
        }
    }
    
    enum PayoutStatus {
        case processing
        case completed
        case failed
        
        func toPayoutStatus() -> PayoutRecord.PayoutStatus {
            switch self {
            case .processing: return .processing
            case .completed: return .completed
            case .failed: return .failed
            }
        }
    }
}

enum PayoutError: LocalizedError {
    case bankInfoNotFound
    case insufficientBalance
    case transferFailed
    case apiError(String)
    
    var errorDescription: String? {
        switch self {
        case .bankInfoNotFound:
            return "Host bank information not found"
        case .insufficientBalance:
            return "Insufficient balance for payout"
        case .transferFailed:
            return "Transfer failed"
        case .apiError(let message):
            return "API Error: \(message)"
        }
    }
} 