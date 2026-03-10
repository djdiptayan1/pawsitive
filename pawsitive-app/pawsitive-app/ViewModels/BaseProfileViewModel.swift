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
class BaseProfileViewModel: ObservableObject {
    @Published var fullName: String = ""
    @Published var email: String = ""
    @Published var avatarUrl: URL? = nil
    @Published var avatarBase64: String? = nil

    @Published var isUploadingAvatar: Bool = false
    @Published var avatarUploadError: String? = nil
    @Published var isLoading: Bool = true

    @Published var impactStats: [ImpactStat] = []
    @Published var recentActivities: [RecentActivityModel] = []

    let sessionVM: SessionViewModel

    init(sessionVM: SessionViewModel) {
        self.sessionVM = sessionVM
    }

    func parseAvatarUrl(_ avatarUrlString: String?) {
        guard let urlString = avatarUrlString, !urlString.isEmpty else { return }

        if urlString.hasPrefix("http://") || urlString.hasPrefix("https://") {
            if let realURL = URL(string: urlString) {
                self.avatarUrl = realURL
                self.avatarBase64 = nil
            }
        } else if urlString.hasPrefix("data:image") {
            self.avatarBase64 = urlString
            self.avatarUrl = nil
        } else if urlString.count > 100 {
            if let data = Data(base64Encoded: urlString),
                let svgString = String(data: data, encoding: .utf8),
                svgString.contains("<svg")
            {
                self.avatarBase64 = "data:image/svg+xml;base64,\(urlString)"
                self.avatarUrl = nil
            } else {
                self.avatarBase64 = "data:image/jpeg;base64,\(urlString)"
                self.avatarUrl = nil
            }
        }
    }

    func uploadAvatar(image: UIImage) async {
        isUploadingAvatar = true
        avatarUploadError = nil

        do {
            guard let imageData = image.jpegData(compressionQuality: 0.8) else {
                throw NSError(
                    domain: "ImageError", code: 0,
                    userInfo: [NSLocalizedDescriptionKey: "Could not compress image"])
            }

            let base64String = "data:image/jpeg;base64," + imageData.base64EncodedString()

            struct AvatarResponse: Decodable {
                let avatarUrl: String
            }

            let result: AvatarResponse = try await NetworkManager.shared.request(
                endpoint: AuthEndpoint.uploadAvatar(token: "", base64: base64String)  // Token is now handled in NetworkManager
            )

            if let newURL = URL(string: result.avatarUrl) {
                self.avatarUrl = newURL
                self.avatarBase64 = nil
            }
            self.isUploadingAvatar = false

        } catch {
            self.avatarUploadError = error.localizedDescription
            self.isUploadingAvatar = false
        }
    }

    func signOut() async {
        sessionVM.logout()
    }
}
