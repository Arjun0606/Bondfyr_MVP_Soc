import SwiftUI
import StoreKit

struct ListingCreditPurchaseSheet: View {
    let userId: String
    let listingFeeUSD: Double
    // Required subcredits (1 subcredit = $0.01)
    let requiredSubcredits: Int
    let onCompleted: () -> Void

    @Environment(\._openURL) private var openURL
    @Environment(\.presentationMode) private var presentationMode
    @StateObject private var iap = StoreKitManager.shared
    @State private var balance: Int = 0
    @State private var isLoading: Bool = true
    @State private var isPurchasing: Bool = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Text("Listing Fee")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("$\(String(format: "%.2f", listingFeeUSD))")
                        .font(.largeTitle).bold()
                        .foregroundColor(.green)
                }

                VStack(spacing: 12) {
                    infoRow(label: "Required", value: "$\(String(format: "%.2f", Double(requiredSubcredits) / 100.0)) (\(requiredSubcredits) coins)")
                    infoRow(label: "Your Balance", value: isLoading ? "…" : "\(balance) coins")
                }
                .padding()
                .background(Color(.systemGray6).opacity(0.1))
                .cornerRadius(12)

                if let error = errorMessage {
                    Text(error).foregroundColor(.red).font(.footnote)
                }

                if balance >= requiredSubcredits {
                    Button(action: deductAndComplete) {
                        HStack {
                            if isPurchasing { ProgressView().tint(.white) }
                            Text("Pay with Apple • Deduct \(requiredSubcredits) coins")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.pink)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(isPurchasing)
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Buy Coins")
                            .font(.headline)
                            .foregroundColor(.white)
                        if iap.products.isEmpty {
                            ProgressView().tint(.white)
                        } else {
                            ForEach(iap.products, id: \.id) { product in
                                Button(action: { Task { await purchase(product) } }) {
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text(product.displayName)
                                                .foregroundColor(.white)
                                            Text(product.description)
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                        }
                                        Spacer()
                                        Text(product.displayPrice)
                                            .foregroundColor(.green)
                                    }
                                    .padding()
                                    .background(Color(.systemGray6).opacity(0.08))
                                    .cornerRadius(10)
                                }
                                .disabled(isPurchasing)
                            }
                        }
                    }
                }

                Spacer()

                Button("Close") { presentationMode.wrappedValue.dismiss() }
                    .foregroundColor(.gray)
            }
            .padding()
            .background(Color.black.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .task { await bootstrap() }
        }
        .preferredColorScheme(.dark)
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label).foregroundColor(.white)
            Spacer()
            Text(value).foregroundColor(.white).bold()
        }
    }

    private func bootstrap() async {
        isLoading = true
        defer { isLoading = false }
        do {
            balance = try await ListingCreditWallet.shared.getBalance(userId: userId)
            await iap.loadProducts()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func refreshBalance() async {
        do { balance = try await ListingCreditWallet.shared.getBalance(userId: userId) } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func purchase(_ product: Product) async {
        isPurchasing = true
        defer { isPurchasing = false }
        let outcome = await iap.purchase(product: product, userId: userId)
        if outcome.success {
            await refreshBalance()
        } else if let err = iap.lastError { errorMessage = err }
    }

    private func deductAndComplete() {
        Task {
            isPurchasing = true
            defer { isPurchasing = false }
            do {
                try await ListingCreditWallet.shared.deductSubcredits(userId: userId, subcreditsToDeduct: requiredSubcredits)
                presentationMode.wrappedValue.dismiss()
                onCompleted()
            } catch { errorMessage = error.localizedDescription }
        }
    }
}


