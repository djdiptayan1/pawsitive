//
//  CitizenMapView.swift
//  pawsitive-app
//
//  Created by Diptayan Jash on 09/03/26.
//

import MapKit
import SwiftUI

struct CitizenMapView: View {
    @StateObject private var viewModel = CitizenMapViewModel()
    @State private var showRescuerDetails = false
    @State private var selectedVetPlace: NearbyVetPOI?
    @State private var showVetOptions = false

    var body: some View {
        ZStack(alignment: .bottom) {
            // MARK: - Map
            Map(position: $viewModel.cameraPosition) {
                // Custom user location annotation (purple paw)
                if let userLoc = viewModel.userLocation {
                    Annotation("You", coordinate: userLoc, anchor: .center) {
                        UserLocationPinView()
                    }
                }

                // Incident pin
                if let incident = viewModel.activeIncident {
                    Annotation(
                        incident.title,
                        coordinate: incident.coordinate,
                        anchor: .bottom
                    ) {
                        IncidentAnnotationView(severity: incident.severity)
                    }
                }

                // Rescuer pin (live)
                if let rescuerLoc = viewModel.rescuerLocation {
                    Annotation(
                        viewModel.activeIncident?.rescuerName ?? "Rescuer",
                        coordinate: rescuerLoc,
                        anchor: .center
                    ) {
                        RescuerAnnotationView()
                    }
                }

                // Nearby available rescuers
                ForEach(viewModel.nearbyRescuers) { rescuer in
                    Annotation(
                        rescuer.name,
                        coordinate: rescuer.coordinate,
                        anchor: .center
                    ) {
                        NearbyRescuerPinView()
                    }
                }

                // Nearby vet hospitals and pet clinics (native MapKit search)
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

                // Route polyline
                if let route = viewModel.route {
                    MapPolyline(route.polyline)
                        .stroke(
                            AppConfig.Colors.accent,
                            style: StrokeStyle(lineWidth: 5, lineCap: .round, dash: [8, 6]))
                }
            }
            .mapStyle(.standard(pointsOfInterest: .excludingAll))
            .mapControls {
                MapUserLocationButton()
                MapCompass()
            }
            //            .ignoresSafeArea(edges: .top)

            //            headerOverlay

            // MARK: - Bottom Status Card
            VStack {
                Spacer()

                if let incident = viewModel.activeIncident {
                    statusCard(incident)
                } else {
                    idleCard
                }
            }
        }
        .onAppear {
            viewModel.startPolling()
        }
        .onDisappear {
            viewModel.stopPolling()
        }
        .sheet(isPresented: $showRescuerDetails) {
            if let incident = viewModel.activeIncident,
                incident.status == "dispatched" || incident.status == "active"
            {
                RescuerDetailSheet(incident: incident)
            }
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

    // MARK: - Header Overlay

    private var headerOverlay: some View {
        HStack {
            Text("Pawsitive")
                .font(AppConfig.Fonts.titleMedium)
                .foregroundColor(AppConfig.Colors.textPrimary)
            Text("🐾")
                .font(.title2)
            Spacer()

            if viewModel.activeIncident != nil {
                statusBadge
            }
        }
        .padding(.horizontal, AppConfig.UI.screenPadding)
        .padding(.top, 60)
        .padding(.bottom, 12)
        .background(
            AppConfig.Colors.background.opacity(0.95)
                .ignoresSafeArea(edges: .top)
        )
    }

    private var statusBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusDotColor)
                .frame(width: 8, height: 8)
            Text(viewModel.activeIncident?.status.capitalized ?? "")
                .font(AppConfig.Fonts.small)
                .foregroundColor(AppConfig.Colors.textPrimary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(AppConfig.Colors.card)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
    }

    private var statusDotColor: Color {
        switch viewModel.activeIncident?.status {
        case "pending": return AppConfig.Colors.warning
        case "dispatched", "active": return AppConfig.Colors.success
        default: return AppConfig.Colors.textSecondary
        }
    }

    // MARK: - Status Card (Active Incident)

    private func statusCard(_ incident: ActiveIncident) -> some View {
        VStack(spacing: 0) {
            // Drag handle
            Capsule()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.top, 10)

            VStack(spacing: 12) {
                if incident.status == "dispatched" || incident.status == "active" {
                    // Rescuer en route
                    HStack(spacing: 12) {
                        // Rescuer avatar
                        ZStack {
                            Circle()
                                .fill(AppConfig.Colors.softAccent.opacity(0.3))
                                .frame(width: 50, height: 50)
                            Image(systemName: "figure.wave")
                                .font(.title2)
                                .foregroundColor(AppConfig.Colors.accent)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Pawsitive Hero is on the way!")
                                .font(AppConfig.Fonts.bodyBold)
                                .foregroundColor(AppConfig.Colors.textPrimary)

                            HStack(spacing: 8) {
                                if !viewModel.etaFormatted.isEmpty {
                                    Label(viewModel.etaFormatted, systemImage: "clock")
                                }
                                if !viewModel.distanceFormatted.isEmpty {
                                    Label(viewModel.distanceFormatted, systemImage: "location")
                                }
                            }
                            .font(AppConfig.Fonts.small)
                            .foregroundColor(AppConfig.Colors.textSecondary)

                            if let name = incident.rescuerName {
                                Text("Rescuer: \(name)")
                                    .font(AppConfig.Fonts.small)
                                    .foregroundColor(AppConfig.Colors.textSecondary)
                            }
                        }

                        Spacer()

                        // Tap to expand indicator
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(AppConfig.Colors.textSecondary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        showRescuerDetails = true
                    }
                } else {
                    // Pending — searching
                    VStack(spacing: 10) {
                        HStack(spacing: 10) {
                            ProgressView()
                                .tint(AppConfig.Colors.accent)
                            Text("Searching for nearby rescuers...")
                                .font(AppConfig.Fonts.bodyBold)
                                .foregroundColor(AppConfig.Colors.textPrimary)
                        }

                        Text(incident.locationName ?? incident.title)
                            .font(AppConfig.Fonts.small)
                            .foregroundColor(AppConfig.Colors.textSecondary)
                            .lineLimit(1)

                        // Severity badge
                        Text(incident.severity)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 5)
                            .background(severityColor(incident.severity))
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal, AppConfig.UI.screenPadding)
            .padding(.vertical, 16)
        }
        //        .background(
        //            RoundedRectangle(cornerRadius: AppConfig.UI.cornerRadius)
        //                .fill(AppConfig.Colors.card)
        //                .shadow(color: .black.opacity(0.1), radius: AppConfig.UI.cardShadowRadius, y: -AppConfig.UI.cardShadowOffsetY)
        //        )
        .glassEffect(.clear, in: .rect(cornerRadius: AppConfig.UI.cornerRadius))
        .tint(AppConfig.Colors.card)
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    // MARK: - Idle Card (No Active Incident)

    private var idleCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "pawprint.fill")
                .font(.title)
                .foregroundColor(AppConfig.Colors.accent)

            Text("No active reports")
                .font(AppConfig.Fonts.bodyBold)
                .foregroundColor(AppConfig.Colors.textPrimary)

            Text("Use the SOS tab to report an animal in distress")
                .font(AppConfig.Fonts.small)
                .foregroundColor(AppConfig.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(AppConfig.UI.screenPadding)
        .frame(maxWidth: .infinity)
        //        .background(
        //            RoundedRectangle(cornerRadius: AppConfig.UI.cornerRadius)
        //                .fill(AppConfig.Colors.card)
        //                .shadow(
        //                    color: .black.opacity(0.08), radius: AppConfig.UI.cardShadowRadius,
        //                    y: -AppConfig.UI.cardShadowOffsetY)
        //        )
        .glassEffect( .clear, in: .rect(cornerRadius: AppConfig.UI.cornerRadius))
        .tint(AppConfig.Colors.card)
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    // MARK: - Helpers

    private func severityColor(_ severity: String) -> Color {
        switch severity.lowercased() {
        case "severe": return AppConfig.Colors.alert
        case "moderate": return AppConfig.Colors.warning
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

// MARK: - Incident Annotation (Paw Pin)

struct IncidentAnnotationView: View {
    let severity: String

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(pinColor)
                    .frame(width: 44, height: 44)
                    .shadow(color: pinColor.opacity(0.4), radius: 8, y: 2)

                Image(systemName: "pawprint.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
            }

            // Pin tail
            Triangle()
                .fill(pinColor)
                .frame(width: 16, height: 10)
                .offset(y: -2)
        }
    }

    private var pinColor: Color {
        switch severity.lowercased() {
        case "severe": return AppConfig.Colors.alert
        case "moderate": return AppConfig.Colors.warning
        default: return AppConfig.Colors.accent
        }
    }
}

// MARK: - Rescuer Annotation (Pulsing Dot)

struct RescuerAnnotationView: View {
    @State private var isPulsing = false

    var body: some View {
        ZStack {
            // Pulse ring
            Circle()
                .stroke(AppConfig.Colors.success.opacity(0.3), lineWidth: 2)
                .frame(width: 48, height: 48)
                .scaleEffect(isPulsing ? 1.3 : 1.0)
                .opacity(isPulsing ? 0 : 0.6)
                .animation(
                    .easeInOut(duration: 1.2).repeatForever(autoreverses: false), value: isPulsing)

            // Outer ring
            Circle()
                .fill(AppConfig.Colors.success.opacity(0.2))
                .frame(width: 36, height: 36)

            // Inner dot
            Circle()
                .fill(AppConfig.Colors.success)
                .frame(width: 20, height: 20)

            Image(systemName: "cross.case.fill")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white)
        }
        .onAppear { isPulsing = true }
    }
}

// MARK: - Nearby Rescuer Pin

struct NearbyRescuerPinView: View {
    @State private var isPulsing = false

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.orange.opacity(0.15))
                .frame(width: 44, height: 44)
                .scaleEffect(isPulsing ? 1.5 : 1.0)
                .opacity(isPulsing ? 0 : 0.5)
                .animation(
                    .easeInOut(duration: 1.5).repeatForever(autoreverses: false), value: isPulsing)

            Circle()
                .fill(Color.orange.opacity(0.3))
                .frame(width: 34, height: 34)

            Circle()
                .fill(Color.orange)
                .frame(width: 22, height: 22)
                .shadow(color: .orange.opacity(0.5), radius: 4)

            Image(systemName: "cross.case.fill")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white)
        }
        .onAppear { isPulsing = true }
    }
}

// MARK: - User Location Pin (Purple Paw)

struct UserLocationPinView: View {
    @State private var isPulsing = false

    var body: some View {
        ZStack {
            // Outer pulsing ring
            Circle()
                .fill(Color.purple.opacity(0.2))
                .frame(width: 50, height: 50)
                .scaleEffect(isPulsing ? 1.5 : 1.0)
                .opacity(isPulsing ? 0 : 0.4)
                .animation(
                    .easeInOut(duration: 1.5).repeatForever(autoreverses: false), value: isPulsing)

            // Solid purple circle
            Circle()
                .fill(Color.purple.opacity(0.3))
                .frame(width: 32, height: 32)

            Circle()
                .fill(Color.purple)
                .frame(width: 24, height: 24)

            // Paw icon
            Image(systemName: "pawprint.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
        }
        .onAppear { isPulsing = true }
    }
}

// MARK: - Rescuer Detail Sheet

struct RescuerDetailSheet: View {
    let incident: ActiveIncident
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(AppConfig.Colors.softAccent.opacity(0.3))
                                .frame(width: 100, height: 100)

                            if let avatarUrl = incident.rescuerAvatarUrl {
                                AsyncImage(url: URL(string: avatarUrl)) { image in
                                    image.resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 100, height: 100)
                                        .clipShape(Circle())
                                } placeholder: {
                                    Image(systemName: "figure.wave")
                                        .font(.largeTitle)
                                        .foregroundColor(AppConfig.Colors.accent)
                                }
                            } else {
                                Image(systemName: "figure.wave")
                                    .font(.largeTitle)
                                    .foregroundColor(AppConfig.Colors.accent)
                            }
                        }

                        Text(incident.rescuerName ?? "Rescuer")
                            .font(AppConfig.Fonts.titleLarge)
                            .foregroundColor(AppConfig.Colors.textPrimary)

                        Text("Pawsitive Hero")
                            .font(AppConfig.Fonts.body)
                            .foregroundColor(AppConfig.Colors.textSecondary)
                    }
                    .padding(.top, 20)

                    // NGO Info
                    if let ngoName = incident.ngoName {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Organization")
                                .font(AppConfig.Fonts.bodyBold)
                                .foregroundColor(AppConfig.Colors.textSecondary)

                            HStack(spacing: 16) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(AppConfig.Colors.accent.opacity(0.15))
                                        .frame(width: 50, height: 50)

                                    Image(systemName: "building.2.fill")
                                        .font(.title2)
                                        .foregroundColor(AppConfig.Colors.accent)
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(ngoName)
                                        .font(AppConfig.Fonts.bodyBold)
                                        .foregroundColor(AppConfig.Colors.textPrimary)

                                    if let city = incident.ngoCity {
                                        Label(city, systemImage: "mappin.circle.fill")
                                            .font(AppConfig.Fonts.small)
                                            .foregroundColor(AppConfig.Colors.textSecondary)
                                    }
                                }

                                Spacer()
                            }
                            .padding(16)
                            .background(AppConfig.Colors.card)
                            .cornerRadius(AppConfig.UI.cornerRadius)
                        }
                    }

                    // Incident Details
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Rescue Details")
                            .font(AppConfig.Fonts.bodyBold)
                            .foregroundColor(AppConfig.Colors.textSecondary)

                        VStack(spacing: 12) {
                            detailRow(
                                icon: "doc.text.fill",
                                title: "Case",
                                value: incident.title
                            )

                            Divider()

                            detailRow(
                                icon: "exclamationmark.triangle.fill",
                                title: "Severity",
                                value: incident.severity.capitalized,
                                valueColor: severityColor(incident.severity)
                            )

                            Divider()

                            detailRow(
                                icon: "location.fill",
                                title: "Location",
                                value: incident.locationName ?? "Unknown location"
                            )

                            Divider()

                            detailRow(
                                icon: "circle.fill",
                                title: "Status",
                                value: incident.status.capitalized,
                                valueColor: statusColor(incident.status)
                            )
                        }
                        .padding(16)
                        .background(AppConfig.Colors.card)
                        .cornerRadius(AppConfig.UI.cornerRadius)
                    }

                    // Support Message
                    VStack(spacing: 12) {
                        Image(systemName: "heart.fill")
                            .font(.title)
                            .foregroundColor(AppConfig.Colors.success)

                        Text("Your rescuer is on the way!")
                            .font(AppConfig.Fonts.bodyBold)
                            .foregroundColor(AppConfig.Colors.textPrimary)

                        Text("Thank you for being a voice for those who cannot speak.")
                            .font(AppConfig.Fonts.small)
                            .foregroundColor(AppConfig.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity)
                    .background(AppConfig.Colors.success.opacity(0.1))
                    .cornerRadius(AppConfig.UI.cornerRadius)
                }
                .padding(AppConfig.UI.screenPadding)
            }
            .background(AppConfig.Colors.background)
            .navigationTitle("Rescue Hero")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(AppConfig.Colors.accent)
                }
            }
        }
    }

    private func detailRow(icon: String, title: String, value: String, valueColor: Color? = nil)
        -> some View
    {
        HStack {
            Label(title, systemImage: icon)
                .font(AppConfig.Fonts.body)
                .foregroundColor(AppConfig.Colors.textSecondary)

            Spacer()

            Text(value)
                .font(AppConfig.Fonts.bodyBold)
                .foregroundColor(valueColor ?? AppConfig.Colors.textPrimary)
        }
    }

    private func severityColor(_ severity: String) -> Color {
        switch severity.lowercased() {
        case "severe": return AppConfig.Colors.alert
        case "moderate": return AppConfig.Colors.warning
        default: return AppConfig.Colors.accent
        }
    }

    private func statusColor(_ status: String) -> Color {
        switch status.lowercased() {
        case "active", "dispatched": return AppConfig.Colors.success
        case "pending": return AppConfig.Colors.warning
        default: return AppConfig.Colors.textSecondary
        }
    }
}

#Preview {
    CitizenMapView()
}
