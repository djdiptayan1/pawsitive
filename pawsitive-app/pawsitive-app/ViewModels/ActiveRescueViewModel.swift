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
import UIKit

@MainActor
class ActiveRescueViewModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    struct ConditionEntry: Identifiable {
        let id: String
        let stage: String
        let note: String?
        let createdAt: String
    }

    enum RescueStage: String, CaseIterable, Identifiable {
        case enRoute = "en_route"
        case onScene = "on_scene"
        case firstAid = "first_aid"
        case inTransport = "in_transport"
        case atVet = "at_vet"

        var id: String { rawValue }

        var title: String {
            switch self {
            case .enRoute: return "En Route"
            case .onScene: return "On Scene"
            case .firstAid: return "First Aid"
            case .inTransport: return "In Transport"
            case .atVet: return "At Vet"
            }
        }

        var icon: String {
            switch self {
            case .enRoute: return "🚗"
            case .onScene: return "📍"
            case .firstAid: return "🩹"
            case .inTransport: return "🚑"
            case .atVet: return "🏥"
            }
        }
    }

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
    @Published var conditionEntries: [ConditionEntry] = []
    @Published var isPostingConditionUpdate = false
    
    // Proof of Rescue State
    @Published var pickedImage: UIImage? = nil
    @Published var selectedDropOffType: String = "treated_on_scene"
    @Published var isUploadingPhoto = false
    @Published var uploadProgress: Double = 0

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
                    await fetchConditionTimeline(incidentId: rescue.id)
                } else {
                    activeRescue = nil
                    route = nil
                    conditionEntries = []
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

        isLoading = true
        guard let image = pickedImage else {
            completeSuccess = false
            showCompleteAlert = true
            isLoading = false
            return
        }

        let finalPhotoUrl = await uploadRescuePhoto(image)

        guard let finalPhotoUrl else {
            completeSuccess = false
            showCompleteAlert = true
            isLoading = false
            return
        }

        do {
            struct CompleteResponse: Decodable {
                let success: Bool?
            }
            let _: CompleteResponse = try await NetworkManager.shared.request(
                endpoint: IncidentEndpoint.completeIncident(
                    token: token,
                    id: rescue.id,
                    rescuePhotoUrl: finalPhotoUrl,
                    dropOffType: selectedDropOffType
                )
            )
            completeSuccess = true
            activeRescue = nil
            route = nil
            pickedImage = nil
        } catch {
            completeSuccess = false
            print("Complete rescue error: \(error)")
        }
        isLoading = false
        showCompleteAlert = true
    }

    func fetchConditionTimeline(incidentId: String) async {
        guard let token = KeychainManager.shared.getString(key: .accessToken) else { return }

        struct Response: Decodable {
            let entries: [EntryDTO]
        }

        struct EntryDTO: Decodable {
            let id: String
            let stage: String
            let note: String?
            let createdAt: String

            enum CodingKeys: String, CodingKey {
                case id, stage, note
                case createdAt = "created_at"
            }
        }

        do {
            let response: Response = try await NetworkManager.shared.request(
                endpoint: IncidentEndpoint.getConditionLog(token: token, id: incidentId),
                keyDecodingStrategy: .useDefaultKeys
            )

            conditionEntries = response.entries.map {
                ConditionEntry(id: $0.id, stage: $0.stage, note: $0.note, createdAt: $0.createdAt)
            }
        } catch {
            print("Failed to fetch rescue condition timeline: \(error)")
        }
    }

    func postConditionUpdate(stage: RescueStage, note: String?) async {
        guard let rescueId = activeRescue?.id,
              let token = KeychainManager.shared.getString(key: .accessToken) else { return }

        isPostingConditionUpdate = true
        defer { isPostingConditionUpdate = false }

        do {
            struct UpdateResponse: Decodable {
                let entry: EntryDTO
            }

            struct EntryDTO: Decodable {
                let id: String
            }

            let _: UpdateResponse = try await NetworkManager.shared.request(
                endpoint: IncidentEndpoint.postConditionLog(
                    token: token,
                    id: rescueId,
                    stage: stage.rawValue,
                    note: note?.isEmpty == true ? nil : note
                ),
                keyDecodingStrategy: .useDefaultKeys
            )

            await fetchConditionTimeline(incidentId: rescueId)
            LocalNotificationService.shared.fire(
                title: "Condition updated",
                body: "\(stage.icon) \(stage.title) has been shared with the citizen."
            )
        } catch {
            print("Failed to post condition update: \(error)")
        }
    }

    func stageLabel(_ rawStage: String) -> String {
        switch rawStage {
        case "en_route": return "En Route"
        case "on_scene": return "On Scene"
        case "first_aid": return "First Aid"
        case "in_transport": return "In Transport"
        case "at_vet": return "At Vet"
        case "recovered": return "Recovered"
        default: return rawStage.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    func uploadRescuePhoto(_ image: UIImage) async -> String? {
        guard let imageData = image.jpegData(compressionQuality: 0.7) else { return nil }
        isUploadingPhoto = true
        defer { isUploadingPhoto = false }

        do {
            let url = URL(string: "\(AppConfig.ApiEndpoints.baseURL)upload/photo")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            
            if let token = KeychainManager.shared.getString(key: .accessToken) {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }

            let boundary = UUID().uuidString
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

            var body = Data()
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"photo\"; filename=\"rescue.jpg\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
            body.append(imageData)
            body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

            request.httpBody = body

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                return nil
            }

            struct UploadRes: Decodable { let url: String }
            let res = try JSONDecoder().decode(UploadRes.self, from: data)
            return res.url
        } catch {
            print("Photo upload failed: \(error)")
            return nil
        }
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
