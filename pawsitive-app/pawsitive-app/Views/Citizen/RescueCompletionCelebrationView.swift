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

    var body: some View {
        ZStack {
            AppConfig.Colors.card.ignoresSafeArea()

            DotLottieAnimation(
                fileName: "Confetti",
                config: AnimationConfig(autoplay: true, loop: true, speed: 1.0)
            )
            .view()
            .ignoresSafeArea()
            .opacity(0.7)

            VStack(spacing: 24) {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(AppConfig.Colors.textSecondary.opacity(0.6))
                    }
                }
                .padding(.horizontal, AppConfig.UI.screenPadding)
                .padding(.top, AppConfig.UI.padding)

                Spacer()

                VStack(spacing: 8) {
                    Text("They are Safe")
                        .font(AppConfig.Fonts.titleLarge)
                        .foregroundColor(AppConfig.Colors.textPrimary)
                        .multilineTextAlignment(.center)

                    Text("Your report made a real difference. The rescuer sent this photo.")
                        .font(AppConfig.Fonts.body)
                        .foregroundColor(AppConfig.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }

                AsyncImage(url: URL(string: rescuePhotoUrl)) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 260)
                            .clipShape(RoundedRectangle(cornerRadius: AppConfig.UI.cornerRadius))
                            .overlay(
                                RoundedRectangle(cornerRadius: AppConfig.UI.cornerRadius)
                                    .stroke(AppConfig.Colors.success, lineWidth: 3)
                            )
                            .shadow(
                                color: AppConfig.Colors.success.opacity(0.3),
                                radius: 12,
                                x: 0,
                                y: 6
                            )
                    } else if phase.error != nil {
                        ZStack {
                            RoundedRectangle(cornerRadius: AppConfig.UI.cornerRadius)
                                .fill(AppConfig.Colors.success.opacity(0.1))
                                .frame(height: 200)
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 60))
                                .foregroundColor(AppConfig.Colors.success)
                        }
                    } else {
                        ZStack {
                            RoundedRectangle(cornerRadius: AppConfig.UI.cornerRadius)
                                .fill(AppConfig.Colors.card)
                                .frame(height: 200)
                            ProgressView()
                                .tint(AppConfig.Colors.accent)
                        }
                    }
                }
                .padding(.horizontal, AppConfig.UI.screenPadding)

                Text(dropOffLabel)
                    .font(AppConfig.Fonts.bodyBold)
                    .foregroundColor(AppConfig.Colors.success)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(AppConfig.Colors.success.opacity(0.12))
                    .clipShape(Capsule())

                Spacer()

                Button {
                    HapticManager.shared.trigger(.success)
                    dismiss()
                } label: {
                    Text("Thank You for Caring")
                        .font(AppConfig.Fonts.bodyBold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(AppConfig.Colors.success)
                        .cornerRadius(AppConfig.UI.buttonCornerRadius)
                        .shadow(
                            color: AppConfig.Colors.success.opacity(0.35),
                            radius: 8,
                            x: 0,
                            y: 4
                        )
                }
                .padding(.horizontal, AppConfig.UI.screenPadding)
                .padding(.bottom, 36)
            }
        }
    }
}
