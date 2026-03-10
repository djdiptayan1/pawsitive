//
//  RescueCompletionCelebrationView.swift
//  pawsitive-app
//

import DotLottie
import SwiftUI

struct RescueCompletionCelebrationView: View {
    @Environment(\.dismiss) private var dismiss

    let rescuePhotoUrl: String
    let dropOffType: String

    private var dropOffLabel: String {
        switch dropOffType {
        case "vet_hospital":
            return "Taken to Vet Hospital"
        case "ngo_shelter":
            return "Safe at NGO Shelter"
        case "treated_on_scene":
            return "Treated on Scene"
        default:
            return "Rescue Completed"
        }
    }

    private var completionMessage: String {
        "Thanks to your report, this rescue reached a safe outcome."
    }

    var body: some View {
        ZStack {
            AppConfig.Colors.card
                .ignoresSafeArea()

            DotLottieAnimation(
                fileName: "Confetti",
                config: AnimationConfig(
                    autoplay: true,
                    loop: true,
                    speed: 2.0
                )
            )
            .view()
            .ignoresSafeArea()
            .opacity(0.8)

            VStack(spacing: 0) {
                HStack {
                    Spacer()

                    Text("Pawsitive Rescue")
                        .font(AppConfig.Fonts.headline)
                        .foregroundColor(AppConfig.Colors.textPrimary)
                        .padding(.leading, AppConfig.UI.padding * 2)

                    Spacer()

                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(AppConfig.Colors.textSecondary)
                    }
                }
                .padding(.horizontal, AppConfig.UI.screenPadding)
                .padding(.top, AppConfig.UI.padding)

                Spacer()

                DotLottieAnimation(
                    fileName: "completion",
                    config: AnimationConfig(
                        autoplay: true,
                        loop: true,
                        speed: 1.0
                    )
                )
                .view()
                .frame(height: 240)
                .padding(.bottom, 8)

                VStack(spacing: AppConfig.UI.padding) {
                    Text("Rescue Completed")
                        .font(AppConfig.Fonts.titleLarge)
                        .foregroundColor(AppConfig.Colors.textPrimary)
                        .multilineTextAlignment(.center)

                    Text(completionMessage)
                        .font(AppConfig.Fonts.body)
                        .foregroundColor(AppConfig.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .padding(.horizontal, AppConfig.UI.padding * 2)
                }

                VStack(spacing: 14) {
                    AsyncImage(url: URL(string: rescuePhotoUrl)) { phase in
                        if let image = phase.image {
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 280, height: 200)
                                .clipShape(RoundedRectangle(cornerRadius: AppConfig.UI.cornerRadius))
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppConfig.UI.cornerRadius)
                                        .stroke(AppConfig.Colors.success, lineWidth: 2)
                                )
                                .shadow(
                                    color: AppConfig.Colors.success.opacity(0.25),
                                    radius: 10,
                                    x: 0,
                                    y: 5
                                )
                        } else if phase.error != nil {
                            ZStack {
                                RoundedRectangle(cornerRadius: AppConfig.UI.cornerRadius)
                                    .fill(AppConfig.Colors.success.opacity(0.1))
                                    .frame(width: 280, height: 200)
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 58))
                                    .foregroundColor(AppConfig.Colors.success)
                            }
                        } else {
                            ZStack {
                                RoundedRectangle(cornerRadius: AppConfig.UI.cornerRadius)
                                    .fill(AppConfig.Colors.card)
                                    .frame(width: 280, height: 200)
                                ProgressView()
                                    .tint(AppConfig.Colors.accent)
                            }
                        }
                    }

                    Text(dropOffLabel)
                        .font(AppConfig.Fonts.bodyBold)
                        .foregroundColor(AppConfig.Colors.success)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                        .background(AppConfig.Colors.success.opacity(0.12))
                        .clipShape(Capsule())
                }
                .padding(.horizontal, AppConfig.UI.screenPadding)

                Spacer()

                Button {
                    HapticManager.shared.trigger(.success)
                    dismiss()
                } label: {
                    Text("Continue to Home")
                        .font(AppConfig.Fonts.bodyBold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppConfig.UI.padding + 2)
                        .background(AppConfig.Colors.success)
                        .cornerRadius(AppConfig.UI.buttonCornerRadius)
                        .shadow(
                            color: AppConfig.Colors.success.opacity(0.35),
                            radius: AppConfig.UI.cardShadowRadius,
                            x: 0,
                            y: AppConfig.UI.cardShadowOffsetY
                        )
                }
                .padding(.horizontal, AppConfig.UI.screenPadding)
                .padding(.bottom, AppConfig.UI.padding * 2.5)
            }
        }
    }
}

#Preview{
    RescueCompletionCelebrationView(
        rescuePhotoUrl: "https://i.sstatic.net/Bii85.png",
        dropOffType: "vet_hospital"
    )
}
