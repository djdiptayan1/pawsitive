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

    // Pawsitive Credits
    @Published var totalCredits: Int = 0
    @Published var tierName: String = "Volunteer"
    @Published var tierBadge: String = "🥉"

    override init(sessionVM: SessionViewModel) {
        super.init(sessionVM: sessionVM)

        self.impactStats = [
            ImpactStat(title: "Rescues", value: "-", icon: "cross.case.fill"),
            ImpactStat(title: "Active Jobs", value: "-", icon: "bolt.heart.fill"),
            ImpactStat(title: "Rating", value: "-", icon: "star.fill"),
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
                endpoint: AuthEndpoint.getProfile(token: ""),
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

                self.impactStats = [
                    ImpactStat(
                        title: "Rescues", value: "\(rescuesCompleted)", icon: "cross.case.fill"),
                    ImpactStat(
                        title: "Active Jobs", value: "\(activeRescues)", icon: "bolt.heart.fill"),
                    ImpactStat(title: "Rating", value: "4.9", icon: "star.fill"),
                ]

                // Pawsitive Credits
                self.totalCredits = result.user.totalCredits ?? 0
                self.tierName = result.user.tierName ?? "Volunteer"
                self.tierBadge = result.user.tierBadge ?? "🥉"

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
