//
//  SplashScreenView.swift
//  pawsitive-app
//
//  Created by Diptayan Jash on 09/03/26.
//

import DotLottie
import SwiftUI

struct SplashScreenView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            // Brand Background
            AppConfig.Colors.background
                .ignoresSafeArea()

            VStack {
                // Lottie Animation
                DotLottieAnimation(
                    fileName: "AnimalPaws",
                    config: AnimationConfig(
                        autoplay: true,
                        loop: true,
                        speed: 1.0
                    )
                )
                .view()
                .frame(width: 300, height: 300)

                // Optional App Tagline or Loading Indicator
                Text("Pawsitive")
                    .font(AppConfig.Fonts.titleLarge)
                    .foregroundColor(AppConfig.Colors.textPrimary)
                    .padding(.top, 20)

//                ProgressView()
//                    .progressViewStyle(CircularProgressViewStyle())
//                    .padding(.top, 10)
//                    .tint(AppConfig.Colors.accent)
            }
        }
    }
}

#Preview {
    SplashScreenView()
}
