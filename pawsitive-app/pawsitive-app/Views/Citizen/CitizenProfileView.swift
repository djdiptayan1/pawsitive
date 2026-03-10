import DotLottie
import PhotosUI
import SVGView
import SwiftUI

struct CitizenProfileView: View {
    @EnvironmentObject var session: SessionViewModel
    @StateObject private var viewModel: CitizenProfileViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPhotoItem: PhotosPickerItem? = nil

    init() {
        _viewModel = StateObject(
            wrappedValue: CitizenProfileViewModel(sessionVM: SessionViewModel()))
    }

    init(sessionVM: SessionViewModel? = nil) {
        if let sessionVM = sessionVM {
            _viewModel = StateObject(wrappedValue: CitizenProfileViewModel(sessionVM: sessionVM))
        } else {
            _viewModel = StateObject(
                wrappedValue: CitizenProfileViewModel(sessionVM: SessionViewModel()))
        }
    }

    var body: some View {
        NavigationStack {
            if viewModel.isLoading {
                VStack(spacing: 16) {
                    DotLottieAnimation(
                        fileName: "loading",
                        config: AnimationConfig(autoplay: true, loop: true)
                    )
                    .view()
                    .frame(width: 120, height: 120)

                    Text("Loading profile...")
                        .font(AppConfig.Fonts.body)
                        .foregroundColor(AppConfig.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppConfig.Colors.background.ignoresSafeArea())
                .navigationTitle("Profile")
                .navigationBarTitleDisplayMode(.inline)
            } else {
                ScrollView {
                    VStack(spacing: 28) {
                        // MARK: - Avatar & Name
                        VStack(spacing: 12) {
                            avatarView
                                .frame(width: 110, height: 110)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(AppConfig.Colors.background, lineWidth: 6))
                                .shadow(
                                    color: AppConfig.Colors.accent.opacity(0.2), radius: 12, x: 0,
                                    y: 8)

                            VStack(spacing: 4) {
                                Text(viewModel.fullName)
                                    .font(AppConfig.Fonts.titleMedium)
                                    .foregroundColor(AppConfig.Colors.textPrimary)

                                Text(viewModel.email)
                                    .font(AppConfig.Fonts.body)
                                    .foregroundColor(AppConfig.Colors.textSecondary)
                            }
                        }
                        .padding(.top, 24)

                        // MARK: - Impact Stats
                        VStack(alignment: .leading, spacing: 16) {
                            HStack(spacing: 12) {
                                ForEach(viewModel.impactStats) { stat in
                                    NavigationLink(
                                        destination: IncidentHistoryView(type: stat.title)
                                    ) {
                                        VStack(spacing: 10) {
                                            Image(systemName: stat.icon)
                                                .font(.system(size: 24, weight: .medium))
                                                .foregroundColor(AppConfig.Colors.accent)

                                            VStack(spacing: 2) {
                                                Text(stat.value)
                                                    .font(
                                                        .system(
                                                            size: 24, weight: .bold,
                                                            design: .rounded)
                                                    )
                                                    .foregroundColor(AppConfig.Colors.textPrimary)

                                                Text(stat.title)
                                                    .font(
                                                        .system(
                                                            size: 12, weight: .medium,
                                                            design: .rounded)
                                                    )
                                                    .foregroundColor(AppConfig.Colors.textSecondary)
                                                    .multilineTextAlignment(.center)
                                                    .lineLimit(2)
                                            }
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 20)
                                        .padding(.horizontal, 8)
                                        .background(AppConfig.Colors.card)
                                        .cornerRadius(AppConfig.UI.cornerRadius)
                                        .shadow(
                                            color: Color.black.opacity(0.04),
                                            radius: AppConfig.UI.cardShadowRadius, x: 0,
                                            y: AppConfig.UI.cardShadowOffsetY)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, AppConfig.UI.screenPadding)

                        // MARK: - Badges
                        badgesSection

                        Spacer(minLength: 24)

                        // MARK: - Sign Out
                        Button(action: {
                            Task { await viewModel.signOut() }
                        }) {
                            HStack {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                Text("Sign Out")
                            }
                            .font(AppConfig.Fonts.bodyBold)
                            .foregroundColor(AppConfig.Colors.alert)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(AppConfig.Colors.alert.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: AppConfig.UI.buttonCornerRadius)
                                    .stroke(AppConfig.Colors.alert.opacity(0.3), lineWidth: 1)
                            )
                            .cornerRadius(AppConfig.UI.buttonCornerRadius)
                        }
                        .padding(.horizontal, AppConfig.UI.screenPadding)
                        .padding(.bottom, 32)
                    }
                }
                .background(AppConfig.Colors.background.ignoresSafeArea())
                .navigationTitle("Profile")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { dismiss() }
                            .font(AppConfig.Fonts.bodyBold)
                            .foregroundColor(AppConfig.Colors.accent)
                    }
                }
            }
        }
    }

    // MARK: - Badges Section

    @ViewBuilder
    private var badgesSection: some View {
        let badges: [(emoji: String, title: String, subtitle: String, isEarned: Bool)] = [
            ("📱", "First Report", "File 1 report", viewModel.reportsFiled >= 1),
            ("🐾", "Animal Friend", "Help rescue 1 animal", viewModel.animalsHelped >= 1),
            ("📋", "Active Reporter", "File 5 reports", viewModel.reportsFiled >= 5),
            ("🦸", "Community Hero", "Help rescue 5 animals", viewModel.animalsHelped >= 5),
            ("🌟", "Pawsitive Star", "File 10 reports", viewModel.reportsFiled >= 10),
            ("🏆", "Guardian Angel", "Help rescue 10 animals", viewModel.animalsHelped >= 10),
        ]

        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Badges")
                    .font(AppConfig.Fonts.headline)
                    .foregroundColor(AppConfig.Colors.textPrimary)
                Spacer()
            }
            .padding(.horizontal, AppConfig.UI.screenPadding)

            let columns = [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12),
            ]

            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(Array(badges.enumerated()), id: \.offset) { _, badge in
                    citizenBadgeItem(
                        emoji: badge.emoji,
                        title: badge.title,
                        subtitle: badge.subtitle,
                        isEarned: badge.isEarned
                    )
                }
            }
            .padding(.horizontal, AppConfig.UI.screenPadding)
        }
    }

    @ViewBuilder
    private func citizenBadgeItem(emoji: String, title: String, subtitle: String, isEarned: Bool)
        -> some View
    {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(
                        isEarned
                            ? AppConfig.Colors.accent.opacity(0.15)
                            : Color.gray.opacity(0.08)
                    )
                    .frame(width: 56, height: 56)

                Text(emoji)
                    .font(.system(size: 26))
                    .opacity(isEarned ? 1.0 : 0.3)
                    .grayscale(isEarned ? 0.0 : 1.0)
            }

            VStack(spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(
                        isEarned ? AppConfig.Colors.textPrimary : AppConfig.Colors.textSecondary
                    )
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                Text(subtitle)
                    .font(.system(size: 10, weight: .regular, design: .rounded))
                    .foregroundColor(AppConfig.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .padding(.horizontal, 4)
        .background(AppConfig.Colors.card)
        .cornerRadius(AppConfig.UI.cornerRadius)
        .shadow(
            color: Color.black.opacity(isEarned ? 0.06 : 0.02),
            radius: AppConfig.UI.cardShadowRadius, x: 0,
            y: AppConfig.UI.cardShadowOffsetY)
        .overlay(
            RoundedRectangle(cornerRadius: AppConfig.UI.cornerRadius)
                .stroke(
                    isEarned ? AppConfig.Colors.accent.opacity(0.3) : Color.clear,
                    lineWidth: 1.5)
        )
    }

    // MARK: - Avatar View

    @ViewBuilder
    private var avatarView: some View {
        if let base64 = viewModel.avatarBase64,
            base64.hasPrefix("data:image/svg+xml;base64,"),
            let svgData = Data(
                base64Encoded: base64.replacingOccurrences(
                    of: "data:image/svg+xml;base64,", with: "")),
            let svgText = String(data: svgData, encoding: .utf8)
        {
            SVGView(string: svgText)
        } else if let avatarUrl = viewModel.avatarUrl {
            AsyncImage(url: avatarUrl) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFill()
                } else if phase.error != nil {
                    Image("Group 1").resizable().scaledToFill()
                } else {
                    ProgressView()
                }
            }
        } else {
            Image("Group 1").resizable().scaledToFill()
        }
    }
}
