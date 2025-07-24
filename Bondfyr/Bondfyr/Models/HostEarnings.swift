import Foundation
import FirebaseFirestore

// MARK: - Host Earnings & Payout Models

struct HostEarnings: Codable, Identifiable {
    let id: String
    let hostId: String
    let hostName: String
    let totalEarnings: Double
    let pendingEarnings: Double
    let paidEarnings: Double
    let lastPayoutDate: Date?
    let bankAccountSetup: Bool
    let transactions: [HostTransaction]
    let payoutHistory: [PayoutRecord]
    
    init(hostId: String, hostName: String) {
        self.id = hostId
        self.hostId = hostId
        self.hostName = hostName
        self.totalEarnings = 0.0
        self.pendingEarnings = 0.0
        self.paidEarnings = 0.0
        self.lastPayoutDate = nil
        self.bankAccountSetup = false
        self.transactions = []
        self.payoutHistory = []
    }
    
    // Complete initializer for updates
    init(id: String, hostId: String, hostName: String, totalEarnings: Double, pendingEarnings: Double, paidEarnings: Double, lastPayoutDate: Date?, bankAccountSetup: Bool, transactions: [HostTransaction], payoutHistory: [PayoutRecord]) {
        self.id = id
        self.hostId = hostId
        self.hostName = hostName
        self.totalEarnings = totalEarnings
        self.pendingEarnings = pendingEarnings
        self.paidEarnings = paidEarnings
        self.lastPayoutDate = lastPayoutDate
        self.bankAccountSetup = bankAccountSetup
        self.transactions = transactions
        self.payoutHistory = payoutHistory
    }
}

struct HostTransaction: Codable, Identifiable {
    let id: String
    let partyId: String
    let partyTitle: String
    let guestId: String
    let guestName: String
    let amount: Double
    let platformFee: Double
    let hostEarning: Double
    let date: Date
    let paymentId: String
    var status: TransactionStatus
    var refundedAt: Date?
    
    init(partyId: String, partyTitle: String, guestId: String, guestName: String, amount: Double) {
        self.id = UUID().uuidString
        self.partyId = partyId
        self.partyTitle = partyTitle
        self.guestId = guestId
        self.guestName = guestName
        self.amount = amount
        self.platformFee = amount * 0.20 // 20% platform fee
        self.hostEarning = amount * 0.80 // 80% to host
        self.date = Date()
        self.paymentId = ""
        self.status = .paid
        self.refundedAt = nil
    }
}

enum TransactionStatus: String, Codable {
    case paid = "paid"
    case refunded = "refunded"
}

struct PayoutRecord: Codable, Identifiable {
    let id: String
    let amount: Double
    let payoutDate: Date
    let payoutMethod: PayoutMethod
    let status: PayoutStatus
    let transactionIds: [String]
    let notes: String?
    
    enum PayoutMethod: String, Codable, CaseIterable {
        case ach = "ACH Transfer"
        case paypal = "PayPal"
        case wise = "Wise Transfer"
        case check = "Check"
    }
    
    enum PayoutStatus: String, Codable, CaseIterable {
        case pending = "Pending"
        case processing = "Processing"
        case completed = "Completed"
        case failed = "Failed"
    }
}

struct HostBankInfo: Codable {
    let hostId: String
    let accountType: BankAccountType
    let bankName: String
    let accountNumber: String // Encrypted
    let routingNumber: String
    let setupDate: Date
    let verified: Bool
    
    enum BankAccountType: String, Codable, CaseIterable {
        case checking = "Checking"
        case savings = "Savings"
        
        var displayName: String {
            switch self {
            case .checking: return "Checking Account"
            case .savings: return "Savings Account"
            }
        }
        
        var icon: String {
            return "building.columns"
        }
    }
}

// MARK: - Host Earnings Manager

@MainActor
class HostEarningsManager: ObservableObject {
    static let shared = HostEarningsManager()
    
    @Published var hostEarnings: [String: HostEarnings] = [:]
    @Published var isLoading = false
    
    private let db = Firestore.firestore()
    
    private init() {}
    
    /// Record a new transaction when guest pays
    func recordHostTransaction(
        hostId: String,
        hostName: String,
        partyId: String,
        partyTitle: String,
        guestId: String,
        guestName: String,
        amount: Double,
        paymentId: String
    ) async throws {
        
        let hostTransaction = HostTransaction(
            partyId: partyId,
            partyTitle: partyTitle,
            guestId: guestId,
            guestName: guestName,
            amount: amount
        )
        
        print("💰 EARNINGS: Recording transaction for host \(hostName)")
        print("💰 EARNINGS: Amount: $\(amount), Host gets: $\(hostTransaction.hostEarning)")
        
        // Update host earnings in Firestore
        let hostEarningsRef = db.collection("hostEarnings").document(hostId)
        
        try await db.runTransaction { (transaction, errorPointer) -> Any? in
            do {
                let hostDoc = try transaction.getDocument(hostEarningsRef)
                
                var hostEarnings: HostEarnings
                if hostDoc.exists {
                    hostEarnings = try hostDoc.data(as: HostEarnings.self)
                } else {
                    hostEarnings = HostEarnings(hostId: hostId, hostName: hostName)
                }
                
                // Add new transaction
                var updatedTransactions = hostEarnings.transactions
                updatedTransactions.append(hostTransaction)
                
                // Update earnings
                let newPendingEarnings = hostEarnings.pendingEarnings + hostTransaction.hostEarning
                let newTotalEarnings = hostEarnings.totalEarnings + hostTransaction.hostEarning
                
                let updatedEarnings = HostEarnings(
                    id: hostEarnings.id,
                    hostId: hostEarnings.hostId,
                    hostName: hostEarnings.hostName,
                    totalEarnings: newTotalEarnings,
                    pendingEarnings: newPendingEarnings,
                    paidEarnings: hostEarnings.paidEarnings,
                    lastPayoutDate: hostEarnings.lastPayoutDate,
                    bankAccountSetup: hostEarnings.bankAccountSetup,
                    transactions: updatedTransactions,
                    payoutHistory: hostEarnings.payoutHistory
                )
                
                try transaction.setData(from: updatedEarnings, forDocument: hostEarningsRef)
                return nil
                
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }
        }
        
        print("✅ EARNINGS: Transaction recorded successfully")
    }
    
    /// CRITICAL: Reverse host earnings when refunds are processed
    func reverseHostEarnings(
        hostId: String,
        partyId: String,
        guestId: String,
        refundAmount: Double,
        paymentId: String
    ) async throws {
        
        print("💸 EARNINGS REVERSAL: Processing for host \(hostId)")
        print("💸 REVERSAL: Party \(partyId), Guest \(guestId), Amount: $\(refundAmount)")
        
        let hostEarningsRef = db.collection("hostEarnings").document(hostId)
        
        try await db.runTransaction { (transaction, errorPointer) -> Any? in
            do {
                let hostDoc = try transaction.getDocument(hostEarningsRef)
                
                guard hostDoc.exists else {
                    print("🔴 REVERSAL: No earnings record found for host \(hostId)")
                    return nil
                }
                
                let hostEarnings = try hostDoc.data(as: HostEarnings.self)
                
                // Find the original transaction to reverse
                var updatedTransactions = hostEarnings.transactions
                var reversalAmount: Double = 0
                
                for index in updatedTransactions.indices {
                    let hostTransaction = updatedTransactions[index]
                    
                    // Match by partyId and guestId (more reliable than paymentId)
                    if hostTransaction.partyId == partyId && 
                       hostTransaction.guestId == guestId {
                        
                        print("💸 REVERSAL: Found transaction to reverse - Host earning: $\(hostTransaction.hostEarning)")
                        
                        reversalAmount = hostTransaction.hostEarning
                        
                        // Mark transaction as refunded
                        var refundedTransaction = hostTransaction
                        refundedTransaction.status = .refunded
                        refundedTransaction.refundedAt = Date()
                        updatedTransactions[index] = refundedTransaction
                        
                        break
                    }
                }
                
                guard reversalAmount > 0 else {
                    print("🔴 REVERSAL: No matching transaction found to reverse")
                    return nil
                }
                
                // Calculate new earnings (reverse the host earning)
                let newPendingEarnings = max(0, hostEarnings.pendingEarnings - reversalAmount)
                let newTotalEarnings = max(0, hostEarnings.totalEarnings - reversalAmount)
                
                print("💸 REVERSAL: Reducing pending earnings by $\(reversalAmount)")
                print("💸 REVERSAL: Old pending: $\(hostEarnings.pendingEarnings) → New pending: $\(newPendingEarnings)")
                
                let updatedEarnings = HostEarnings(
                    id: hostEarnings.id,
                    hostId: hostEarnings.hostId,
                    hostName: hostEarnings.hostName,
                    totalEarnings: newTotalEarnings,
                    pendingEarnings: newPendingEarnings,
                    paidEarnings: hostEarnings.paidEarnings,
                    lastPayoutDate: hostEarnings.lastPayoutDate,
                    bankAccountSetup: hostEarnings.bankAccountSetup,
                    transactions: updatedTransactions,
                    payoutHistory: hostEarnings.payoutHistory
                )
                
                try transaction.setData(from: updatedEarnings, forDocument: hostEarningsRef)
                return nil
                
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }
        }
        
        print("✅ EARNINGS REVERSAL: Successfully reversed $\(refundAmount * 0.8) for host \(hostId)")
    }
    
    /// Get host earnings for display
    func getHostEarnings(hostId: String) async throws -> HostEarnings? {
        let doc = try await db.collection("hostEarnings").document(hostId).getDocument()
        
        if doc.exists {
            return try doc.data(as: HostEarnings.self)
        } else {
            return nil
        }
    }
    
    /// Process weekly payouts (admin function)
    func processWeeklyPayouts() async throws {
        print("💸 PAYOUTS: Processing weekly payouts...")
        
        // Get all hosts with pending earnings
        let hostsWithEarnings = try await db.collection("hostEarnings")
            .whereField("pendingEarnings", isGreaterThan: 0)
            .getDocuments()
        
        for document in hostsWithEarnings.documents {
            let hostEarnings = try document.data(as: HostEarnings.self)
            
            if hostEarnings.pendingEarnings >= 10.0 { // Minimum $10 payout
                try await processHostPayout(hostEarnings: hostEarnings)
            }
        }
        
        print("✅ PAYOUTS: Weekly payouts completed")
    }
    
    /// Process individual host payout
    private func processHostPayout(hostEarnings: HostEarnings) async throws {
        print("💸 PAYOUT: Processing payout for \(hostEarnings.hostName): $\(hostEarnings.pendingEarnings)")
        
        // Here you would integrate with:
        // - Stripe for ACH transfers
        // - PayPal for PayPal payouts  
        // - Wise for international transfers
        
        // For now, we'll mark as completed (implement actual payout later)
        let payoutRecord = PayoutRecord(
            id: UUID().uuidString,
            amount: hostEarnings.pendingEarnings,
            payoutDate: Date(),
            payoutMethod: .ach,
            status: .completed,
            transactionIds: hostEarnings.transactions.map { $0.id },
            notes: "Weekly payout"
        )
        
        // Update Firestore - create new instance since properties are immutable
        let updatedEarnings = HostEarnings(
            id: hostEarnings.id,
            hostId: hostEarnings.hostId,
            hostName: hostEarnings.hostName,
            totalEarnings: hostEarnings.totalEarnings,
            pendingEarnings: 0, // Reset to 0
            paidEarnings: hostEarnings.paidEarnings + hostEarnings.pendingEarnings,
            lastPayoutDate: Date(),
            bankAccountSetup: hostEarnings.bankAccountSetup,
            transactions: hostEarnings.transactions,
            payoutHistory: hostEarnings.payoutHistory + [payoutRecord]
        )
        
        try await db.collection("hostEarnings").document(hostEarnings.hostId).setData(from: updatedEarnings)
        
        print("✅ PAYOUT: Completed payout for \(hostEarnings.hostName)")
    }
} 