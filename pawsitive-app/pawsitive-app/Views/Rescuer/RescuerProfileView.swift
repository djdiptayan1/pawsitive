//
//  RescuerProfileView.swift
//  pawsitive-app
//
//  Created by Diptayan Jash on 09/03/26.
//

import PhotosUI
import SVGView
import SwiftUI

struct RescuerProfileView: View {
    @EnvironmentObject var session: SessionViewModel
    @StateObject private var viewModel: RescuerProfileViewModel

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
            ScrollView {
                VStack(spacing: 24) {
                    // MARK: - Header / Avatar
                    VStack(spacing: 4) {
                        ZStack(alignment: .bottomTrailing) {
                            Group {
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
                            .frame(width: 140, height: 140)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.white, lineWidth: 4))
                            .shadow(
                                color: Color.black.opacity(0.1),
                                radius: AppConfig.UI.cardShadowRadius, x: 0,
                                y: AppConfig.UI.cardShadowOffsetY)
                        }
                    }

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
                            HStack {
                                Image(systemName: "building.2.fill")
                                    .foregroundColor(AppConfig.Colors.accent)
                                Text(ngoName)
                                    .font(AppConfig.Fonts.small)
                                    .foregroundColor(AppConfig.Colors.textSecondary)
                            }
                            .padding(.top, 4)
                        }
                    }
                    .padding(.top, 16)

                    // MARK: - Impact Stats
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Rescue Impact")
                            .font(AppConfig.Fonts.headline)
                            .foregroundColor(AppConfig.Colors.textPrimary)

                        HStack(spacing: 16) {
                            ForEach(viewModel.impactStats) { stat in
                                VStack(spacing: 8) {
                                    Image(systemName: stat.icon)
                                        .font(.title2)
                                        .foregroundColor(AppConfig.Colors.accent)

                                    Text(stat.value)
                                        .font(.title3.bold())
                                        .foregroundColor(AppConfig.Colors.textPrimary)

                                    Text(stat.title)
                                        .font(AppConfig.Fonts.small)
                                        .foregroundColor(AppConfig.Colors.textSecondary)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(AppConfig.UI.padding)
                                .background(AppConfig.Colors.card)
                                .cornerRadius(AppConfig.UI.cornerRadius)
                                .shadow(
                                    color: Color.black.opacity(0.05),
                                    radius: AppConfig.UI.cardShadowRadius, x: 0,
                                    y: AppConfig.UI.cardShadowOffsetY)
                            }
                        }
                    }
                    .padding(.horizontal)

                    // MARK: - Recent Activity
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Recent Dispatch Activity")
                            .font(AppConfig.Fonts.headline)
                            .foregroundColor(AppConfig.Colors.textPrimary)
                            .padding(.horizontal)

                        VStack(spacing: 12) {
                            ForEach(viewModel.recentActivities) { activity in
                                HStack(alignment: .center, spacing: 16) {
                                    if let urlStr = activity.photoUrl,
                                        let photoUrl = URL(string: urlStr)
                                    {
                                        AsyncImage(url: photoUrl) { phase in
                                            if let image = phase.image {
                                                image.resizable().scaledToFill()
                                            } else {
                                                Color.gray.opacity(0.3)
                                            }
                                        }
                                        .frame(width: 80, height: 80)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                    } else {
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(AppConfig.Colors.accent.opacity(0.1))
                                            .frame(width: 80, height: 80)
                                            .overlay(
                                                Image(
                                                    systemName: activity.severity?.lowercased()
                                                        == "critical"
                                                        ? "exclamationmark.triangle.fill"
                                                        : "pawprint.fill"
                                                )
                                                .foregroundColor(AppConfig.Colors.accent)
                                                .font(.title)
                                            )
                                    }

                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(
                                            activity.title
                                                ?? "Severity: \(activity.severity?.capitalized ?? "Moderate")"
                                        )
                                        .font(AppConfig.Fonts.headline)
                                        .foregroundColor(AppConfig.Colors.textPrimary)
                                        .lineLimit(1)

                                        HStack(alignment: .top, spacing: 4) {
                                            Text("Location:")
                                                .font(AppConfig.Fonts.bodyBold)
                                                .foregroundColor(AppConfig.Colors.textPrimary)
                                            Text(activity.locationName ?? "Unknown Location")
                                                .font(AppConfig.Fonts.body)
                                                .foregroundColor(AppConfig.Colors.textSecondary)
                                                .lineLimit(2)
                                        }

                                        HStack(spacing: 4) {
                                            Text("Date:")
                                                .font(AppConfig.Fonts.bodyBold)
                                                .foregroundColor(AppConfig.Colors.textPrimary)
                                            Text(
                                                RescuerProfileViewModel.formatSupabaseDate(
                                                    activity.createdAt)
                                            )
                                            .font(AppConfig.Fonts.body)
                                            .foregroundColor(AppConfig.Colors.textSecondary)
                                        }

                                        HStack(spacing: 4) {
                                            Text("Status:")
                                                .font(AppConfig.Fonts.bodyBold)
                                                .foregroundColor(AppConfig.Colors.textPrimary)
                                            Text(activity.status?.capitalized ?? "Reported")
                                                .font(AppConfig.Fonts.body)
                                                .foregroundColor(AppConfig.Colors.textSecondary)
                                        }
                                    }

                                    Spacer()
                                }
                                .padding(AppConfig.UI.padding)
                                .background(AppConfig.Colors.card)
                                .cornerRadius(AppConfig.UI.cornerRadius)
                                .shadow(
                                    color: Color.black.opacity(0.05),
                                    radius: AppConfig.UI.cardShadowRadius, x: 0,
                                    y: AppConfig.UI.cardShadowOffsetY
                                )
                                .padding(.horizontal)
                            }
                        }
                    }

                    Spacer(minLength: 32)

                    // MARK: - Sign Out Button
                    Button(action: {
                        Task {
                            await viewModel.signOut()
                        }
                    }) {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Sign Out")
                        }
                        .font(AppConfig.Fonts.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(AppConfig.Colors.alert)
                        .cornerRadius(AppConfig.UI.buttonCornerRadius)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 32)
                }
            }
            .background(AppConfig.Colors.background)
            .navigationTitle("My Profile")
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
