//
//  CreditHistoryViewModel.swift
//  pawsitive-app
//
//  Created by Diptayan Jash on 10/03/26.
//

import Foundation
import Supabase
import SwiftUI

struct CreditEntry: Codable, Identifiable {
    let id: String
    let incidentId: String?
    let creditsEarned: Int
    let reason: String
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case incidentId = "incident_id"
        case creditsEarned = "credits_earned"
        case reason
        case createdAt = "created_at"
    }
}

struct CreditHistoryResponse: Codable {
    let history: [CreditEntry]
}

@MainActor
class CreditHistoryViewModel: ObservableObject {
    @Published var entries: [CreditEntry] = []
    @Published var isLoading: Bool = true
    @Published var errorMessage: String? = nil

    init() {
        loadHistory()
    }

    func loadHistory() {
        Task {
            isLoading = true
            errorMessage = nil

            do {
                let result: CreditHistoryResponse = try await NetworkManager.shared.request(
                    endpoint: CreditEndpoint.creditHistory(token: "", limit: 50),
                    keyDecodingStrategy: .useDefaultKeys
                )

                entries = result.history
                isLoading = false
            } catch {
                errorMessage = "Failed to load earning history."
                isLoading = false
            }
        }
    }

    func reasonLabel(_ reason: String) -> String {
        switch reason {
        case "rescue_completion": return "Rescue Completed"
        case "fast_response": return "Fast Response Bonus"
        case "severe_case": return "Severe Case Bonus"
        case "citizen_rating": return "Citizen Rating Bonus"
        case "distance_bonus": return "Distance Bonus"
        default: return reason.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    func reasonIcon(_ reason: String) -> String {
        switch reason {
        case "rescue_completion": return "checkmark.circle.fill"
        case "fast_response": return "bolt.fill"
        case "severe_case": return "exclamationmark.triangle.fill"
        case "citizen_rating": return "star.fill"
        case "distance_bonus": return "location.fill"
        default: return "star.circle.fill"
        }
    }
}
