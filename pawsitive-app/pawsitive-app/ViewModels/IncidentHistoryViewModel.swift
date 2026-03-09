import Foundation
import SwiftUI
import Combine
import Supabase

@MainActor
class IncidentHistoryViewModel: ObservableObject {
    @Published var incidents: [RecentActivityModel] = []
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    
    let type: String // "Reports" or "Rescues"
    
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
            
            let endpoint: IncidentEndpoint = type == "Reports"
                ? .myReports(token: token)
                : .myRescues(token: token)
            
            let result: IncidentListResponse = try await NetworkManager.shared.request(
                endpoint: endpoint,
                keyDecodingStrategy: .useDefaultKeys
            )
            
            incidents = result.incidents
            isLoading = false
        } catch {
            errorMessage = "Failed to load incidents."
            isLoading = false
        }
    }
    
    func formattedDate(from dateStr: String?) -> String {
        guard let dateStr = dateStr else { return "Unknown" }
        
        let istZone = TimeZone(identifier: "Asia/Kolkata")!
        let parseZone = TimeZone(abbreviation: "UTC")!
        let posixLocale = Locale(identifier: "en_US_POSIX")
        
        let display = DateFormatter()
        display.dateFormat = "d MMM yyyy, h:mm a"
        display.timeZone = istZone
        
        let parser = DateFormatter()
        parser.locale = posixLocale
        parser.timeZone = parseZone
        
        // Supabase formats: "2026-03-09T14:04:14.820905" or "2026-03-09 13:58:52.223264"
        let formats = [
            "yyyy-MM-dd'T'HH:mm:ss.SSSSSS",
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd HH:mm:ss.SSSSSS",
            "yyyy-MM-dd HH:mm:ss",
        ]
        for fmt in formats {
            parser.dateFormat = fmt
            if let date = parser.date(from: dateStr) {
                return display.string(from: date)
            }
        }
        
        // ISO8601 fallback
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: dateStr) {
            return display.string(from: date)
        }
        iso.formatOptions = [.withInternetDateTime]
        if let date = iso.date(from: dateStr) {
            return display.string(from: date)
        }
        
        return dateStr
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
