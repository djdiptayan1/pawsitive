//
//  SuccessPopupView.swift
//  pawsitive-app
//
//  Created by Diptayan Jash on 10/03/26.
//

import DotLottie
import SwiftUI

struct SuccessPopupView: View {
    @Environment(\.dismiss) private var dismiss

    // Configurable properties
    var title: String = "Pawsitive Rescue"
    var heroText: String = "Thank You, Hero!"
    var message: String =
        "Your rescue mission was successful!\nBuddy is safe and sound. Thanks for\nmaking a difference."
    var animationName: String = "thankYou"
    var showButtons: Bool = false

    // Callbacks for your buttons (now optional)
    var onBackToMap: (() -> Void)? = nil
    var onShareStory: (() -> Void)? = nil

    var body: some View {
        ZStack {
            AppConfig.Colors.card
                .ignoresSafeArea()

            DotLottieAnimation(
                fileName: "Confetti",
                config: AnimationConfig(
                    autoplay: true,
                    loop: true,
                    speed: 1.0
                )
            )
            .view()
            .ignoresSafeArea()
            .opacity(0.8)

            VStack(spacing: 0) {
                HStack {
                    Spacer()

                    Text(title)
                        .font(AppConfig.Fonts.headline)
                        .foregroundColor(AppConfig.Colors.textPrimary)
                        .padding(.leading, AppConfig.UI.padding * 2)

                    Spacer()

                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(AppConfig.Colors.textSecondary)
                    }
                }
                .padding(.horizontal, AppConfig.UI.screenPadding)
                .padding(.top, AppConfig.UI.padding)

                Spacer()

                DotLottieAnimation(
                    fileName: animationName,
                    config: AnimationConfig(
                        autoplay: true,
                        loop: true,
                        speed: 1.0
                    )
                )
                .view()
                .frame(height: 320)
                .padding(.bottom, 16)

                VStack(spacing: AppConfig.UI.padding) {
                    Text(heroText)
                        .font(AppConfig.Fonts.titleLarge)
                        .foregroundColor(AppConfig.Colors.textPrimary)
                        .multilineTextAlignment(.center)

                    Text(message)
                        .font(AppConfig.Fonts.body)
                        .foregroundColor(AppConfig.Colors.textPrimary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, AppConfig.UI.padding * 2)
                }

                Spacer()

                if showButtons {
                    HStack(spacing: AppConfig.UI.padding) {
                        Button(action: {
                            dismiss()
                            onBackToMap?()
                        }) {
                            Text("Back to Map")
                                .font(AppConfig.Fonts.bodyBold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, AppConfig.UI.padding + 2)
                                .background(AppConfig.Colors.accent)  // Sun Orange
                                .cornerRadius(AppConfig.UI.buttonCornerRadius)
                                .shadow(
                                    color: AppConfig.Colors.accent.opacity(0.3),
                                    radius: AppConfig.UI.cardShadowRadius,
                                    y: AppConfig.UI.cardShadowOffsetY)
                        }

                        Button(action: {
                            onShareStory?()
                        }) {
                            Text("Share Story")
                                .font(AppConfig.Fonts.bodyBold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, AppConfig.UI.padding + 2)
                                .background(AppConfig.Colors.success)  // Mint Green
                                .cornerRadius(AppConfig.UI.buttonCornerRadius)
                                .shadow(
                                    color: AppConfig.Colors.success.opacity(0.3),
                                    radius: AppConfig.UI.cardShadowRadius,
                                    y: AppConfig.UI.cardShadowOffsetY)
                        }
                    }
                    .padding(.horizontal, AppConfig.UI.screenPadding)
                    .padding(.bottom, AppConfig.UI.padding * 2.5)
                } else {
                    Spacer()
                        .frame(height: 60)
                }
            }
        }
    }
}

#Preview {
    SuccessPopupView(
        onBackToMap: { print("Routing to Map...") },
        onShareStory: { print("Opening Share Sheet...") }
    )
}
