import Foundation
import StoreKit
import FirebaseFirestore

@MainActor
final class StoreKitManager: ObservableObject {
    static let shared = StoreKitManager()

    @Published var products: [Product] = []
    @Published var isLoading: Bool = false
    @Published var lastError: String?

    // Default product identifiers for listing subcredits (configure in App Store Connect)
    // Example bundles: 100, 500, 1000 subcredits (1 subcredit = $0.01)
    let defaultProductIds: [String] = [
        "listing_subcredit_100",
        "listing_subcredit_500",
        "listing_subcredit_1000"
    ]

    private init() {}

    func loadProducts(productIds: [String]? = nil) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let ids = productIds ?? defaultProductIds
            let fetched = try await Product.products(for: Set(ids))
            self.products = fetched.sorted { $0.price < $1.price }
        } catch {
            self.lastError = error.localizedDescription
        }
    }

    struct PurchaseOutcome {
        let success: Bool
        let subcreditsGranted: Int
    }

    func purchase(product: Product, userId: String) async -> PurchaseOutcome {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                // Determine subcredits from product identifier
                let subcredits = subcreditsFromProductId(product.id)
                // Grant subcredits
                try await ListingCreditWallet.shared.addSubcredits(userId: userId, subcreditsToAdd: subcredits)
                await transaction.finish()
                return PurchaseOutcome(success: true, subcreditsGranted: subcredits)
            case .userCancelled:
                return PurchaseOutcome(success: false, subcreditsGranted: 0)
            case .pending:
                // Treat as not yet usable
                return PurchaseOutcome(success: false, subcreditsGranted: 0)
            @unknown default:
                return PurchaseOutcome(success: false, subcreditsGranted: 0)
            }
        } catch {
            self.lastError = error.localizedDescription
            return PurchaseOutcome(success: false, subcreditsGranted: 0)
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error ?? NSError(domain: "IAP", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unverified transaction"])
        case .verified(let safe):
            return safe
        }
    }

    private func subcreditsFromProductId(_ id: String) -> Int {
        // Supports both styles:
        // - listing_subcredit_100 => 100 subcredits
        // - listing_credit_1      => 1 dollar => 100 subcredits
        let parts = id.split(separator: "_")
        guard let last = parts.last, let n = Int(last) else { return 100 }
        if id.contains("subcredit") { return n }
        if id.contains("credit") { return n * 100 }
        return 100
    }
}

actor ListingCreditWallet {
    static let shared = ListingCreditWallet()
    private let db = Firestore.firestore()

    // Firestore: wallets/{userId} { listingSubcredits: Int }
    // Backward compatible: if old field listingCredits exists, treat as dollars and convert to subcredits
    func getBalance(userId: String) async throws -> Int {
        let doc = try await db.collection("wallets").document(userId).getDocument()
        let data = doc.data() ?? [:]
        if let sub = data["listingSubcredits"] as? Int { return sub }
        if let legacyCredits = data["listingCredits"] as? Int { return legacyCredits * 100 }
        return 0
    }

    func addSubcredits(userId: String, subcreditsToAdd: Int) async throws {
        try await db.runTransaction { transaction, _ in
            let ref = self.db.collection("wallets").document(userId)
            let snapshot: DocumentSnapshot
            do { snapshot = try transaction.getDocument(ref) } catch { throw error }
            let current = (snapshot.data()? ["listingSubcredits"] as? Int)
                ?? (((snapshot.data()? ["listingCredits"] as? Int)?.advanced(by: 0))?.multipliedReportingOverflow(by: 100).partialValue ?? 0)
            let updated = max(0, current + subcreditsToAdd)
            transaction.setData(["listingSubcredits": updated], forDocument: ref, merge: true)
            return ()
        }
    }

    func deductSubcredits(userId: String, subcreditsToDeduct: Int) async throws {
        try await db.runTransaction { transaction, _ in
            let ref = self.db.collection("wallets").document(userId)
            let snapshot: DocumentSnapshot
            do { snapshot = try transaction.getDocument(ref) } catch { throw error }
            let current = (snapshot.data()? ["listingSubcredits"] as? Int)
                ?? (((snapshot.data()? ["listingCredits"] as? Int)?.advanced(by: 0))?.multipliedReportingOverflow(by: 100).partialValue ?? 0)
            guard current >= subcreditsToDeduct else {
                throw NSError(domain: "IAP", code: 402, userInfo: [NSLocalizedDescriptionKey: "Insufficient credits (subcredits)"])
            }
            let updated = current - subcreditsToDeduct
            transaction.setData(["listingSubcredits": updated], forDocument: ref, merge: true)
            return ()
        }
    }
}


