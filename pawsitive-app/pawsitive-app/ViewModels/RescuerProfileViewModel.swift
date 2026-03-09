import Combine
import PhotosUI
import Supabase
import SwiftUI
import UIKit

@MainActor
class RescuerProfileViewModel: ObservableObject {
    @Published var fullName: String = ""
    @Published var email: String = ""
    @Published var avatarUrl: URL? = nil
    @Published var avatarBase64: String? = nil

    @Published var isVerified: Bool = false
    @Published var ngoName: String? = nil
    @Published var operatingCity: String? = nil

    @Published var isUploadingAvatar: Bool = false
    @Published var avatarUploadError: String? = nil

    // Stubbed Data for Impact & Activity explicitly for rescuers
    @Published var impactStats: [ImpactStat] = [
        ImpactStat(title: "Rescues", value: "34", icon: "cross.case.fill"),
        ImpactStat(title: "Active Hours", value: "120", icon: "clock.fill"),
        ImpactStat(title: "Rating", value: "4.9", icon: "star.fill"),
    ]

    @Published var recentActivities: [RecentActivityModel] = []

    private let sessionVM: SessionViewModel

    init(sessionVM: SessionViewModel) {
        self.sessionVM = sessionVM
        loadProfile()
    }

    func loadProfile() {
        Task {
            do {
                guard let token = KeychainManager.shared.getString(key: .accessToken) else {
                    let session = try await supabase.auth.session
                    let user = session.user
                    let freshToken = session.accessToken
                    try? KeychainManager.shared.save(key: .accessToken, value: freshToken)
                    try? KeychainManager.shared.save(key: .userID, value: user.id.uuidString)
                    await fetchAndUpdateProfile(
                        token: freshToken, email: user.email ?? "Unknown Email")
                    return
                }
                let session = try await supabase.auth.session
                let userEmail = session.user.email ?? "Unknown Email"
                await fetchAndUpdateProfile(token: token, email: userEmail)
            } catch {
                DispatchQueue.main.async {
                    self.email = "Error loading profile"
                    self.fullName = "Error"
                }
            }
        }
    }

    private func fetchAndUpdateProfile(token: String, email: String) async {
        do {
            let result: ProfileResponse = try await NetworkManager.shared.request(
                endpoint: AuthEndpoint.getProfile(token: token),
                keyDecodingStrategy: .useDefaultKeys
            )

            DispatchQueue.main.async {
                self.email = result.user.email
                self.fullName = result.user.fullName ?? "Rescuer"
                self.isVerified = result.user.verifiedRescuer
                self.ngoName = result.user.ngo?.name
                self.operatingCity = result.user.ngo?.operatingCity

                if let avatarUrlString = result.user.avatarUrl, !avatarUrlString.isEmpty {
                    if avatarUrlString.hasPrefix("http://") || avatarUrlString.hasPrefix("https://")
                    {
                        if let realURL = URL(string: avatarUrlString) {
                            self.avatarUrl = realURL
                            self.avatarBase64 = nil
                        }
                    } else if avatarUrlString.hasPrefix("data:image") {
                        self.avatarBase64 = avatarUrlString
                        self.avatarUrl = nil
                    } else if avatarUrlString.count > 100 {
                        self.avatarBase64 = "data:image/svg+xml;base64," + avatarUrlString
                        self.avatarUrl = nil
                    }
                }

                let rescuesCompleted = result.user.rescuesCompleted ?? 0
                let activeRescues = result.user.activeRescues ?? 0
                let activeHours = rescuesCompleted * 2  // rough estimation for dummy stats

                self.impactStats = [
                    ImpactStat(
                        title: "Rescues", value: "\(rescuesCompleted)", icon: "cross.case.fill"),
                    ImpactStat(title: "Active Jobs", value: "\(activeRescues)", icon: "clock.fill"),  // Using this for Active Rescues
                    ImpactStat(
                        title: "Active Hours", value: "\(activeHours > 0 ? activeHours : 120)",
                        icon: "star.fill"),
                ]

                // Map recent activities
                if let activities = result.user.recentActivities {
                    self.recentActivities = Array(activities.prefix(2))
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.email = email
                self.fullName = "Rescuer"
            }
        }
    }

    // MARK: - Helpers
    static func formatSupabaseDate(_ dateStr: String?) -> String {
        guard let dateStr = dateStr else { return "Recently" }

        let istZone = TimeZone(identifier: "Asia/Kolkata")!
        let parseZone = TimeZone(abbreviation: "UTC")!
        let posixLocale = Locale(identifier: "en_US_POSIX")

        let display = DateFormatter()
        display.dateFormat = "d MMM yyyy, h:mm a"
        display.timeZone = istZone

        let parser = DateFormatter()
        parser.locale = posixLocale
        parser.timeZone = parseZone

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

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: dateStr) {
            return display.string(from: date)
        }
        iso.formatOptions = [.withInternetDateTime]
        if let date = iso.date(from: dateStr) {
            return display.string(from: date)
        }
        return "Recently"
    }

    func uploadAvatar(image: UIImage) async {
        DispatchQueue.main.async {
            self.isUploadingAvatar = true
            self.avatarUploadError = nil
        }

        do {
            guard let imageData = image.jpegData(compressionQuality: 0.8) else {
                throw NSError(
                    domain: "ImageError", code: 0,
                    userInfo: [NSLocalizedDescriptionKey: "Could not compress image"])
            }

            let base64String = "data:image/jpeg;base64," + imageData.base64EncodedString()

            // Get token
            let token: String
            if let keychainToken = KeychainManager.shared.getString(key: .accessToken) {
                token = keychainToken
            } else {
                let session = try await supabase.auth.session
                token = session.accessToken
                try? KeychainManager.shared.save(key: .accessToken, value: token)
            }

            struct AvatarResponse: Decodable {
                let avatarUrl: String
            }

            let result: AvatarResponse = try await NetworkManager.shared.request(
                endpoint: AuthEndpoint.uploadAvatar(token: token, base64: base64String)
            )

            DispatchQueue.main.async {
                if let newURL = URL(string: result.avatarUrl) {
                    self.avatarUrl = newURL
                    self.avatarBase64 = nil
                }
                self.isUploadingAvatar = false
            }

        } catch {
            DispatchQueue.main.async {
                self.avatarUploadError = error.localizedDescription
                self.isUploadingAvatar = false
            }
        }
    }

    func signOut() async {
        sessionVM.logout()
    }
}
