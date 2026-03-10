import Combine
import PhotosUI
import Supabase
import SwiftUI
import UIKit

@MainActor
class CitizenProfileViewModel: BaseProfileViewModel {

    @Published var reportsFiled: Int = 0
    @Published var animalsHelped: Int = 0

    override init(sessionVM: SessionViewModel) {
        super.init(sessionVM: sessionVM)

        // Stubbed Data for Impact & Activity
        self.impactStats = [
            ImpactStat(title: "Animals Helped", value: "-", icon: "pawprint.fill"),
            ImpactStat(title: "Reports Filed", value: "-", icon: "doc.text.fill"),
            ImpactStat(title: "Active Reports", value: "-", icon: "exclamationmark.circle.fill"),
        ]

        loadProfile()
    }

    func loadProfile() {
        Task {
            do {
                if let session = try? await supabase.auth.session {
                    let userEmail = session.user.email ?? "Unknown Email"
                    await fetchAndUpdateProfile(email: userEmail)
                } else {
                    await fetchAndUpdateProfile(email: "Unknown Email")
                }
            }
        }
    }

    private func fetchAndUpdateProfile(email: String) async {
        do {
            let result: ProfileResponse = try await NetworkManager.shared.request(
                endpoint: AuthEndpoint.getProfile(token: ""),  // Token injected by NetworkManager automatically from here on
                keyDecodingStrategy: .useDefaultKeys
            )

            DispatchQueue.main.async {
                self.email = result.user.email
                self.fullName = result.user.fullName ?? "Citizen User"

                self.parseAvatarUrl(result.user.avatarUrl)

                let totalReports = result.user.reportsFiled ?? 0
                let activeReports = result.user.activeReports ?? 0
                let animalsHelped = result.user.animalsHelped ?? 0

                self.reportsFiled = totalReports
                self.animalsHelped = animalsHelped

                self.impactStats = [
                    ImpactStat(
                        title: "Animals Helped", value: "\(animalsHelped)", icon: "pawprint.fill"),
                    ImpactStat(
                        title: "Reports Filed", value: "\(totalReports)", icon: "doc.text.fill"),
                    ImpactStat(
                        title: "Active Reports", value: "\(activeReports)",
                        icon: "exclamationmark.circle.fill"),
                ]

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
}
