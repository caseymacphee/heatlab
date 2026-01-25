//
//  PaywallView.swift
//  heatlab
//
//  Subscription paywall with plan selection and purchase flow
//

import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(SubscriptionManager.self) var subscriptionManager
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedProduct: Product?
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection
                    
                    // Feature comparison
                    featureSection
                    
                    // Subscription options
                    if subscriptionManager.isLoading {
                        ProgressView("Loading plans...")
                            .padding()
                    } else if let error = subscriptionManager.loadError {
                        errorView(message: error)
                    } else {
                        subscriptionCardsSection
                    }
                    
                    // Purchase button
                    purchaseButton
                    
                    // Disclosures
                    disclosuresSection
                    
                    // Restore purchases
                    restoreButton
                    
                    // Legal links
                    legalLinksSection
                }
                .padding()
            }
            .navigationTitle("Heatlab Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .alert("Purchase Error", isPresented: $showingError) {
                Button("OK") {
                    subscriptionManager.resetPurchaseState()
                }
            } message: {
                Text(errorMessage)
            }
            .onChange(of: subscriptionManager.purchaseState) { _, newState in
                handlePurchaseStateChange(newState)
            }
            .onAppear {
                // Select annual by default (better value)
                if selectedProduct == nil {
                    selectedProduct = subscriptionManager.annualProduct ?? subscriptionManager.monthlyProduct
                }
            }
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "flame.fill")
                .font(.system(size: 60))
                .foregroundStyle(LinearGradient.heatLabPrimary)
            
            Text("Unlock Your Full Potential")
                .font(.title2.bold())
            
            Text("Free includes 7 days of history. Pro unlocks 1M, 3M, and 1Y analysis, plus AI insights and detailed period comparisons.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top)
    }
    
    // MARK: - Features
    
    private var featureSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(ProFeature.allCases, id: \.self) { feature in
                HStack(spacing: 12) {
                    Image(systemName: feature.iconName)
                        .foregroundStyle(Color.HeatLab.coral)
                        .frame(width: 24)
                    
                    Text(feature.rawValue)
                        .font(.subheadline)
                    
                    Spacer()
                    
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: HeatLabRadius.lg))
    }
    
    // MARK: - Subscription Cards
    
    private var subscriptionCardsSection: some View {
        VStack(spacing: 12) {
            if let monthly = subscriptionManager.monthlyProduct {
                SubscriptionCard(
                    product: monthly,
                    isSelected: selectedProduct?.id == monthly.id,
                    savingsPercent: nil
                ) {
                    selectedProduct = monthly
                }
            }
            
            if let annual = subscriptionManager.annualProduct {
                SubscriptionCard(
                    product: annual,
                    isSelected: selectedProduct?.id == annual.id,
                    savingsPercent: subscriptionManager.annualSavingsPercent
                ) {
                    selectedProduct = annual
                }
            }
        }
    }
    
    // MARK: - Purchase Button
    
    private var purchaseButton: some View {
        Button {
            Task {
                if let product = selectedProduct {
                    await subscriptionManager.purchase(product)
                }
            }
        } label: {
            Group {
                if subscriptionManager.purchaseState == .purchasing {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Subscribe Now")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
        }
        .buttonStyle(.borderedProminent)
        .tint(Color.HeatLab.coral)
        .disabled(selectedProduct == nil || subscriptionManager.purchaseState == .purchasing)
    }
    
    // MARK: - Disclosures
    
    private var disclosuresSection: some View {
        VStack(spacing: 8) {
            if let product = selectedProduct {
                Text("Payment will be charged to your Apple ID account at confirmation of purchase.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                
                Text("Subscription automatically renews every \(product.subscriptionPeriodText) unless cancelled at least 24 hours before the end of the current period. Your account will be charged \(product.displayPrice) for renewal within 24 hours prior to the end of the current period.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                
                Text("You can manage and cancel your subscription in your App Store account settings.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal)
    }
    
    // MARK: - Restore Button
    
    private var restoreButton: some View {
        Button {
            Task {
                await subscriptionManager.restorePurchases()
            }
        } label: {
            if subscriptionManager.isLoading {
                ProgressView()
                    .scaleEffect(0.8)
            } else {
                Text("Restore Purchases")
                    .font(.subheadline)
            }
        }
        .disabled(subscriptionManager.isLoading)
    }
    
    // MARK: - Legal Links
    
    private var legalLinksSection: some View {
        HStack(spacing: 16) {
            Link("Terms of Use", destination: URL(string: "https://macpheelabs.com/heatlab/terms")!)
            
            Text("•")
                .foregroundStyle(.tertiary)
            
            Link("Privacy Policy", destination: URL(string: "https://macpheelabs.com/heatlab/privacy")!)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    
    // MARK: - Error View
    
    private func errorView(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.orange)
            
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Try Again") {
                Task {
                    await subscriptionManager.start()
                }
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }
    
    // MARK: - Helpers
    
    private func handlePurchaseStateChange(_ state: PurchaseState) {
        switch state {
        case .purchased:
            dismiss()
        case .failed(let message):
            errorMessage = message
            showingError = true
        case .cancelled:
            subscriptionManager.resetPurchaseState()
        default:
            break
        }
    }
}

// MARK: - Subscription Card

private struct SubscriptionCard: View {
    let product: Product
    let isSelected: Bool
    let savingsPercent: Int?
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(product.displayName)
                            .font(.headline)
                        
                        if let savings = savingsPercent {
                            Text("Save \(savings)%")
                                .font(.caption2.bold())
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.HeatLab.coral)
                                .clipShape(Capsule())
                        }
                    }
                    
                    Text(product.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(product.displayPrice)
                        .font(.title3.bold())
                    
                    Text("per \(product.subscriptionPeriodText)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    if let monthlyPrice = product.monthlyEquivalentPrice,
                       product.subscription?.subscriptionPeriod.unit == .year {
                        Text("\(monthlyPrice.formatted(.currency(code: "USD")))/mo")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: HeatLabRadius.md)
                    .fill(isSelected ? Color.HeatLab.coral.opacity(0.1) : Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: HeatLabRadius.md)
                    .strokeBorder(isSelected ? Color.HeatLab.coral : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    PaywallView()
        .environment(SubscriptionManager())
}
