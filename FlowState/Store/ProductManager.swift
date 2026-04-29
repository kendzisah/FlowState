import Foundation
import StoreKit

/// Thin wrapper around StoreKit 2.
///
/// **Wired-but-stubbed**: when no `Configuration.storekit` file is in the scheme
/// (and no App Store Connect product is configured), `purchaseProTrial()` returns
/// `true` immediately so onboarding/paywall flows are testable without backend setup.
///
/// To go live:
/// 1. Add a `Configuration.storekit` file to the project root and select it under
///    Edit Scheme > Run > Options > StoreKit Configuration.
/// 2. Configure the product `com.flocktechnologies.FlowState.proMonthly` with a
///    7-day intro free trial.
/// 3. Replace the stub branches below with the live `Product.products(for:)` /
///    `Transaction.currentEntitlements` flow.
@MainActor
@Observable
final class ProductManager {
    static let shared = ProductManager()

    let proMonthlyID = "com.flocktechnologies.FlowState.proMonthly"

    private(set) var products: [Product] = []
    private(set) var lastError: String?

    private init() {}

    func loadProducts() async {
        do {
            products = try await Product.products(for: [proMonthlyID])
        } catch {
            products = []
            lastError = error.localizedDescription
        }
    }

    /// Returns true on confirmed purchase or successful trial start.
    /// Stub fallback: returns true if no product is configured.
    func purchaseProTrial() async -> Bool {
        if products.isEmpty { await loadProducts() }
        guard let product = products.first else {
            // Stub mode: no products configured, treat as success for dev testing.
            return true
        }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    return true
                }
                return false
            case .userCancelled, .pending:
                return false
            @unknown default:
                return false
            }
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    /// Returns true if any active entitlement is found.
    /// Stub fallback: returns true if no products are configured.
    func restorePurchases() async -> Bool {
        try? await StoreKit.AppStore.sync()
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == proMonthlyID,
               transaction.revocationDate == nil {
                return true
            }
        }
        return products.isEmpty
    }
}
