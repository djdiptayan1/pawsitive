import Combine
import PhotosUI
import Supabase
import SwiftUI
import UIKit

@MainActor
class RescuerProfileViewModel: BaseProfileViewModel {
    @Published var isVerified: Bool = false
    @Published var ngoName: String? = nil
    @Published var operatingCity: String? = nil

    override init(sessionVM: SessionViewModel) {
        super.init(sessionVM: sessionVM)

        // Stubbed Data for Impact & Activity explicitly for rescuers
        self.impactStats = [
            ImpactStat(title: "Rescues", value: "34", icon: "cross.case.fill"),
            ImpactStat(title: "Active Hours", value: "120", icon: "clock.fill"),
            ImpactStat(title: "Rating", value: "4.9", icon: "star.fill"),
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
                endpoint: AuthEndpoint.getProfile(token: ""),  // Handled by NetworkManager
                keyDecodingStrategy: .useDefaultKeys
            )

            DispatchQueue.main.async {
                self.email = result.user.email
                self.fullName = result.user.fullName ?? "Rescuer"
                self.isVerified = result.user.verifiedRescuer
                self.ngoName = result.user.ngo?.name
                self.operatingCity = result.user.ngo?.operatingCity

                self.parseAvatarUrl(result.user.avatarUrl)

                let rescuesCompleted = result.user.rescuesCompleted ?? 0
                let activeRescues = result.user.activeRescues ?? 0
                let activeHours = rescuesCompleted * 2  // rough estimation for dummy stats

                self.impactStats = [
                    ImpactStat(
                        title: "Rescues", value: "\(rescuesCompleted)", icon: "cross.case.fill"),
                    ImpactStat(title: "Active Jobs", value: "\(activeRescues)", icon: "clock.fill"),
                    ImpactStat(
                        title: "Active Hours", value: "\(activeHours > 0 ? activeHours : 120)",
                        icon: "star.fill"),
                ]

                if let activities = result.user.recentActivities {
                    self.recentActivities = Array(activities.prefix(2))
                }
                self.isLoading = false
            }
        } catch {
            DispatchQueue.main.async {
                self.email = email
                self.fullName = "Rescuer"
                self.isLoading = false
            }
        }
    }
}
