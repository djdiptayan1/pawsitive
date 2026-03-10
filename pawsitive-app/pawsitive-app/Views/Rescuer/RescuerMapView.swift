//
//  RescuerMapView.swift
//  pawsitive-app
//
//  Created by Diptayan Jash on 09/03/26.
//

import MapKit
import SwiftUI

struct RescuerMapView: View {
    @StateObject private var viewModel = RescuerMapViewModel()

    @State private var position: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var selectedIncident: RecentActivityModel? = nil
    @State private var selectedVetPlace: NearbyVetPlace?
    @State private var showAcceptAlert = false
    @State private var acceptSuccess = false
    @State private var showVetOptions = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Map(position: $position) {
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

                ForEach(viewModel.pendingIncidents) { incident in
                    if let lat = incident.lat, let lng = incident.lng {
                        Annotation(
                            incident.title ?? "Emergency",
                            coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng),
                            anchor: .bottom
                        ) {
                            IncidentAnnotationView(
                                severity: incident.severity ?? "minor"
                            )
                            .onTapGesture {
                                selectedIncident = incident
                            }
                        }
                    }
                }
            }
            .mapControls {
                MapUserLocationButton()
                MapCompass()
                MapScaleView()
            }

            // Bottom status card
            VStack {
                Spacer()

                if viewModel.isLoading && viewModel.pendingIncidents.isEmpty {
                    statusCard {
                        HStack(spacing: 12) {
                            ProgressView()
                                .tint(AppConfig.Colors.accent)
                            Text("Loading incidents...")
                                .font(AppConfig.Fonts.body)
                                .foregroundColor(AppConfig.Colors.textPrimary)
                        }
                    }
                } else if viewModel.pendingIncidents.isEmpty {
                    statusCard {
                        VStack(spacing: 8) {
                            Image(systemName: "pawprint.fill")
                                .font(.title2)
                                .foregroundColor(AppConfig.Colors.accent)
                            Text("No pending incidents")
                                .font(AppConfig.Fonts.bodyBold)
                                .foregroundColor(AppConfig.Colors.textPrimary)
                            Text("New SOS alerts will appear automatically")
                                .font(AppConfig.Fonts.small)
                                .foregroundColor(AppConfig.Colors.textSecondary)
                        }
                    }
                } else {
                    statusCard {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(AppConfig.Colors.alert)
                            Text(
                                "\(viewModel.pendingIncidents.count) pending rescue\(viewModel.pendingIncidents.count == 1 ? "" : "s")"
                            )
                            .font(AppConfig.Fonts.bodyBold)
                            .foregroundColor(AppConfig.Colors.textPrimary)

                            Spacer()

                            Circle()
                                .fill(
                                    viewModel.wsConnected
                                        ? AppConfig.Colors.success : AppConfig.Colors.alert
                                )
                                .frame(width: 8, height: 8)
                            Text(viewModel.wsConnected ? "Live" : "Polling")
                                .font(AppConfig.Fonts.small)
                                .foregroundColor(AppConfig.Colors.textSecondary)
                        }
                    }
                }
            }
        }
        .onAppear {
            viewModel.startMonitoring()
        }
        .onDisappear {
            viewModel.stopMonitoring()
        }
        .sheet(item: $selectedIncident) { (incident: RecentActivityModel) in
            IncidentDetailSheet(incident: incident) {
                Task {
                    let success = await viewModel.acceptIncident(id: incident.id)
                    acceptSuccess = success
                    selectedIncident = nil
                    showAcceptAlert = true
                }
            }
            .presentationDetents([.medium])
        }
        .alert(
            acceptSuccess ? "Rescue Accepted!" : "Could Not Accept",
            isPresented: $showAcceptAlert
        ) {
            Button("OK") {}
        } message: {
            Text(
                acceptSuccess
                    ? "You've been assigned. Head to the location now."
                    : "Another rescuer may have already accepted this incident.")
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

    private func statusCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding()
            .frame(maxWidth: .infinity)
            //            .background(
            //                RoundedRectangle(cornerRadius: AppConfig.UI.cornerRadius)
            //                    .fill(AppConfig.Colors.card)
            //                    .shadow(
            //                        color: .black.opacity(0.08),
            //                        radius: AppConfig.UI.cardShadowRadius,
            //                        y: -AppConfig.UI.cardShadowOffsetY)
            //            )
            .glassEffect(.regular, in: .rect(cornerRadius: AppConfig.UI.cornerRadius))
            .tint(AppConfig.Colors.card)
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
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

// MARK: - Incident Detail Sheet
struct IncidentDetailSheet: View {
    let incident: RecentActivityModel
    let onAccept: () -> Void
    @State private var isAccepting = false

    var body: some View {
        VStack(spacing: 20) {
            Capsule()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.top, 10)

            // Photo
            if let photoUrlStr = incident.photoUrl, let photoUrl = URL(string: photoUrlStr) {
                AsyncImage(url: photoUrl) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else if phase.error != nil {
                        placeholderImage
                    } else {
                        ProgressView()
                    }
                }
                .frame(height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)
            }

            VStack(alignment: .leading, spacing: 12) {
                // Title + Severity
                HStack {
                    Text(incident.title ?? "Animal in Distress")
                        .font(AppConfig.Fonts.headline)
                        .foregroundColor(AppConfig.Colors.textPrimary)
                    Spacer()
                    Text((incident.severity ?? "unknown").uppercased())
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(severityColor)
                        .clipShape(Capsule())
                }

                // Location
                if let location = incident.locationName {
                    HStack(spacing: 6) {
                        Image(systemName: "mappin.and.ellipse")
                            .foregroundColor(AppConfig.Colors.textSecondary)
                        Text(location)
                            .font(AppConfig.Fonts.body)
                            .foregroundColor(AppConfig.Colors.textSecondary)
                            .lineLimit(2)
                    }
                }

                // Time
                if let date = incident.createdAt {
                    HStack(spacing: 6) {
                        Image(systemName: "clock")
                            .foregroundColor(AppConfig.Colors.textSecondary)
                        Text(DateUtils.formatSupabaseDate(date))
                            .font(AppConfig.Fonts.small)
                            .foregroundColor(AppConfig.Colors.textSecondary)
                    }
                }
            }
            .padding(.horizontal)

            Spacer()

            // Accept Button
            Button(action: {
                isAccepting = true
                onAccept()
            }) {
                HStack(spacing: 10) {
                    if isAccepting {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                    }
                    Text("Accept Rescue")
                }
                .font(AppConfig.Fonts.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(AppConfig.Colors.success)
                .cornerRadius(AppConfig.UI.buttonCornerRadius)
            }
            .disabled(isAccepting)
            .padding(.horizontal)
            .padding(.bottom)
        }
        .background(AppConfig.Colors.background)
    }

    private var placeholderImage: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(AppConfig.Colors.accent.opacity(0.1))
            .frame(height: 180)
            .overlay(
                Image(systemName: "pawprint.fill")
                    .font(.largeTitle)
                    .foregroundColor(AppConfig.Colors.accent)
            )
            .padding(.horizontal)
    }

    private var severityColor: Color {
        switch incident.severity?.lowercased() {
        case "severe": return AppConfig.Colors.alert
        case "moderate": return AppConfig.Colors.warning
        default: return AppConfig.Colors.accent
        }
    }
}

#Preview {
    RescuerMapView()
}
