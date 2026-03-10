//
//  ActiveRescueView.swift
//  pawsitive-app
//
//  Created by Diptayan Jash on 09/03/26.
//

import Combine
import MapKit
import SwiftUI

// MARK: - View
struct ActiveRescueView: View {
    @StateObject private var viewModel = ActiveRescueViewModel()
    @State private var showDetailSheet: Bool = false
    @State private var selectedVetPlace: ActiveRescueViewModel.NearbyVetPOI?
    @State private var showVetOptions = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppConfig.Colors.background.ignoresSafeArea()

                if viewModel.isLoading && viewModel.activeRescue == nil {
                    loadingView
                } else if let rescue = viewModel.activeRescue {
                    activeRescueLayout(rescue)
                } else {
                    noActiveRescueView
                }
            }
            .navigationTitle("Active Rescue")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear { viewModel.startPolling() }
        .onDisappear { viewModel.stopPolling() }
        .fullScreenCover(isPresented: $viewModel.showCompleteAlert) {
            SuccessPopupView(
                title: "Rescue Complete!",
                heroText: "Mission Accomplished! 🐾",
                message:
                    "Great work! The animal has been marked as rescued. Thank you for being a hero.",
                animationName: "thankYou",
                showButtons: true,
                onBackToMap: {
                    // Optional: reset VM or navigate
                },
                onShareStory: {
                    // Logic to share the story
                }
            )
        }
    }

    // MARK: - Main Layout
    private func activeRescueLayout(_ rescue: ActiveRescueViewModel.ActiveRescueData) -> some View {
        ZStack {
            // Full-screen Map behind everything
            Map {
                Annotation(rescue.title, coordinate: rescue.coordinate, anchor: .bottom) {
                    IncidentAnnotationView(severity: rescue.severity)
                }
                UserAnnotation()

                ForEach(viewModel.nearbyVetPlaces) { place in
                    Annotation(place.name, coordinate: place.coordinate, anchor: .center) {
                        Image(systemName: "cross.vial.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.mint)
                            .clipShape(Circle())
                            .shadow(color: Color.mint.opacity(0.4), radius: 4, y: 2)
                            .onTapGesture {
                                selectedVetPlace = place
                                showVetOptions = true
                            }
                    }
                }

                if let route = viewModel.route {
                    MapPolyline(route.polyline)
                        .stroke(
                            AppConfig.Colors.accent,
                            style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round)
                        )
                }
            }
            .mapStyle(.standard(pointsOfInterest: .excludingAll))
            .mapControls {
                MapUserLocationButton()
                MapCompass()
            }

            // Bottom status card overlay
            VStack {
                Spacer()
                rescueStatusCard(rescue)
            }
        }
        .sheet(isPresented: $showDetailSheet) {
            detailSheet(rescue)
        }
        .confirmationDialog(
            selectedVetPlace?.name ?? "Clinic",
            isPresented: $showVetOptions,
            titleVisibility: .visible
        ) {
            Button("Navigate in Maps") {
                guard let place = selectedVetPlace else { return }
                openMapsNavigation(to: place.coordinate, name: place.name)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(selectedVetPlace?.subtitle ?? "")
        }
    }

    // MARK: - Bottom Status Card
    private func rescueStatusCard(_ rescue: ActiveRescueViewModel.ActiveRescueData) -> some View {
        VStack(spacing: 0) {
            // Drag handle
            Capsule()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.top, 10)

            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    // Icon
                    ZStack {
                        Circle()
                            .fill(AppConfig.Colors.accent.opacity(0.2))
                            .frame(width: 50, height: 50)
                        Image(systemName: "cross.case.fill")
                            .font(.title2)
                            .foregroundColor(AppConfig.Colors.accent)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(rescue.title)
                            .font(AppConfig.Fonts.bodyBold)
                            .foregroundColor(AppConfig.Colors.textPrimary)
                            .lineLimit(1)

                        HStack(spacing: 8) {
                            Text(rescue.status.uppercased())
                                .rescueBadge(color: statusColor(rescue.status), isSolid: false)
                            Text(rescue.severity.uppercased())
                                .rescueBadge(color: severityColor(rescue.severity), isSolid: true)
                        }

                        if let route = viewModel.route {
                            let eta = Int(route.expectedTravelTime / 60)
                            let dist = String(format: "%.1f km", route.distance / 1000)
                            HStack(spacing: 8) {
                                Label("\(eta) min", systemImage: "clock")
                                Label(dist, systemImage: "location")
                            }
                            .font(AppConfig.Fonts.small)
                            .foregroundColor(AppConfig.Colors.textSecondary)
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(AppConfig.Colors.textSecondary)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    showDetailSheet = true
                }
            }
            .padding(.horizontal, AppConfig.UI.screenPadding)
            .padding(.vertical, 16)
        }
        .glassEffect(.regular, in: .rect(cornerRadius: AppConfig.UI.cornerRadius))
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    // MARK: - Detail Sheet
    private func detailSheet(_ rescue: ActiveRescueViewModel.ActiveRescueData) -> some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {

                    // Badges & Title Row
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Text(rescue.status.uppercased())
                                .rescueBadge(color: statusColor(rescue.status), isSolid: false)

                            Text(rescue.severity.uppercased())
                                .rescueBadge(color: severityColor(rescue.severity), isSolid: true)

                            Spacer()
                        }

                        Text(rescue.title)
                            .font(AppConfig.Fonts.titleMedium)
                            .foregroundColor(AppConfig.Colors.textPrimary)
                    }

                    // ETA & Photo Row
                    HStack(alignment: .center, spacing: 16) {
                        if let route = viewModel.route {
                            let eta = Int(route.expectedTravelTime / 60)
                            let dist = String(format: "%.1f km", route.distance / 1000)

                            VStack(alignment: .center, spacing: 4) {
                                Text("\(eta)")
                                    .font(.system(size: 32, weight: .black, design: .rounded))
                                    .foregroundColor(AppConfig.Colors.accent)
                                Text("MINUTES")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .foregroundColor(AppConfig.Colors.textSecondary)
                                Text(dist)
                                    .font(AppConfig.Fonts.small)
                                    .foregroundColor(AppConfig.Colors.textPrimary)
                            }
                            .frame(maxWidth: 100)
                            .padding(.vertical, 16)
                            .background(AppConfig.Colors.accent.opacity(0.1))
                            .cornerRadius(16)
                        }

                        if let photoUrlStr = rescue.photoUrl,
                            let photoUrl = URL(string: photoUrlStr)
                        {
                            AsyncImage(url: photoUrl) { phase in
                                if let image = phase.image {
                                    image.resizable().scaledToFill()
                                } else {
                                    Color.gray.opacity(0.15)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 100)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                    }

                    Divider().background(AppConfig.Colors.stroke.opacity(0.1))

                    // Location & Info
                    VStack(alignment: .leading, spacing: 16) {
                        if let location = rescue.locationName {
                            InfoRowView(
                                icon: "mappin.and.ellipse", label: "Destination",
                                value: location, iconColor: AppConfig.Colors.accent)
                        }

                        if let reporter = rescue.reporterName {
                            InfoRowView(
                                icon: "person.wave.2.fill", label: "Reported by",
                                value: reporter, iconColor: AppConfig.Colors.textSecondary)
                        }
                    }

                    // Action Buttons
                    VStack(spacing: 12) {
                        Button(action: {
                            openMapsNavigation(to: rescue.coordinate, name: rescue.title)
                        }) {
                            HStack {
                                Image(systemName: "location.fill")
                                Text("Navigate")
                            }
                            .primaryActionStyle(color: AppConfig.Colors.accent)
                        }

                        Button(action: {
                            Task { await viewModel.completeRescue() }
                        }) {
                            HStack {
                                Image(systemName: "checkmark.seal.fill")
                                Text("Mark as Rescued")
                            }
                            .primaryActionStyle(color: AppConfig.Colors.success)
                        }
                    }
                    .padding(.top, 10)
                    .padding(.bottom, 30)
                }
                .padding(.horizontal, AppConfig.UI.screenPadding)
                .padding(.top, 24)
                .padding(.bottom, 24)
            }
            .background(AppConfig.Colors.background)
            .navigationTitle("Rescue Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showDetailSheet = false
                    }
                    .foregroundColor(AppConfig.Colors.accent)
                }
            }
        }
    }

    // MARK: - Empty States
    private var loadingView: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .tint(AppConfig.Colors.accent)
                .scaleEffect(1.3)
            Text("Checking active rescue...")
                .font(AppConfig.Fonts.body)
                .foregroundColor(AppConfig.Colors.textSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var noActiveRescueView: some View {
        VStack(spacing: 20) {
            Spacer()
            ZStack {
                Circle()
                    .fill(AppConfig.Colors.accent.opacity(0.1))
                    .frame(width: 100, height: 100)
                Image(systemName: "shield.slash.fill")
                    .font(.system(size: 40))
                    .foregroundColor(AppConfig.Colors.accent)
            }

            Text("No Active Rescue")
                .font(AppConfig.Fonts.titleMedium)
                .foregroundColor(AppConfig.Colors.textPrimary)

            Text(
                "You are currently on standby. Accept a rescue request from the Map or Jobs tab to begin."
            )
            .font(AppConfig.Fonts.body)
            .foregroundColor(AppConfig.Colors.textSecondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 40)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers
    private func severityColor(_ severity: String) -> Color {
        switch severity.lowercased() {
        case "severe": return AppConfig.Colors.alert
        case "moderate": return AppConfig.Colors.warning
        default: return AppConfig.Colors.accent
        }
    }

    private func statusColor(_ status: String) -> Color {
        switch status.lowercased() {
        case "dispatched": return AppConfig.Colors.warning
        case "active": return AppConfig.Colors.success
        default: return AppConfig.Colors.accent
        }
    }

    private func openMapsNavigation(to coordinate: CLLocationCoordinate2D, name: String) {
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = name
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }
}

#Preview {
    ActiveRescueView()
}
