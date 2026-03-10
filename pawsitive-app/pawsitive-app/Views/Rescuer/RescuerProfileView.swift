//
//  RescuerProfileView.swift
//  pawsitive-app
//
//  Created by Diptayan Jash on 09/03/26.
//

import DotLottie
import PhotosUI
import SVGView
import SwiftUI

struct RescuerProfileView: View {
    @EnvironmentObject var session: SessionViewModel
    @StateObject private var viewModel: RescuerProfileViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPhotoItem: PhotosPickerItem? = nil

    init() {
        _viewModel = StateObject(
            wrappedValue: RescuerProfileViewModel(sessionVM: SessionViewModel()))
    }

    init(sessionVM: SessionViewModel? = nil) {
        if let sessionVM = sessionVM {
            _viewModel = StateObject(wrappedValue: RescuerProfileViewModel(sessionVM: sessionVM))
        } else {
            _viewModel = StateObject(
                wrappedValue: RescuerProfileViewModel(sessionVM: SessionViewModel()))
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
                .navigationTitle("My Profile")
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
                                HStack(spacing: 4) {
                                    Text(viewModel.fullName)
                                        .font(AppConfig.Fonts.titleMedium)
                                        .foregroundColor(AppConfig.Colors.textPrimary)

                                    if viewModel.isVerified {
                                        Image(systemName: "checkmark.seal.fill")
                                            .foregroundColor(AppConfig.Colors.success)
                                    }
                                }

                                Text(viewModel.email)
                                    .font(AppConfig.Fonts.body)
                                    .foregroundColor(AppConfig.Colors.textSecondary)

                                if let ngoName = viewModel.ngoName {
                                    HStack(spacing: 4) {
                                        Image(systemName: "building.2.fill")
                                            .foregroundColor(AppConfig.Colors.accent)
                                            .font(.system(size: 14))
                                        Text(ngoName)
                                            .font(AppConfig.Fonts.small)
                                            .foregroundColor(AppConfig.Colors.textSecondary)
                                    }
                                    .padding(.top, 4)
                                }
                            }
                        }
                        .padding(.top, 24)

                        // MARK: - Pawsitive Credits
                        creditsSection

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

                        // MARK: - Recent Activity
                        if !viewModel.recentActivities.isEmpty {
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
                .navigationTitle("My Profile")
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

    // MARK: - Pawsitive Credits Section
    @ViewBuilder
    private var creditsSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                // Tier Badge
                Text(viewModel.tierBadge)
                    .font(.system(size: 40))

                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.tierName)
                        .font(AppConfig.Fonts.headline)
                        .foregroundColor(AppConfig.Colors.textPrimary)

                    HStack(spacing: 4) {
                        Image(systemName: "star.circle.fill")
                            .foregroundColor(AppConfig.Colors.accent)
                            .font(.system(size: 16))
                        Text("\(viewModel.totalCredits)")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(AppConfig.Colors.accent)
                        Text("Pawsitive Credits")
                            .font(AppConfig.Fonts.small)
                            .foregroundColor(AppConfig.Colors.textSecondary)
                    }
                }

                Spacer()
            }

            // Tier progress bar
            tierProgressBar
        }
        .padding(AppConfig.UI.padding)
        .background(AppConfig.Colors.card)
        .cornerRadius(AppConfig.UI.cornerRadius)
        .shadow(
            color: Color.black.opacity(0.04),
            radius: AppConfig.UI.cardShadowRadius, x: 0,
            y: AppConfig.UI.cardShadowOffsetY)
        .padding(.horizontal, AppConfig.UI.screenPadding)
    }

    // MARK: - Tier Progress Bar
    @ViewBuilder
    private var tierProgressBar: some View {
        let credits = viewModel.totalCredits
        let (currentMin, nextMin, nextTier) = tierThresholds(credits: credits)
        let range = max(nextMin - currentMin, 1)
        let progress = min(Double(credits - currentMin) / Double(range), 1.0)

        VStack(spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(AppConfig.Colors.accent.opacity(0.15))
                        .frame(height: 10)

                    RoundedRectangle(cornerRadius: 6)
                        .fill(AppConfig.Colors.accent)
                        .frame(width: geo.size.width * progress, height: 10)
                }
            }
            .frame(height: 10)

            HStack {
                Text("\(credits) / \(nextMin)")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(AppConfig.Colors.textSecondary)
                Spacer()
                Text("Next: \(nextTier)")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(AppConfig.Colors.textSecondary)
            }
        }
    }

    private func tierThresholds(credits: Int) -> (Int, Int, String) {
        if credits >= 1000 { return (1000, 2000, "Legend") }
        if credits >= 500 { return (500, 1000, "Pawsitive Hero") }
        if credits >= 100 { return (100, 500, "Elite Rescuer") }
        return (0, 100, "Responder")
    }

    // MARK: - Badges Section
    @ViewBuilder
    private var badgesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Badges")
                    .font(AppConfig.Fonts.headline)
                    .foregroundColor(AppConfig.Colors.textPrimary)
                Spacer()
            }
            .padding(.horizontal, AppConfig.UI.screenPadding)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    badgeItem(
                        emoji: "🐾", title: "First Rescue",
                        isEarned: (Int(
                            viewModel.impactStats.first(where: { $0.title == "Rescues" })?.value
                                ?? "0") ?? 0) >= 1)
                    badgeItem(
                        emoji: "⚡", title: "Speed Hero",
                        isEarned: viewModel.totalCredits >= 50)
                    badgeItem(
                        emoji: "🏅", title: "Top Responder",
                        isEarned: viewModel.totalCredits >= 100)
                    badgeItem(
                        emoji: "💪", title: "10 Rescues",
                        isEarned: (Int(
                            viewModel.impactStats.first(where: { $0.title == "Rescues" })?.value
                                ?? "0") ?? 0) >= 10)
                    badgeItem(
                        emoji: "🏆", title: "Pawsitive Hero",
                        isEarned: viewModel.totalCredits >= 1000)
                }
                .padding(.horizontal, AppConfig.UI.screenPadding)
            }
        }
    }

    @ViewBuilder
    private func badgeItem(emoji: String, title: String, isEarned: Bool) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(
                        isEarned
                            ? AppConfig.Colors.accent.opacity(0.15)
                            : Color.gray.opacity(0.1)
                    )
                    .frame(width: 60, height: 60)

                Text(emoji)
                    .font(.system(size: 28))
                    .opacity(isEarned ? 1.0 : 0.3)
            }

            Text(title)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(
                    isEarned ? AppConfig.Colors.textPrimary : AppConfig.Colors.textSecondary
                )
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(width: 80)
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

struct RescuerProfileViewWrapper: View {
    @EnvironmentObject var session: SessionViewModel
    var body: some View {
        RescuerProfileView(sessionVM: session)
    }
}

#Preview {
    // Workaround for #Preview macros using multi-statement
    VStack {
        let mockSession = SessionViewModel()
        let _ = mockSession.isLoggedIn = true
        let _ = mockSession.role = .rescuer

        RescuerProfileView(sessionVM: mockSession)
            .environmentObject(mockSession)
    }
}
