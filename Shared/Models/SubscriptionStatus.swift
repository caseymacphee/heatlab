//
//  SubscriptionStatus.swift
//  heatlab
//
//  Subscription tier and status types for Heatlab Pro
//

import Foundation

/// Subscription tier levels
enum SubscriptionTier: String, Codable {
    case free
    case pro
}

/// Detailed subscription status for UI display
enum SubscriptionStatusInfo: Equatable {
    /// No active subscription
    case free
    
    /// Active monthly subscription
    case proMonthly
    
    /// Active annual subscription
    case proAnnual
    
    /// Subscription expired or was cancelled
    case expired
    
    /// Whether this status represents an active Pro subscription
    var isPro: Bool {
        switch self {
        case .proMonthly, .proAnnual:
            return true
        case .free, .expired:
            return false
        }
    }
    
    /// Display name for the subscription status
    var displayName: String {
        switch self {
        case .free:
            return "Free"
        case .proMonthly:
            return "Pro (Monthly)"
        case .proAnnual:
            return "Pro (Annual)"
        case .expired:
            return "Expired"
        }
    }
    
    /// Short display name
    var shortName: String {
        switch self {
        case .free, .expired:
            return "Free"
        case .proMonthly, .proAnnual:
            return "Pro"
        }
    }
}

/// Features available at each tier
enum ProFeature: String, CaseIterable {
    case unlimitedHistory = "Unlimited session history"
    case periodComparisons = "Week, Month & Year comparisons"
    case aiInsights = "AI-powered insights"
    case fullTrends = "Full trend analysis"
    
    /// Short description for upgrade prompts
    var shortDescription: String {
        switch self {
        case .unlimitedHistory:
            return "Unlimited History"
        case .periodComparisons:
            return "Period Comparisons"
        case .aiInsights:
            return "AI Insights"
        case .fullTrends:
            return "Full Trends"
        }
    }
    
    /// Icon name for the feature
    var iconName: String {
        switch self {
        case .unlimitedHistory:
            return "calendar"
        case .periodComparisons:
            return "chart.bar.xaxis"
        case .aiInsights:
            return "sparkles"
        case .fullTrends:
            return "chart.line.uptrend.xyaxis"
        }
    }
}
