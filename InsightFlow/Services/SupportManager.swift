import Foundation
import StoreKit
import SwiftUI

@MainActor
class SupportManager: ObservableObject {
    static let shared = SupportManager()

    @Published var products: [Product] = []
    @Published var isLoading = false
    @Published var purchaseError: String?
    @Published var showThankYou = false

    // Support reminder tracking
    @AppStorage("supportReminderShown") private var reminderShown = false
    @AppStorage("hasSupported") private var hasSupported = false
    @AppStorage("appLaunchCount") private var launchCount = 0

    // Product IDs - diese müssen in App Store Connect erstellt werden
    private let productIds = [
        "de.godsapp.insightflow.support.small",   // 0,99€
        "de.godsapp.insightflow.support.medium",  // 2,99€
        "de.godsapp.insightflow.support.large"    // 5,99€
    ]

    private init() {}

    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }

        do {
            products = try await Product.products(for: productIds)
                .sorted { $0.price < $1.price }
        } catch {
            #if DEBUG
            print("Failed to load products: \(error)")
            #endif
        }
    }

    func purchase(_ product: Product) async {
        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    hasSupported = true
                    showThankYou = true
                case .unverified:
                    purchaseError = String(localized: "support.error.unverified", defaultValue: "Purchase could not be verified")
                }
            case .userCancelled:
                break
            case .pending:
                purchaseError = String(localized: "support.error.pending", defaultValue: "Purchase is being processed")
            @unknown default:
                break
            }
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    // MARK: - Support Reminder

    func incrementLaunchCount() {
        launchCount += 1
    }

    var shouldShowReminder: Bool {
        // Show after 5 launches, only once, and only if not already supported
        return launchCount >= 5 && !reminderShown && !hasSupported
    }

    func markReminderShown() {
        reminderShown = true
    }

    func markAlreadySupported() {
        hasSupported = true
        reminderShown = true
    }
}

// MARK: - Support Product Extensions

extension Product {
    var emoji: String {
        switch id {
        case "de.godsapp.insightflow.support.small": return "☕️"
        case "de.godsapp.insightflow.support.medium": return "🍕"
        case "de.godsapp.insightflow.support.large": return "🎉"
        default: return "💝"
        }
    }

    var supportName: String {
        switch id {
        case "de.godsapp.insightflow.support.small":
            return String(localized: "support.small")
        case "de.godsapp.insightflow.support.medium":
            return String(localized: "support.medium")
        case "de.godsapp.insightflow.support.large":
            return String(localized: "support.large")
        default:
            return displayName
        }
    }
}
