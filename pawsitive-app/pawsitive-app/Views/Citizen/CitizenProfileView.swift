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

                        // MARK: - Recent Activity
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Recent Activity")
                                    .font(AppConfig.Fonts.headline)
                                    .foregroundColor(AppConfig.Colors.textPrimary)
                                Spacer()
                            }
                            .padding(.horizontal, AppConfig.UI.screenPadding)

                            VStack(spacing: 16) {
                                ForEach(viewModel.recentActivities) { activity in
                                    ActivityCardView(activity: activity)
                                        .padding(.horizontal, AppConfig.UI.screenPadding)
                                }
                            }
                        }

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
