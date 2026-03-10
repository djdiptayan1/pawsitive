import Combine
import Foundation
import Supabase
import SwiftUI

@MainActor
class IncidentHistoryViewModel: ObservableObject {
    @Published var incidents: [RecentActivityModel] = []
    @Published var isLoading = false
    @Published var errorMessage: String? = nil

    let type: String  // "Reports" or "Rescues"

    init(type: String) {
        self.type = type
        loadIncidents()
    }

    func loadIncidents() {
        Task {
            isLoading = true
            errorMessage = nil

            guard let token = KeychainManager.shared.getString(key: .accessToken) else {
                let session = try? await supabase.auth.session
                if let t = session?.accessToken {
                    try? KeychainManager.shared.save(key: .accessToken, value: t)
                    await fetchIncidents(token: t)
                } else {
                    errorMessage = "Please log in again."
                    isLoading = false
                }
                return
            }

            await fetchIncidents(token: token)
        }
    }

    private func fetchIncidents(token: String) async {
        do {
            struct IncidentListResponse: Decodable {
                let incidents: [RecentActivityModel]
            }

            let isRescuerStat = type == "Rescues" || type == "Active Jobs"
            let endpoint: IncidentEndpoint =
                isRescuerStat
                ? .myRescues(token: token)
                : .myReports(token: token)

            let result: IncidentListResponse = try await NetworkManager.shared.request(
                endpoint: endpoint,
                keyDecodingStrategy: .useDefaultKeys
            )

            var filtered = result.incidents
            switch type {
            case "Animals Helped":
                filtered = filtered.filter {
                    let status = $0.status?.lowercased() ?? ""
                    return status == "rescued" || status == "rehabilitated" || status == "completed"
                }
            case "Active Reports":
                filtered = filtered.filter {
                    let status = $0.status?.lowercased() ?? ""
                    return status == "pending" || status == "dispatched" || status == "active"
                }
            case "Active Jobs":
                filtered = filtered.filter {
                    let status = $0.status?.lowercased() ?? ""
                    return status == "pending" || status == "dispatched" || status == "active"
                }
            case "Rescues":
                filtered = filtered.filter {
                    let status = $0.status?.lowercased() ?? ""
                    return status == "rescued" || status == "rehabilitated" || status == "completed"
                }
            default:
                break  // "Reports Filed" or others show all
            }

            incidents = filtered
            isLoading = false
        } catch {
            errorMessage = "Failed to load incidents."
            isLoading = false
        }
    }

    var emptyStateTitle: String {
        switch type {
        case "Reports Filed": return "No Reports Yet"
        case "Animals Helped": return "No Animals Helped"
        case "Active Reports": return "No Active Reports"
        case "Rescues": return "No Rescues Yet"
        case "Active Jobs": return "No Active Jobs"
        default: return "No Records"
        }
    }

    var emptyStateMessage: String {
        switch type {
        case "Reports Filed":
            return "When you report an animal in distress, your history will appear here."
        case "Animals Helped":
            return "Your completed reports will appear here once the animals are rescued."
        case "Active Reports": return "You don't have any ongoing rescue requests."
        case "Rescues": return "Completed rescues will show up here."
        case "Active Jobs": return "You don't have any active rescue jobs."
        default: return "Nothing to show here."
        }
    }

    var navigationTitle: String {
        return type
    }

    func severityColor(_ severity: String?) -> Color {
        switch severity?.lowercased() {
        case "severe": return AppConfig.Colors.alert
        case "moderate": return AppConfig.Colors.warning
        case "minor": return AppConfig.Colors.accent
        default: return AppConfig.Colors.textSecondary
        }
    }

    func statusColor(_ status: String?) -> Color {
        switch status?.lowercased() {
        case "pending": return AppConfig.Colors.warning
        case "dispatched", "active": return AppConfig.Colors.accent
        case "rescued", "rehabilitated": return AppConfig.Colors.success
        default: return AppConfig.Colors.textSecondary
        }
    }
}
