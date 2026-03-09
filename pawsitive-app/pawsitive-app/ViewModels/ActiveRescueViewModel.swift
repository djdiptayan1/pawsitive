//
//  ActiveRescueViewModel.swift
//  pawsitive-app
//
//  Created by Antigravity on 10/03/26.
//

import Combine
import CoreLocation
import MapKit
import SwiftUI

@MainActor
class ActiveRescueViewModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    struct NearbyVetPOI: Identifiable {
        let id: String
        let name: String
        let coordinate: CLLocationCoordinate2D
        let subtitle: String
    }

    @Published var activeRescue: ActiveRescueData? = nil
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    @Published var showCompleteAlert = false
    @Published var completeSuccess = false
    @Published var route: MKRoute? = nil
    @Published var nearbyVetPlaces: [NearbyVetPOI] = []

    private var pollTimer: Timer?
    private var locationTimer: Timer?
    private var vetPlacesTimer: Timer?
    private let clLocationManager = CLLocationManager()
    private var currentLocation: CLLocationCoordinate2D?
    private var isFetchingVetPlaces = false

    struct ActiveRescueData: Identifiable {
        let id: String
        let title: String
        let status: String
        let severity: String
        let photoUrl: String?
        let locationName: String?
        let coordinate: CLLocationCoordinate2D
        let reporterName: String?
        let createdAt: String?
    }

    override init() {
        super.init()
        clLocationManager.delegate = self
        clLocationManager.desiredAccuracy = kCLLocationAccuracyBest
        clLocationManager.requestWhenInUseAuthorization()
        clLocationManager.startUpdatingLocation()
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]
    ) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            self.currentLocation = location.coordinate
            if self.nearbyVetPlaces.isEmpty {
                await self.fetchNearbyVetPlaces()
            }
        }
    }

    func startPolling() {
        fetchActiveRescue()
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.fetchActiveRescue() }
        }
        // Ping rescuer location every 3s (keeps broadcasting to citizen via WS)
        locationTimer?.invalidate()
        locationTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) {
            [weak self] _ in
            Task { await self?.pingLocation() }
        }

        vetPlacesTimer?.invalidate()
        Task { await fetchNearbyVetPlaces() }
        vetPlacesTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) {
            [weak self] _ in
            Task { await self?.fetchNearbyVetPlaces() }
        }
    }

    func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
        locationTimer?.invalidate()
        locationTimer = nil
        vetPlacesTimer?.invalidate()
        vetPlacesTimer = nil
    }

    func fetchNearbyVetPlaces() async {
        let center = currentLocation ?? activeRescue?.coordinate
        guard let center else { return }
        guard !isFetchingVetPlaces else { return }
        isFetchingVetPlaces = true
        defer { isFetchingVetPlaces = false }

        let region = MKCoordinateRegion(
            center: center,
            latitudinalMeters: 15000,
            longitudinalMeters: 15000
        )

        let queries = ["veterinary hospital", "pet clinic", "animal hospital"]
        var mergedItems: [MKMapItem] = []

        for query in queries {
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = query
            request.region = region

            do {
                let response = try await MKLocalSearch(request: request).start()
                mergedItems.append(contentsOf: response.mapItems)
            } catch {
                print("ActiveRescue vet POI search failed for \(query): \(error)")
            }
        }

        var seen = Set<String>()
        let places = mergedItems.compactMap { item -> NearbyVetPOI? in
            let coordinate = item.placemark.coordinate
            let name = item.name ?? "Vet Clinic"
            let key =
                "\(name.lowercased())|\(String(format: "%.5f", coordinate.latitude))|\(String(format: "%.5f", coordinate.longitude))"
            guard !seen.contains(key) else { return nil }
            seen.insert(key)

            return NearbyVetPOI(
                id: key,
                name: name,
                coordinate: coordinate,
                subtitle: item.placemark.title ?? ""
            )
        }

        nearbyVetPlaces = Array(places.prefix(20))
    }

    private func pingLocation() async {
        guard let token = KeychainManager.shared.getString(key: .accessToken),
            let location = currentLocation,
            let rescueId = activeRescue?.id
        else { return }

        do {
            let endpoint = RescuerEndpoint.updateLocation(
                token: token, lat: location.latitude, lng: location.longitude,
                incidentId: rescueId, eta: nil)
            struct PingResponse: Decodable { let ok: Bool? }
            let _: PingResponse = try await NetworkManager.shared.request(endpoint: endpoint)
        } catch {
            print("ActiveRescue: Failed to ping location: \(error)")
        }
    }

    func fetchActiveRescue() {
        Task {
            isLoading = activeRescue == nil
            guard let token = KeychainManager.shared.getString(key: .accessToken) else {
                isLoading = false
                return
            }

            do {
                struct ActiveRescueResponse: Decodable {
                    let incident: ActiveRescueDTO?
                }
                struct ActiveRescueDTO: Decodable {
                    let id: String
                    let title: String?
                    let status: String
                    let severity: String
                    let photoUrl: String?
                    let locationName: String?
                    let lat: Double?
                    let lng: Double?
                    let createdAt: String?
                    let reporter: ReporterDTO?

                    enum CodingKeys: String, CodingKey {
                        case id, title, status, severity
                        case photoUrl = "photo_url"
                        case locationName = "location_name"
                        case lat, lng
                        case createdAt = "created_at"
                        case reporter
                    }
                }
                struct ReporterDTO: Decodable {
                    let fullName: String?
                    let email: String?
                    enum CodingKeys: String, CodingKey {
                        case fullName = "full_name"
                        case email
                    }
                }

                let result: ActiveRescueResponse = try await NetworkManager.shared.request(
                    endpoint: IncidentEndpoint.activeRescue(token: token),
                    keyDecodingStrategy: .useDefaultKeys
                )

                if let dto = result.incident, let lat = dto.lat, let lng = dto.lng {
                    let rescue = ActiveRescueData(
                        id: dto.id,
                        title: dto.title ?? "Rescue Mission",
                        status: dto.status,
                        severity: dto.severity,
                        photoUrl: dto.photoUrl,
                        locationName: dto.locationName,
                        coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng),
                        reporterName: dto.reporter?.fullName ?? dto.reporter?.email,
                        createdAt: dto.createdAt
                    )
                    activeRescue = rescue
                    if let userLoc = clLocationManager.location?.coordinate {
                        calculateRoute(from: userLoc, to: rescue.coordinate)
                    } else if let userLoc = CLLocationManager().location?.coordinate {
                        calculateRoute(from: userLoc, to: rescue.coordinate)
                    }
                } else {
                    activeRescue = nil
                    route = nil
                }
            } catch {
                if activeRescue == nil {
                    errorMessage = "Failed to check active rescue."
                }
                print("ActiveRescue fetch error: \(error)")
            }
            isLoading = false
        }
    }

    func completeRescue() async {
        guard let rescue = activeRescue,
            let token = KeychainManager.shared.getString(key: .accessToken)
        else { return }

        do {
            struct CompleteResponse: Decodable {
                let success: Bool?
            }
            let _: CompleteResponse = try await NetworkManager.shared.request(
                endpoint: IncidentEndpoint.completeIncident(token: token, id: rescue.id))
            completeSuccess = true
            activeRescue = nil
            route = nil
        } catch {
            completeSuccess = false
            print("Complete rescue error: \(error)")
        }
        showCompleteAlert = true
    }

    private func calculateRoute(
        from source: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D
    ) {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: source))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
        request.transportType = .automobile

        MKDirections(request: request).calculate { [weak self] response, _ in
            Task { @MainActor in
                self?.route = response?.routes.first
            }
        }
    }
}
