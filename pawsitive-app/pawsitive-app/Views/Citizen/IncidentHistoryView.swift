import DotLottie
import SwiftUI

struct IncidentHistoryView: View {
    let type: String
    @StateObject private var viewModel: IncidentHistoryViewModel

    init(type: String) {
        self.type = type
        _viewModel = StateObject(wrappedValue: IncidentHistoryViewModel(type: type))
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                VStack(spacing: 16) {
                    DotLottieAnimation(
                        fileName: "loading",
                        config: AnimationConfig(autoplay: true, loop: true)
                    )
                    .view()
                    .frame(width: 120, height: 120)

                    Text("Loading records...")
                        .font(AppConfig.Fonts.body)
                        .foregroundColor(AppConfig.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    if let error = viewModel.errorMessage {
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 40))
                                .foregroundColor(AppConfig.Colors.warning)
                            Text(error)
                                .font(AppConfig.Fonts.body)
                                .foregroundColor(AppConfig.Colors.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                            Button("Try Again") { viewModel.loadIncidents() }
                                .font(AppConfig.Fonts.bodyBold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(AppConfig.Colors.accent)
                                .clipShape(Capsule())
                        }
                        .padding(.top, 80)
                    } else if viewModel.incidents.isEmpty {
                        VStack(spacing: 20) {
                            ZStack {
                                Circle()
                                    .fill(AppConfig.Colors.accent.opacity(0.1))
                                    .frame(width: 100, height: 100)
                                Image(
                                    systemName: type == "Reports"
                                        ? "doc.text.magnifyingglass" : "pawprint.fill"
                                )
                                .font(.system(size: 40))
                                .foregroundColor(AppConfig.Colors.accent)
                            }
                            .padding(.top, 60)

                            Text(viewModel.emptyStateTitle)
                                .font(AppConfig.Fonts.titleMedium)
                                .foregroundColor(AppConfig.Colors.textPrimary)

                            Text(viewModel.emptyStateMessage)
                                .font(AppConfig.Fonts.body)
                                .foregroundColor(AppConfig.Colors.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                    } else {
                        LazyVStack(spacing: 16) {
                            ForEach(viewModel.incidents) { incident in
                                historyCard(incident)
                            }
                        }
                        .padding(.horizontal, AppConfig.UI.screenPadding)
                        .padding(.top, 20)
                        .padding(.bottom, 40)
                    }
                }
            }
        }
        .background(AppConfig.Colors.background.ignoresSafeArea())
        .navigationTitle(viewModel.navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func historyCard(_ incident: RecentActivityModel) -> some View {
        HStack(alignment: .center, spacing: 16) {
            // Photo thumbnail
            ZStack {
                if let urlStr = incident.photoUrl, let url = URL(string: urlStr) {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFill()
                        } else {
                            Color.gray.opacity(0.15)
                        }
                    }
                } else {
                    AppConfig.Colors.accent.opacity(0.1)
                        .overlay(
                            Image(systemName: "pawprint.fill")
                                .foregroundColor(AppConfig.Colors.accent)
                                .font(.title2)
                        )
                }
            }
            .frame(width: 90, height: 90)
            .clipShape(RoundedRectangle(cornerRadius: 16))

            VStack(alignment: .leading, spacing: 8) {
                // Status + Severity badges
                HStack(spacing: 6) {
                    Text(incident.status?.uppercased() ?? "UNKNOWN")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(viewModel.statusColor(incident.status))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(viewModel.statusColor(incident.status).opacity(0.15))
                        .clipShape(Capsule())

                    if let severity = incident.severity {
                        Text(severity.uppercased())
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(viewModel.severityColor(severity))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(viewModel.severityColor(severity).opacity(0.15))
                            .clipShape(Capsule())
                    }
                }

                Text(incident.title ?? "Animal Rescue Request")
                    .font(AppConfig.Fonts.bodyBold)
                    .foregroundColor(AppConfig.Colors.textPrimary)
                    .lineLimit(1)

                VStack(alignment: .leading, spacing: 4) {
                    if let location = incident.locationName, !location.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "mappin.and.ellipse")
                                .font(.system(size: 12))
                                .foregroundColor(AppConfig.Colors.textSecondary)
                                .frame(width: 14)
                            Text(location)
                                .font(.system(size: 13, weight: .regular, design: .rounded))
                                .foregroundColor(AppConfig.Colors.textSecondary)
                                .lineLimit(1)
                        }
                    }

                    HStack(spacing: 6) {
                        Image(systemName: "clock")
                            .font(.system(size: 12))
                            .foregroundColor(AppConfig.Colors.textSecondary)
                            .frame(width: 14)
                        Text(DateUtils.formatSupabaseDate(incident.createdAt))
                            .font(.system(size: 13, weight: .regular, design: .rounded))
                            .foregroundColor(AppConfig.Colors.textSecondary)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(AppConfig.Colors.card)
        .cornerRadius(AppConfig.UI.cornerRadius)
        .shadow(
            color: .black.opacity(0.04), radius: AppConfig.UI.cardShadowRadius, x: 0,
            y: AppConfig.UI.cardShadowOffsetY)
    }
}
