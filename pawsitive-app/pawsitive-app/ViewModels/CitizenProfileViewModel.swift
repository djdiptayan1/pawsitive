import Combine
import PhotosUI
import Supabase
import SwiftUI
import UIKit

// Simplified models for the view
struct ImpactStat: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let icon: String  // SF Symbol name
}

@MainActor
class CitizenProfileViewModel: ObservableObject {
    @Published var fullName: String = ""
    @Published var email: String = ""
    @Published var avatarUrl: URL? = nil

    @Published var avatarBase64: String? = nil
    @Published var isUploadingAvatar: Bool = false
    @Published var avatarUploadError: String? = nil
    @Published var isLoading: Bool = true

    // Stubbed Data for Impact & Activity
    @Published var impactStats: [ImpactStat] = [
        ImpactStat(title: "Animals Helped", value: "-", icon: "pawprint.fill"),
        ImpactStat(title: "Reports Filed", value: "-", icon: "doc.text.fill"),
        ImpactStat(title: "Active Reports", value: "-", icon: "exclamationmark.circle.fill"),
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
                    let token = session.accessToken
                    try? KeychainManager.shared.save(key: .accessToken, value: token)
                    try? KeychainManager.shared.save(key: .userID, value: user.id.uuidString)
                    await fetchAndUpdateProfile(token: token, email: user.email ?? "Unknown Email")
                    return
                }
                let session = try await supabase.auth.session
                let userEmail = session.user.email ?? "Unknown Email"
                await fetchAndUpdateProfile(token: token, email: userEmail)
            } catch {
                DispatchQueue.main.async {
                    self.email = "Error loading profile"
                    self.fullName = "Error"
                    self.isLoading = false
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
                self.fullName = result.user.fullName ?? "Citizen User"

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
                        if let data = Data(base64Encoded: avatarUrlString),
                            let svgString = String(data: data, encoding: .utf8),
                            svgString.contains("<svg")
                        {
                            self.avatarBase64 = "data:image/svg+xml;base64,\(avatarUrlString)"
                            self.avatarUrl = nil
                        } else {
                            self.avatarBase64 = "data:image/jpeg;base64,\(avatarUrlString)"
                            self.avatarUrl = nil
                        }
                    }
                }

                // Update impact stats dynamically
                let totalReports = result.user.reportsFiled ?? 0
                let activeReports = result.user.activeReports ?? 0
                let animalsHelped = result.user.animalsHelped ?? 0

                self.impactStats = [
                    ImpactStat(
                        title: "Animals Helped", value: "\(animalsHelped)", icon: "pawprint.fill"),
                    ImpactStat(
                        title: "Reports Filed", value: "\(totalReports)", icon: "doc.text.fill"),
                    ImpactStat(
                        title: "Active Reports", value: "\(activeReports)",
                        icon: "exclamationmark.circle.fill"),
                ]

                // Map recent activities
                if let activities = result.user.recentActivities {
                    self.recentActivities = Array(activities.prefix(2))
                }
                self.isLoading = false
            }
        } catch {
            DispatchQueue.main.async {
                self.email = email
                self.fullName = "Citizen User"
                self.isLoading = false
            }
        }
    }

    // MARK: - Helpers
    private static func formatSupabaseDate(_ dateStr: String?) -> String {
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
            // Convert UIImage to base64
            guard let imageData = image.jpegData(compressionQuality: 0.8) else {
                throw NSError(
                    domain: "ImageError", code: 0,
                    userInfo: [NSLocalizedDescriptionKey: "Could not compress image"])
            }

            print("✅ [ProfileVM] Compressed image to \(imageData.count) bytes")
            let base64String = "data:image/jpeg;base64," + imageData.base64EncodedString()
            print("✅ [ProfileVM] Converted to base64 (\(base64String.count) chars)")

            // Get token from keychain
            guard let token = KeychainManager.shared.getString(key: .accessToken) else {
                print("❌ [ProfileVM] No access token in keychain, fetching fresh token...")
                let session = try await supabase.auth.session
                let token = session.accessToken
                try? KeychainManager.shared.save(key: .accessToken, value: token)

                return await uploadAvatarWithToken(token: token, base64: base64String)
            }

            await uploadAvatarWithToken(token: token, base64: base64String)

        } catch {
            print("❌ [ProfileVM] Avatar upload error: \(error)")
            DispatchQueue.main.async {
                self.avatarUploadError = error.localizedDescription
                self.isUploadingAvatar = false
            }
        }
    }

    private func uploadAvatarWithToken(token: String, base64: String) async {
        do {
            print("🌐 [ProfileVM] Uploading avatar to backend...")

            struct AvatarResponse: Decodable {
                let avatarUrl: String
            }

            let result: AvatarResponse = try await NetworkManager.shared.request(
                endpoint: AuthEndpoint.uploadAvatar(token: token, base64: base64)
            )

            print("✅ [ProfileVM] Avatar uploaded successfully: \(result.avatarUrl)")

            DispatchQueue.main.async {
                if let newURL = URL(string: result.avatarUrl) {
                    self.avatarUrl = newURL
                    self.avatarBase64 = nil
                }
                self.isUploadingAvatar = false
            }
        } catch {
            print("❌ [ProfileVM] Failed to upload avatar: \(error)")
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
