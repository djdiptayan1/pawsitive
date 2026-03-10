//
//  RescueReplayViewModel.swift
//  pawsitive-app
//
//  Created by Diptayan Jash on 10/03/26.
//

import Combine
import CoreLocation
import MapKit
import SwiftUI

// MARK: - Models

struct LocationHistoryPoint: Codable, Identifiable {
    let id: String
    let rescuerId: String
    let lat: Double
    let lng: Double
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case rescuerId = "rescuer_id"
        case lat, lng
        case createdAt = "created_at"
    }
}

struct LocationHistoryResponse: Codable {
    let points: [LocationHistoryPoint]
}

// MARK: - ViewModel

@MainActor
class RescueReplayViewModel: ObservableObject {
    @Published var routeCoordinates: [CLLocationCoordinate2D] = []
    @Published var currentReplayPosition: CLLocationCoordinate2D? = nil
    @Published var incidentCoordinate: CLLocationCoordinate2D? = nil
    @Published var severity: String = "Minor"
    @Published var cameraPosition: MapCameraPosition = .automatic

    @Published var isPlaying: Bool = false
    @Published var isLoading: Bool = true
    @Published var errorMessage: String? = nil
    @Published var elapsedTimeFormatted: String = "0:00"
    @Published var replayProgress: Double = 0.0

    private var replayIndex: Int = 0
    private var replayTimer: Timer? = nil
    private var timestamps: [Date] = []

    func loadReplay(incidentId: String) {
        Task {
            isLoading = true
            errorMessage = nil

            do {
                // Fetch incident details (for location + severity)
                struct IncidentResponse: Codable {
                    let incident: IncidentDetail
                }
                struct IncidentDetail: Codable {
                    let id: String
                    let severity: String?
                    let geoLocation: String?
                    let lat: Double?
                    let lng: Double?

                    enum CodingKeys: String, CodingKey {
                        case id, severity, lat, lng
                        case geoLocation = "geo_location"
                    }
                }

                // Fetch location history
                let historyResponse: LocationHistoryResponse =
                    try await NetworkManager.shared.request(
                        endpoint: IncidentEndpoint.locationHistory(
                            token: "", id: incidentId)
                    )

                let points = historyResponse.points

                if points.isEmpty {
                    errorMessage = "No GPS trail available for this rescue."
                    isLoading = false
                    return
                }

                // Parse coordinates
                routeCoordinates = points.map {
                    CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lng)
                }

                // Parse timestamps for time display
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                timestamps = points.compactMap { formatter.date(from: $0.createdAt) }

                // Set initial state
                currentReplayPosition = routeCoordinates.first
                replayIndex = 0
                replayProgress = 0.0
                updateElapsedTime()

                // Set incident coordinate from last point (approximate — animal location)
                if let lastCoord = routeCoordinates.last {
                    incidentCoordinate = lastCoord
                }

                // Fit map to show entire route
                if let first = routeCoordinates.first {
                    let region = MKCoordinateRegion(
                        center: first,
                        span: MKCoordinateSpan(
                            latitudeDelta: 0.02, longitudeDelta: 0.02)
                    )
                    cameraPosition = .region(region)
                }

                isLoading = false
            } catch {
                errorMessage = "Could not load rescue replay."
                isLoading = false
            }
        }
    }

    func togglePlayback() {
        if isPlaying {
            pausePlayback()
        } else {
            startPlayback()
        }
    }

    private func startPlayback() {
        guard !routeCoordinates.isEmpty else { return }

        // If at the end, restart
        if replayIndex >= routeCoordinates.count - 1 {
            replayIndex = 0
        }

        isPlaying = true
        replayTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) {
            [weak self] _ in
            Task { @MainActor in
                self?.advanceReplay()
            }
        }
    }

    private func pausePlayback() {
        isPlaying = false
        replayTimer?.invalidate()
        replayTimer = nil
    }

    private func advanceReplay() {
        guard replayIndex < routeCoordinates.count - 1 else {
            pausePlayback()
            return
        }

        replayIndex += 1
        currentReplayPosition = routeCoordinates[replayIndex]
        replayProgress = Double(replayIndex) / Double(max(routeCoordinates.count - 1, 1))
        updateElapsedTime()
    }

    private func updateElapsedTime() {
        guard timestamps.count > 1,
            replayIndex < timestamps.count,
            let start = timestamps.first
        else {
            elapsedTimeFormatted = "0:00"
            return
        }

        let elapsed = timestamps[replayIndex].timeIntervalSince(start)
        let minutes = Int(elapsed) / 60
        let seconds = Int(elapsed) % 60
        elapsedTimeFormatted = String(format: "%d:%02d", minutes, seconds)
    }

    deinit {
        replayTimer?.invalidate()
    }
}
