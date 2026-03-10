import Combine
import Foundation
import MapKit
import Supabase
import SwiftUI

// MARK: - Models

struct ActiveIncident: Identifiable {
    let id: String
    let title: String
    let status: String
    let severity: String
    let photoUrl: String?
    let locationName: String?
    let coordinate: CLLocationCoordinate2D
    let rescuerName: String?
    let rescuerId: String?
    let rescuerAvatarUrl: String?
    let ngoName: String?
    let ngoCity: String?
    let witnessCount: Int

    var severityColor: String {
        switch severity.lowercased() {
        case "severe": return "Alert"
        case "moderate": return "Warning"
        default: return "Accent"
        }
    }
}

struct NearbyWitnessIncident: Identifiable {
    let id: String
    let title: String
    let severity: String
    let status: String
    let witnessCount: Int
    let coordinate: CLLocationCoordinate2D
    let distanceMeters: Double
}

struct HeatmapPoint: Identifiable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let weight: Int
}

struct ConditionLogEntry: Identifiable {
    let id: String
    let stage: String
    let note: String?
    let createdAt: String
}

struct NearbyRescuer: Identifiable {
    let id: String
    let name: String
    let distance: Double
    let coordinate: CLLocationCoordinate2D
}

struct NearbyVetPOI: Identifiable {
    let id: String
    let name: String
    let coordinate: CLLocationCoordinate2D
    let subtitle: String
}

// MARK: - ViewModel

@MainActor
class CitizenMapViewModel: ObservableObject {
    // Map state
    @Published var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)
    @Published var userLocation: CLLocationCoordinate2D?

    // Incident state
    @Published var activeIncident: ActiveIncident?
    @Published var isLoading = false

    // Rescuer live tracking
    @Published var rescuerLocation: CLLocationCoordinate2D?
    @Published var route: MKRoute?
    @Published var etaSeconds: Int?
    @Published var rescueCompletionPhotoUrl: String?
    @Published var rescueCompletionDropOffType: String?

    // Nearby rescuers (shown on map always)
    @Published var nearbyRescuers: [NearbyRescuer] = []
    @Published var nearbyVetPlaces: [NearbyVetPOI] = []
    @Published var nearbyWitnessIncidents: [NearbyWitnessIncident] = []
    @Published var heatmapPoints: [HeatmapPoint] = []
    @Published var isHeatmapEnabled = false
    @Published var conditionTimeline: [ConditionLogEntry] = []
    @Published var witnessActionMessage: String?

    // WS status
    @Published var wsConnected = false

    private var wsTask: URLSessionWebSocketTask?
    private var pollTimer: Timer?
    private var nearbyRescuerTimer: Timer?
    private var nearbyVetTimer: Timer?
    private let locationManager = LocationManager()
    private var cancellables = Set<AnyCancellable>()
    private var isFetchingVetPlaces = false

    init() {
        print("🗺️ [CitizenMapViewModel] Initializing...")

        // Subscribe first so first location update is not missed.
        locationManager.$location
            .compactMap { $0 }
            .sink { [weak self] coord in
                print(
                    "🗺️ [CitizenMapViewModel] User location updated: \(coord.latitude), \(coord.longitude)"
                )
                self?.userLocation = coord
                if self?.nearbyVetPlaces.isEmpty == true {
                    Task { await self?.fetchNearbyVetPlaces() }
                }
            }
            .store(in: &cancellables)

        locationManager.requestPermission()
        locationManager.startUpdating()
    }

    deinit {
        pollTimer?.invalidate()
        nearbyRescuerTimer?.invalidate()
        nearbyVetTimer?.invalidate()
        wsTask?.cancel(with: .goingAway, reason: nil)
    }

    // MARK: - Fetch Active Incident

    func fetchActiveIncident() async {
        guard let token = KeychainManager.shared.getString(key: .accessToken) else { return }

        struct ActiveIncidentResponse: Decodable {
            let incident: ActiveIncidentDTO?
        }

        struct ActiveIncidentDTO: Decodable {
            let id: String
            let title: String?
            let status: String
            let severity: String
            let photoUrl: String?
            let locationName: String?
            let lat: Double?
            let lng: Double?
            let assignedRescuerId: String?
            let witnessCount: Int?
            let rescuer: RescuerDTO?

            enum CodingKeys: String, CodingKey {
                case id, title, status, severity
                case photoUrl = "photo_url"
                case locationName = "location_name"
                case lat, lng
                case assignedRescuerId = "assigned_rescuer_id"
                case witnessCount = "witness_count"
                case rescuer
            }
        }

        struct RescuerDTO: Decodable {
            let fullName: String?
            let email: String?
            let avatarUrl: String?
            let ngo: NGODTO?

            enum CodingKeys: String, CodingKey {
                case fullName = "full_name"
                case email
                case avatarUrl = "avatar_url"
                case ngo
            }
        }

        struct NGODTO: Decodable {
            let name: String?
            let operatingCity: String?

            enum CodingKeys: String, CodingKey {
                case name
                case operatingCity = "operating_city"
            }
        }

        do {
            let result: ActiveIncidentResponse = try await NetworkManager.shared.request(
                endpoint: IncidentEndpoint.activeIncident(token: token),
                keyDecodingStrategy: .useDefaultKeys
            )

            if let dto = result.incident, let lat = dto.lat, let lng = dto.lng {
                let incident = ActiveIncident(
                    id: dto.id,
                    title: dto.title ?? "Rescue Request",
                    status: dto.status,
                    severity: dto.severity,
                    photoUrl: dto.photoUrl,
                    locationName: dto.locationName,
                    coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng),
                    rescuerName: dto.rescuer?.fullName ?? dto.rescuer?.email,
                    rescuerId: dto.assignedRescuerId,
                    rescuerAvatarUrl: dto.rescuer?.avatarUrl,
                    ngoName: dto.rescuer?.ngo?.name,
                    ngoCity: dto.rescuer?.ngo?.operatingCity,
                    witnessCount: dto.witnessCount ?? 0
                )

                let wasNil = activeIncident == nil
                activeIncident = incident

                // Always join the incident room so we receive the "accepted" event the
                // moment a rescuer claims the job — don't wait for the 10 s poll.
                if !wsConnected { connectWebSocket(incidentId: incident.id) }

                if (incident.status == "dispatched" || incident.status == "active")
                    && incident.rescuerId != nil {
                    await fetchConditionTimeline(incidentId: incident.id)
                } else {
                    // Still pending — clear any stale rescuer data
                    rescuerLocation = nil
                    route = nil
                    etaSeconds = nil
                    conditionTimeline = []
                }

                // Center map on incident if first load
                if wasNil {
                    cameraPosition = .region(
                        MKCoordinateRegion(
                            center: incident.coordinate,
                            latitudinalMeters: 2000,
                            longitudinalMeters: 2000
                        ))
                }
            } else {
                activeIncident = nil
                disconnectWebSocket()
                rescuerLocation = nil
                route = nil
                etaSeconds = nil
                conditionTimeline = []
            }
        } catch {
            // Silent — map still shows user location
        }
    }

    // MARK: - Nearby Rescuers

    func fetchNearbyRescuers() async {
        guard let token = KeychainManager.shared.getString(key: .accessToken),
              let userLoc = userLocation
        else {
            print("⚠️ [Nearby Rescuers] Skipped - token or location missing")
            print("   Token exists: \(KeychainManager.shared.getString(key: .accessToken) != nil)")
            print("   User location: \(String(describing: userLocation))")
            return
        }

        print("🔍 [Nearby Rescuers] Fetching nearby rescuers...")
        print("   User location: \(userLoc.latitude), \(userLoc.longitude)")
        print("   Radius: 100000m (100km)")

        struct NearbyResponse: Decodable {
            let rescuers: [NearbyRescuerDTO]
        }
        struct NearbyRescuerDTO: Decodable {
            let rescuerId: String
            let distanceMeters: Double?
            let fullName: String?
            let lat: Double?
            let lng: Double?

            enum CodingKeys: String, CodingKey {
                case rescuerId = "rescuer_id"
                case distanceMeters = "distance_meters"
                case fullName = "full_name"
                case lat, lng
            }
        }

        do {
            let result: NearbyResponse = try await NetworkManager.shared.request(
                endpoint: RescuerEndpoint.nearbyRescuers(
                    token: token, lat: userLoc.latitude, lng: userLoc.longitude, radius: 100000),
                keyDecodingStrategy: .useDefaultKeys
            )

            print("✅ [Nearby Rescuers] Response received: \(result.rescuers.count) rescuers")
            for (index, rescuer) in result.rescuers.enumerated() {
                print(
                    "   [\(index + 1)] \(rescuer.fullName ?? "Unknown") - \(rescuer.distanceMeters ?? 0)m - Coords: (\(rescuer.lat ?? 0), \(rescuer.lng ?? 0))"
                )
            }

            nearbyRescuers = result.rescuers.compactMap { dto in
                guard let lat = dto.lat, let lng = dto.lng else { return nil }
                return NearbyRescuer(
                    id: dto.rescuerId,
                    name: dto.fullName ?? "Rescuer",
                    distance: dto.distanceMeters ?? 0,
                    coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng)
                )
            }
            print("📍 [Nearby Rescuers] Displaying \(nearbyRescuers.count) rescuers on map")
        } catch {
            print("❌ [Nearby Rescuers] Error: \(error.localizedDescription)")
            if let error = error as? NetworkError {
                print("   Network error: \(error)")
            }
        }
    }

    // MARK: - Polling

    func startPolling() {
        pollTimer?.invalidate()
        nearbyRescuerTimer?.invalidate()
        nearbyVetTimer?.invalidate()

        print("🚀 [Polling] Starting timers...")

        // Poll for active incident every 10s
        Task { await fetchActiveIncident() }
        pollTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            Task {
                await self?.fetchActiveIncident()
            }
        }

        // Poll for nearby rescuers every 5s
        Task { await fetchNearbyRescuersIfNeeded() }
        nearbyRescuerTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) {
            [weak self] _ in
            Task {
                await self?.fetchNearbyRescuersIfNeeded()
                await self?.fetchNearbyActiveIncidents()
            }
        }

        Task { await fetchNearbyActiveIncidents() }
        Task { await fetchHeatmapPoints() }

        // Refresh nearby vet clinics/hospitals every minute.
        Task { await fetchNearbyVetPlaces() }
        nearbyVetTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) {
            [weak self] _ in
            Task {
                await self?.fetchNearbyVetPlaces()
            }
        }
    }

    func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
        nearbyRescuerTimer?.invalidate()
        nearbyRescuerTimer = nil
        nearbyVetTimer?.invalidate()
        nearbyVetTimer = nil
        disconnectWebSocket()
    }

    // Always fetch nearby rescuers — they should always be visible on the map
    private func fetchNearbyRescuersIfNeeded() async {
        print("🔄 [Nearby Check] Fetching nearby rescuers...")
        await fetchNearbyRescuers()
    }

    func fetchNearbyActiveIncidents() async {
        guard activeIncident == nil,
              let token = KeychainManager.shared.getString(key: .accessToken),
              let userLoc = userLocation else {
            nearbyWitnessIncidents = []
            return
        }

        struct NearbyResponse: Decodable {
            let incidents: [NearbyIncidentDTO]
        }

        struct NearbyIncidentDTO: Decodable {
            let id: String
            let title: String
            let severity: String
            let status: String
            let witnessCount: Int?
            let lat: Double
            let lng: Double
            let distanceMeters: Double?

            enum CodingKeys: String, CodingKey {
                case id, title, severity, status, lat, lng
                case witnessCount = "witness_count"
                case distanceMeters = "distance_meters"
            }
        }

        do {
            let result: NearbyResponse = try await NetworkManager.shared.request(
                endpoint: IncidentEndpoint.nearbyActiveIncidents(
                    token: token,
                    lat: userLoc.latitude,
                    lng: userLoc.longitude,
                    radius: 1500
                ),
                keyDecodingStrategy: .useDefaultKeys
            )

            nearbyWitnessIncidents = result.incidents.map { dto in
                NearbyWitnessIncident(
                    id: dto.id,
                    title: dto.title,
                    severity: dto.severity,
                    status: dto.status,
                    witnessCount: dto.witnessCount ?? 0,
                    coordinate: CLLocationCoordinate2D(latitude: dto.lat, longitude: dto.lng),
                    distanceMeters: dto.distanceMeters ?? 0
                )
            }
        } catch {
            print("Failed to load nearby active incidents: \(error)")
        }
    }

    func fetchHeatmapPoints() async {
        struct HeatmapResponse: Decodable {
            let points: [HeatmapPointDTO]
        }

        struct HeatmapPointDTO: Decodable {
            let lat: Double
            let lng: Double
            let weight: Int
        }

        do {
            let result: HeatmapResponse = try await NetworkManager.shared.request(
                endpoint: IncidentEndpoint.heatmap(limit: 500),
                keyDecodingStrategy: .useDefaultKeys
            )
            heatmapPoints = result.points.enumerated().map { idx, point in
                HeatmapPoint(
                    id: "heatmap-\(idx)-\(point.lat)-\(point.lng)",
                    coordinate: CLLocationCoordinate2D(latitude: point.lat, longitude: point.lng),
                    weight: point.weight
                )
            }
        } catch {
            print("Failed to load heatmap points: \(error)")
        }
    }

    // MARK: - Native POI Search (Vet / Pet Clinics)

    func fetchNearbyVetPlaces() async {
        guard let userLoc = userLocation else { return }
        guard !isFetchingVetPlaces else { return }
        isFetchingVetPlaces = true
        defer { isFetchingVetPlaces = false }

        let region = MKCoordinateRegion(
            center: userLoc,
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
                print("❌ [Vet POI] Search failed for \(query): \(error)")
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
        print("🏥 [Vet POI] Displaying \(nearbyVetPlaces.count) vet/pet places")
    }

    // MARK: - WebSocket (live rescuer tracking)

    private func connectWebSocket(incidentId: String) {
        guard let userId = KeychainManager.shared.getString(key: .userID) else { return }

        let baseURL = AppConfig.ApiEndpoints.baseURL
            .replacingOccurrences(of: "http://", with: "ws://")
            .replacingOccurrences(of: "https://", with: "wss://")
            .replacingOccurrences(of: "/api/", with: "")

        let wsURLString = "\(baseURL)/ws/track?role=citizen&userId=\(userId)&incident=\(incidentId)"
        guard let url = URL(string: wsURLString) else { return }

        wsTask?.cancel(with: .goingAway, reason: nil)
        let session = URLSession(configuration: .default)
        wsTask = session.webSocketTask(with: url)
        wsTask?.resume()
        wsConnected = true
        receiveMessage()
    }

    private func disconnectWebSocket() {
        wsTask?.cancel(with: .goingAway, reason: nil)
        wsTask = nil
        wsConnected = false
    }

    private func receiveMessage() {
        wsTask?.receive { [weak self] result in
            switch result {
            case let .success(message):
                if case let .string(text) = message,
                   let data = text.data(using: .utf8) {
                    self?.handleWSMessage(data)
                }
                self?.receiveMessage() // Keep listening
            case .failure:
                Task { @MainActor in
                    self?.wsConnected = false
                    // Auto-reconnect after 5s if we still have an active incident
                    if let incidentId = self?.activeIncident?.id {
                        try? await Task.sleep(nanoseconds: 5000000000)
                        if self?.wsConnected == false {
                            print("🔄 [WS] Auto-reconnecting for incident \(incidentId)...")
                            self?.connectWebSocket(incidentId: incidentId)
                        }
                    }
                }
            }
        }
    }

    private func handleWSMessage(_ data: Data) {
        struct WSMessage: Decodable {
            let type: String
            let lat: Double?
            let lng: Double?
            let etaSeconds: Int?
            let rescuerId: String?
            let rescuerName: String?
            let severity: String?
            let rescuePhotoUrl: String? // NEW — for proof of rescue
            let dropOffType: String?
            let witnessCount: Int?
            let stage: String?
            let note: String?
            let createdAt: String?
            let notification: WSNotification?

            struct WSNotification: Decodable {
                let title: String
                let body: String
            }
        }

        guard let msg = try? JSONDecoder().decode(WSMessage.self, from: data) else { return }

        Task { @MainActor [weak self] in
            guard let self else { return }

            switch msg.type {
            case "location_update":
                if let lat = msg.lat, let lng = msg.lng {
                    let newLoc = CLLocationCoordinate2D(latitude: lat, longitude: lng)
                    self.rescuerLocation = newLoc
                    if let eta = msg.etaSeconds { self.etaSeconds = eta }
                    // Recalculate route
                    self.calculateRoute(from: newLoc, to: self.activeIncident?.coordinate)
                }

            case "accepted":
                // Rescuer just accepted — refresh incident data
                if let n = msg.notification {
                    LocalNotificationService.shared.fire(title: n.title, body: n.body)
                }
                await self.fetchActiveIncident()
                if let incidentId = self.activeIncident?.id {
                    await self.fetchConditionTimeline(incidentId: incidentId)
                }

            case "condition_update":
                if let n = msg.notification {
                    LocalNotificationService.shared.fire(title: n.title, body: n.body)
                }
                if let incidentId = self.activeIncident?.id {
                    await self.fetchConditionTimeline(incidentId: incidentId)
                }

            case "witness_update":
                if let count = msg.witnessCount, var incident = self.activeIncident {
                    incident = ActiveIncident(
                        id: incident.id,
                        title: incident.title,
                        status: incident.status,
                        severity: msg.severity ?? incident.severity,
                        photoUrl: incident.photoUrl,
                        locationName: incident.locationName,
                        coordinate: incident.coordinate,
                        rescuerName: incident.rescuerName,
                        rescuerId: incident.rescuerId,
                        rescuerAvatarUrl: incident.rescuerAvatarUrl,
                        ngoName: incident.ngoName,
                        ngoCity: incident.ngoCity,
                        witnessCount: count
                    )
                    self.activeIncident = incident
                }
                if let n = msg.notification {
                    LocalNotificationService.shared.fire(title: n.title, body: n.body)
                }

            case "rescued":
                // Incident resolved
                if let n = msg.notification {
                    LocalNotificationService.shared.fire(title: n.title, body: n.body)
                }
                if let photoUrl = msg.rescuePhotoUrl {
                    self.rescueCompletionPhotoUrl = photoUrl // bind to UI
                }
                self.rescueCompletionDropOffType = msg.dropOffType
                self.activeIncident = nil
                self.rescuerLocation = nil
                self.route = nil
                self.etaSeconds = nil
                self.disconnectWebSocket()

            default:
                break
            }
        }
    }

    func submitWitnessReport(incident: NearbyWitnessIncident, severity: UrgencySeverity) async {
        guard let token = KeychainManager.shared.getString(key: .accessToken) else { return }

        struct WitnessResponse: Decodable {
            let result: WitnessResult
        }

        struct WitnessResult: Decodable {
            let alreadyWitnessed: Bool
            let witnessCount: Int?

            enum CodingKeys: String, CodingKey {
                case alreadyWitnessed = "alreadyWitnessed"
                case witnessCount = "witnessCount"
            }
        }

        do {
            let result: WitnessResponse = try await NetworkManager.shared.request(
                endpoint: IncidentEndpoint.witnessIncident(token: token, id: incident.id, severity: severity.rawValue),
                keyDecodingStrategy: .useDefaultKeys
            )

            if result.result.alreadyWitnessed {
                witnessActionMessage = "You already confirmed this incident."
            } else {
                let count = result.result.witnessCount ?? (incident.witnessCount + 1)
                witnessActionMessage = "Thanks. \(count) witnesses have confirmed this case."
            }

            await fetchNearbyActiveIncidents()
            await fetchHeatmapPoints()
        } catch {
            witnessActionMessage = "Could not submit your witness confirmation."
            print("Witness submit failed: \(error)")
        }
    }

    func fetchConditionTimeline(incidentId: String) async {
        guard let token = KeychainManager.shared.getString(key: .accessToken) else { return }

        struct ConditionResponse: Decodable {
            let entries: [ConditionEntryDTO]
        }

        struct ConditionEntryDTO: Decodable {
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
            let result: ConditionResponse = try await NetworkManager.shared.request(
                endpoint: IncidentEndpoint.getConditionLog(token: token, id: incidentId),
                keyDecodingStrategy: .useDefaultKeys
            )

            conditionTimeline = result.entries.map {
                ConditionLogEntry(id: $0.id, stage: $0.stage, note: $0.note, createdAt: $0.createdAt)
            }
        } catch {
            print("Failed to fetch condition timeline: \(error)")
        }
    }

    func prettyStage(_ stage: String) -> String {
        switch stage {
        case "en_route": return "En Route"
        case "on_scene": return "On Scene"
        case "first_aid": return "First Aid"
        case "in_transport": return "In Transport"
        case "at_vet": return "At Vet"
        case "recovered": return "Recovered"
        default: return stage.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    // MARK: - Route Calculation

    func calculateRoute(
        from source: CLLocationCoordinate2D?, to destination: CLLocationCoordinate2D?
    ) {
        guard let source, let destination else { return }

        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: source))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
        request.transportType = .automobile

        MKDirections(request: request).calculate { [weak self] response, _ in
            Task { @MainActor in
                if let route = response?.routes.first {
                    self?.route = route
                    if self?.etaSeconds == nil {
                        self?.etaSeconds = Int(route.expectedTravelTime)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    var etaFormatted: String {
        guard let eta = etaSeconds else { return "" }
        if eta < 60 { return "< 1 min" }
        let minutes = eta / 60
        return "\(minutes) min"
    }

    var distanceFormatted: String {
        guard let route else { return "" }
        let km = route.distance / 1000
        if km < 1 {
            return String(format: "%.0f m", route.distance)
        }
        return String(format: "%.1f km", km)
    }
}
