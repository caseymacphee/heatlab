//
//  SubscriptionManager.swift
//  heatlab
//
//  StoreKit 2 subscription management for Heatlab Pro
//

import Foundation
import StoreKit
import SwiftUI

/// Product identifiers for Heatlab Pro subscriptions
enum SubscriptionProduct: String, CaseIterable {
    case monthly = "com.heatlab.pro.monthly"
    case annual = "com.heatlab.pro.annual"
    
    var id: String { rawValue }
}

/// Current state of a purchase operation
enum PurchaseState: Equatable {
    case ready
    case purchasing
    case purchased
    case failed(String)
    case cancelled
}

/// Manages StoreKit 2 subscriptions for Heatlab Pro
@Observable
final class SubscriptionManager {
    // MARK: - Published State
    
    /// Whether the user has an active Pro subscription
    private(set) var isPro: Bool = false
    
    /// Available subscription products loaded from App Store
    private(set) var products: [Product] = []
    
    /// Current state of purchase operation
    private(set) var purchaseState: PurchaseState = .ready
    
    /// Whether products are currently loading
    private(set) var isLoading: Bool = false
    
    /// Error message if product loading failed
    private(set) var loadError: String?
    
    // MARK: - Private Properties
    
    private var updateListenerTask: Task<Void, Error>?
    
    private let productIDs: [String] = SubscriptionProduct.allCases.map { $0.id }
    
    // MARK: - Computed Properties
    
    /// Monthly subscription product (if available)
    var monthlyProduct: Product? {
        products.first { $0.id == SubscriptionProduct.monthly.id }
    }
    
    /// Annual subscription product (if available)
    var annualProduct: Product? {
        products.first { $0.id == SubscriptionProduct.annual.id }
    }
    
    /// Calculates annual savings compared to monthly
    var annualSavingsPercent: Int? {
        guard let monthly = monthlyProduct,
              let annual = annualProduct else { return nil }
        
        let monthlyAnnualized = monthly.price * 12
        let savings = (monthlyAnnualized - annual.price) / monthlyAnnualized
        let savingsPercent = NSDecimalNumber(decimal: savings * 100)
        return Int(savingsPercent.doubleValue)
    }
    
    // MARK: - Initialization
    
    init() {}
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    // MARK: - Public Methods
    
    /// Start the subscription manager - load products, check entitlements, listen for updates
    @MainActor
    func start() async {
        // Start listening for transaction updates
        updateListenerTask = listenForTransactionUpdates()
        
        // Load products from App Store
        await loadProducts()
        
        // Check current entitlement status
        await checkEntitlements()
    }
    
    /// Purchase a subscription product
    @MainActor
    func purchase(_ product: Product) async {
        purchaseState = .purchasing
        
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                // Verify the transaction
                switch verification {
                case .verified(let transaction):
                    // Grant access and finish the transaction
                    await transaction.finish()
                    await checkEntitlements()
                    purchaseState = .purchased
                    
                case .unverified(_, let error):
                    purchaseState = .failed("Transaction verification failed: \(error.localizedDescription)")
                }
                
            case .userCancelled:
                purchaseState = .cancelled
                
            case .pending:
                // Transaction is pending (e.g., Ask to Buy)
                purchaseState = .ready
                
            @unknown default:
                purchaseState = .failed("Unknown purchase result")
            }
        } catch {
            purchaseState = .failed(error.localizedDescription)
        }
    }
    
    /// Restore previous purchases
    @MainActor
    func restorePurchases() async {
        isLoading = true
        
        do {
            // Sync with App Store to restore any purchases
            try await AppStore.sync()
            await checkEntitlements()
        } catch {
            loadError = "Failed to restore purchases: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    /// Reset purchase state (e.g., after dismissing an error)
    @MainActor
    func resetPurchaseState() {
        purchaseState = .ready
    }
    
    // MARK: - Private Methods
    
    /// Load subscription products from the App Store
    @MainActor
    private func loadProducts() async {
        isLoading = true
        loadError = nil
        
        do {
            let storeProducts = try await Product.products(for: productIDs)
            
            // Sort products: monthly first, then annual
            products = storeProducts.sorted { product1, product2 in
                if product1.id == SubscriptionProduct.monthly.id { return true }
                if product2.id == SubscriptionProduct.monthly.id { return false }
                return product1.id < product2.id
            }
            
            if products.isEmpty {
                loadError = "No subscription products available"
            }
        } catch {
            loadError = "Failed to load products: \(error.localizedDescription)"
            print("❌ SubscriptionManager: Failed to load products: \(error)")
        }
        
        isLoading = false
    }
    
    /// Check current entitlement status
    @MainActor
    private func checkEntitlements() async {
        var hasActiveSubscription = false
        
        // Iterate through all current entitlements
        for await result in Transaction.currentEntitlements {
            switch result {
            case .verified(let transaction):
                // Check if this is one of our subscription products
                if productIDs.contains(transaction.productID) {
                    // Subscription is active if not expired or revoked
                    if transaction.revocationDate == nil {
                        hasActiveSubscription = true
                    }
                }
                
            case .unverified(_, _):
                // Skip unverified transactions
                continue
            }
        }
        
        isPro = hasActiveSubscription
        print("🔑 SubscriptionManager: isPro = \(isPro)")
    }
    
    /// Listen for transaction updates (purchases, renewals, revocations)
    private func listenForTransactionUpdates() -> Task<Void, Error> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                switch result {
                case .verified(let transaction):
                    // Finish the transaction
                    await transaction.finish()
                    
                    // Update entitlement status on main actor
                    guard let self = self else { continue }
                    Task { @MainActor [self] in
                        await self.checkEntitlements()
                    }
                    
                case .unverified(_, _):
                    // Skip unverified transactions
                    continue
                }
            }
        }
    }
}

// MARK: - StoreKit Extensions

extension Product {
    /// Formatted subscription period (e.g., "month", "year")
    var subscriptionPeriodText: String {
        guard let subscription = self.subscription else { return "" }
        
        let unit = subscription.subscriptionPeriod.unit
        let value = subscription.subscriptionPeriod.value
        
        switch unit {
        case .day:
            return value == 1 ? "day" : "\(value) days"
        case .week:
            return value == 1 ? "week" : "\(value) weeks"
        case .month:
            return value == 1 ? "month" : "\(value) months"
        case .year:
            return value == 1 ? "year" : "\(value) years"
        @unknown default:
            return ""
        }
    }
    
    /// Price per month for comparison (for annual subscriptions)
    var monthlyEquivalentPrice: Decimal? {
        guard let subscription = self.subscription else { return nil }
        
        let period = subscription.subscriptionPeriod
        switch period.unit {
        case .year:
            return price / Decimal(12 * period.value)
        case .month:
            return price / Decimal(period.value)
        default:
            return nil
        }
    }
}
