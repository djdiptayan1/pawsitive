//
//  RescueReplayView.swift
//  pawsitive-app
//
//  Created by Diptayan Jash on 10/03/26.
//

import DotLottie
import MapKit
import SwiftUI

struct RescueReplayView: View {
    let incidentId: String
    @StateObject private var vm = RescueReplayViewModel()

    var body: some View {
        ZStack {
            if vm.isLoading {
                VStack(spacing: 16) {
                    DotLottieAnimation(
                        fileName: "loading",
                        config: AnimationConfig(autoplay: true, loop: true)
                    )
                    .view()
                    .frame(width: 120, height: 120)

                    Text("Loading rescue story...")
                        .font(AppConfig.Fonts.body)
                        .foregroundColor(AppConfig.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppConfig.Colors.background.ignoresSafeArea())
            } else if let error = vm.errorMessage {
                VStack(spacing: 16) {
                    Image(systemName: "map.fill")
                        .font(.system(size: 48))
                        .foregroundColor(AppConfig.Colors.textSecondary)

                    Text(error)
                        .font(AppConfig.Fonts.body)
                        .foregroundColor(AppConfig.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppConfig.Colors.background.ignoresSafeArea())
            } else {
                Map(position: $vm.cameraPosition) {
                    // Draw the full route as a polyline
                    if vm.routeCoordinates.count > 1 {
                        MapPolyline(coordinates: vm.routeCoordinates)
                            .stroke(AppConfig.Colors.accent, lineWidth: 4)
                    }

                    // Animated rescuer dot at current replay position
                    if let current = vm.currentReplayPosition {
                        Annotation("Rescuer", coordinate: current) {
                            ReplayRescuerPinView()
                        }
                    }

                    // Incident pin (last known location)
                    if let incident = vm.incidentCoordinate {
                        Annotation("Animal", coordinate: incident) {
                            ReplayIncidentPinView()
                        }
                    }
                }
                .mapStyle(.standard(pointsOfInterest: .excludingAll))
                .overlay(alignment: .bottom) {
                    playbackControls
                }
            }
        }
        .onAppear { vm.loadReplay(incidentId: incidentId) }
        .navigationTitle("Rescue Story")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Playback Controls

    @ViewBuilder
    private var playbackControls: some View {
        VStack(spacing: 12) {
            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.3))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(AppConfig.Colors.accent)
                        .frame(
                            width: geo.size.width * vm.replayProgress,
                            height: 6)
                }
            }
            .frame(height: 6)

            HStack {
                Button(action: { vm.togglePlayback() }) {
                    HStack(spacing: 6) {
                        Image(
                            systemName: vm.isPlaying
                                ? "pause.fill" : "play.fill"
                        )
                        .font(.system(size: 16, weight: .bold))
                        Text(vm.isPlaying ? "Pause" : "Play")
                            .font(AppConfig.Fonts.bodyBold)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(AppConfig.Colors.accent)
                    .clipShape(Capsule())
                }

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 14))
                    Text(vm.elapsedTimeFormatted)
                        .font(AppConfig.Fonts.bodyBold)
                }
                .foregroundColor(AppConfig.Colors.textPrimary)
            }
        }
        .padding(AppConfig.UI.padding)
        .background(.ultraThinMaterial)
        .cornerRadius(AppConfig.UI.cornerRadius)
        .padding(.horizontal, AppConfig.UI.screenPadding)
        .padding(.bottom, 12)
    }
}

// MARK: - Annotation Views

private struct ReplayRescuerPinView: View {
    @State private var pulse = false

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.green.opacity(0.2))
                .frame(width: 36, height: 36)
                .scaleEffect(pulse ? 1.4 : 1.0)
                .opacity(pulse ? 0.0 : 0.6)
                .animation(
                    .easeInOut(duration: 1.2).repeatForever(autoreverses: false),
                    value: pulse)

            Circle()
                .fill(Color.green)
                .frame(width: 20, height: 20)

            Image(systemName: "cross.fill")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white)
        }
        .onAppear { pulse = true }
    }
}

private struct ReplayIncidentPinView: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(AppConfig.Colors.alert.opacity(0.2))
                .frame(width: 44, height: 44)

            Circle()
                .fill(AppConfig.Colors.alert)
                .frame(width: 28, height: 28)

            Image(systemName: "pawprint.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
        }
    }
}
