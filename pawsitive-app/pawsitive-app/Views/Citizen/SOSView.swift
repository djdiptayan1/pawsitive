//
//  SOSView.swift
//  pawsitive-app
//
//  Created by Diptayan Jash on 09/03/26.
//
import SwiftUI

struct SOSView: View {
    @EnvironmentObject var session: SessionViewModel
    @StateObject private var cameraVM = CameraViewModel()
    @StateObject private var locationMgr = LocationManager()
    @StateObject private var sosVM = SOSViewModel()
    @State private var showProfile = false

    var body: some View {
        ZStack {
            AppConfig.Colors.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Improved Header
                HeaderView(onProfileTap: {
                    showProfile = true
                })
                .padding(.horizontal, AppConfig.UI.screenPadding)
                .padding(.top, 10)
                .padding(.bottom, 16)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Camera and SOS Section
                        ZStack(alignment: .bottom) {
                            CameraSectionView(cameraVM: cameraVM)
                                .padding(.horizontal, AppConfig.UI.screenPadding)

                            SOSButtonView(action: submitSOS, isLoading: sosVM.isSubmitting)
                                .offset(y: 78)
                        }
                        .padding(.top, 10)
                        .padding(.bottom, 85)

                        if let error = sosVM.submissionError {
                            HStack {
                                Image(systemName: "exclamationmark.circle.fill")
                                Text(error)
                            }
                            .font(AppConfig.Fonts.small)
                            .foregroundColor(AppConfig.Colors.alert)
                            .padding(.horizontal, AppConfig.UI.screenPadding)
                            .padding(.bottom, 12)
                        }

                        // Improved Title Input
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Describe the situation")
                                .font(AppConfig.Fonts.headline)
                                .foregroundColor(AppConfig.Colors.textPrimary)
                            
                            HStack {
                                Image(systemName: "pencil.line")
                                    .foregroundColor(AppConfig.Colors.textSecondary)
                                TextField("E.g., Stray dog hit by car...", text: $sosVM.incidentTitle)
                                    .font(AppConfig.Fonts.body)
                            }
                            .padding(16)
                            .background(AppConfig.Colors.card)
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(AppConfig.Colors.stroke.opacity(0.08), lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(0.02), radius: 5, x: 0, y: 2)
                        }
                        .padding(.horizontal, AppConfig.UI.screenPadding)

                        // Urgency Selection
                        UrgencySectionView(selectedSeverity: $sosVM.selectedSeverity)
                            .padding(.horizontal, AppConfig.UI.screenPadding)
                            .padding(.top, 24)
                            .padding(.bottom, 40)
                    }
                }
            }
        }
        .sheet(isPresented: $showProfile) {
            // Need the wrapper or straight view if EnvironmentObject is managed
            CitizenProfileView(sessionVM: session)
                .environmentObject(session)
        }
        .alert("Help is on the way! 🚑", isPresented: $sosVM.showSuccessAlert) {
            Button("Got it", role: .cancel) { }
        } message: {
            Text("Your report has been broadcasted to nearby rescuers. Please stay nearby if safe to do so.")
        }
        .onAppear {
            cameraVM.checkPermission()
            locationMgr.requestPermission()
            locationMgr.startUpdating()
        }
        .onDisappear {
            cameraVM.stopSession()
            locationMgr.stopUpdating()
        }
    }

    private func submitSOS() {
        Task {
            if let image = await cameraVM.capturePhoto() {
                await sosVM.submitIncident(photo: image, location: locationMgr.location)
            } else {
                sosVM.submissionError = "Could not capture image. Make sure camera is available."
            }
        }
    }
}

// MARK: - SOS Subviews

struct HeaderView: View {
    var onProfileTap: () -> Void

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("Pawsitive")
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .foregroundColor(AppConfig.Colors.textPrimary)

                    Image(systemName: "pawprint.fill")
                        .foregroundColor(AppConfig.Colors.accent)
                        .font(.title2)
                }
                
                Text("Ready to save a life today?")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(AppConfig.Colors.textSecondary)
            }

            Spacer()
            
            Button(action: onProfileTap) {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 44, height: 44)
                    .foregroundColor(AppConfig.Colors.accent.opacity(0.8))
                    .background(Circle().fill(AppConfig.Colors.card))
                    .overlay(Circle().stroke(AppConfig.Colors.stroke.opacity(0.1), lineWidth: 1))
                    .shadow(color: Color.black.opacity(0.05), radius: 4, y: 2)
            }
        }
    }
}

struct CameraSectionView: View {
    @ObservedObject var cameraVM: CameraViewModel

    var body: some View {
        ZStack(alignment: .topLeading) {
            Group {
                if cameraVM.isCameraAvailable {
                    CameraPreviewView(session: cameraVM.session)
                } else {
                    Color.gray.opacity(0.15)
                        .overlay(
                            VStack(spacing: 12) {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(AppConfig.Colors.textSecondary.opacity(0.5))
                                Text(cameraVM.permissionGranted ? "Starting camera..." : "Camera access needed")
                                    .font(AppConfig.Fonts.small)
                                    .foregroundColor(AppConfig.Colors.textSecondary)
                            }
                        )
                }
            }
            .frame(height: 320)
            .mask {
                ZStack {
                    RoundedRectangle(cornerRadius: AppConfig.UI.cornerRadius)
                        .fill(Color.black)

                    Circle()
                        .frame(width: 170, height: 170)
                        .offset(y: 160)
                        .blendMode(.destinationOut)
                }
                .compositingGroup()
            }
            .overlay(
                RoundedRectangle(cornerRadius: AppConfig.UI.cornerRadius)
                    .stroke(Color.white.opacity(0.8), lineWidth: 4)
                    .mask {
                        ZStack {
                            RoundedRectangle(cornerRadius: AppConfig.UI.cornerRadius)
                                .fill(Color.black)
                            Circle()
                                .frame(width: 170, height: 170)
                                .offset(y: 160)
                                .blendMode(.destinationOut)
                        }
                        .compositingGroup()
                    }
            )
            .shadow(color: Color.black.opacity(0.08), radius: 10, y: 5)
        }
    }
}

struct SOSButtonView: View {
    var action: () -> Void
    var isLoading: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(AppConfig.Colors.background)
                .frame(width: 156, height: 156)

            Button(action: action) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [AppConfig.Colors.accent, Color(hex: "#F99B20")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 140, height: 140)
                        .shadow(color: AppConfig.Colors.accent.opacity(0.4), radius: 12, x: 0, y: 8)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.6), lineWidth: 2)
                                .padding(2)
                        )
                        .overlay(
                            Ellipse()
                                .fill(Color.white.opacity(0.25))
                                .frame(width: 80, height: 30)
                                .offset(y: -40)
                        )

                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                    } else {
                        Text("S.O.S.")
                            .font(.system(size: 34, weight: .black, design: .rounded))
                            .foregroundColor(AppConfig.Colors.textPrimary)
                    }
                }
            }
            .disabled(isLoading)
        }
    }
}

struct UrgencySectionView: View {
    @Binding var selectedSeverity: UrgencySeverity?

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Select Urgency Type")
                    .font(AppConfig.Fonts.headline)
                    .foregroundColor(AppConfig.Colors.textPrimary)
                Spacer()
            }

            HStack(spacing: 12) {
                UrgencyCard(
                    title: "Bleeding",
                    severity: .severe,
                    icon: "drop.fill",
                    isSelected: selectedSeverity == .severe) {
                        selectedSeverity = .severe
                    }
                UrgencyCard(
                    title: "Injury",
                    severity: .moderate,
                    icon: "bandage.fill",
                    isSelected: selectedSeverity == .moderate) {
                        selectedSeverity = .moderate
                    }
                UrgencyCard(
                    title: "Sick/Stranded",
                    severity: .minor,
                    icon: "thermometer.medium",
                    isSelected: selectedSeverity == .minor) {
                        selectedSeverity = .minor
                    }
            }
        }
    }
}

struct UrgencyCard: View {
    let title: String
    let severity: UrgencySeverity
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.white.opacity(0.2) : severity.color.opacity(0.1))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(isSelected ? .white : severity.color)
                }

                Text(title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(isSelected ? .white : AppConfig.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .padding(.horizontal, 4)
            .background(isSelected ? severity.color : AppConfig.Colors.card)
            .cornerRadius(20)
            .shadow(color: isSelected ? severity.color.opacity(0.3) : Color.black.opacity(0.03), radius: 8, y: 4)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? severity.color : AppConfig.Colors.stroke.opacity(0.08), lineWidth: isSelected ? 2 : 1)
            )
        }
    }
}

#Preview {
    // Workaround for #Preview macros using multi-statement
    VStack {
        let mockSession = SessionViewModel()
        let _ = mockSession.isLoggedIn = true
        let _ = mockSession.role = .citizen

        SOSView()
            .environmentObject(mockSession)
    }
}
