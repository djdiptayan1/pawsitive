//
//  CreditHistoryView.swift
//  pawsitive-app
//
//  Created by Diptayan Jash on 10/03/26.
//

import DotLottie
import SwiftUI

struct CreditHistoryView: View {
    @StateObject private var viewModel = CreditHistoryViewModel()

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

                    Text("Loading earnings...")
                        .font(AppConfig.Fonts.body)
                        .foregroundColor(AppConfig.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = viewModel.errorMessage {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(AppConfig.Colors.warning)
                    Text(error)
                        .font(AppConfig.Fonts.body)
                        .foregroundColor(AppConfig.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    Button("Try Again") { viewModel.loadHistory() }
                        .font(AppConfig.Fonts.bodyBold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(AppConfig.Colors.accent)
                        .clipShape(Capsule())
                }
                .padding(.top, 80)
            } else if viewModel.entries.isEmpty {
                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .fill(AppConfig.Colors.accent.opacity(0.1))
                            .frame(width: 100, height: 100)
                        Image(systemName: "star.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(AppConfig.Colors.accent)
                    }
                    .padding(.top, 60)

                    Text("No Earnings Yet")
                        .font(AppConfig.Fonts.titleMedium)
                        .foregroundColor(AppConfig.Colors.textPrimary)

                    Text("Complete rescues to earn Pawsitive Credits. Your earning history will appear here.")
                        .font(AppConfig.Fonts.body)
                        .foregroundColor(AppConfig.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.entries) { entry in
                            earningCard(entry)
                        }
                    }
                    .padding(.horizontal, AppConfig.UI.screenPadding)
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }
            }
        }
        .background(AppConfig.Colors.background.ignoresSafeArea())
        .navigationTitle("Earnings")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func earningCard(_ entry: CreditEntry) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(AppConfig.Colors.accent.opacity(0.12))
                    .frame(width: 48, height: 48)
                Image(systemName: viewModel.reasonIcon(entry.reason))
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(AppConfig.Colors.accent)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.reasonLabel(entry.reason))
                    .font(AppConfig.Fonts.bodyBold)
                    .foregroundColor(AppConfig.Colors.textPrimary)
                    .lineLimit(1)

                Text(DateUtils.formatSupabaseDate(entry.createdAt))
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundColor(AppConfig.Colors.textSecondary)
            }

            Spacer()

            Text("+\(entry.creditsEarned)")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(AppConfig.Colors.accent)
        }
        .padding(14)
        .background(AppConfig.Colors.card)
        .cornerRadius(AppConfig.UI.cornerRadius)
        .shadow(
            color: .black.opacity(0.04), radius: AppConfig.UI.cardShadowRadius, x: 0,
            y: AppConfig.UI.cardShadowOffsetY)
    }
}
