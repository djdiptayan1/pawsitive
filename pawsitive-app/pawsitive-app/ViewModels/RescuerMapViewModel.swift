import Combine
import CoreLocation
import Foundation
import MapKit

struct NearbyVetPlace: Identifiable {
    let id: String
    let name: String
    let coordinate: CLLocationCoordinate2D
    let subtitle: String
}

@MainActor
class RescuerMapViewModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var pendingIncidents: [RecentActivityModel] = []
    @Published var userLocation: CLLocationCoordinate2D? = nil
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    @Published var activeRescueId: String? = nil
    @Published var wsConnected = false
    @Published var nearbyVetPlaces: [NearbyVetPlace] = []

    private let locationManager = CLLocationManager()
    private var locationTimer: Timer?
    private var pollTimer: Timer?
    private var vetPlacesTimer: Timer?
    private var isMonitoring = false
    private var isFetchingVetPlaces = false

    // WebSocket
    private var wsTask: URLSessionWebSocketTask?

    override init() {
        super.init()
        setupLocationManager()
    }

    // MARK: - Location Services

    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        userLocation = location.coordinate

        // Trigger first native POI fetch once we have location.
        if nearbyVetPlaces.isEmpty {
            Task { await fetchNearbyVetPlaces() }
        }
    }

    // MARK: - Lifecycle

    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true

        // Check for existing active rescue so location pings include incidentId
        Task { await fetchActiveRescueId() }

        // Start location pings every 3s
        locationTimer?.invalidate()
        locationTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) {
            [weak self] _ in
            Task { await self?.pingLocation() }
        }

        // Fetch immediately
        fetchPendingIncidents()

        // Connect WebSocket for live SOS alerts
        connectWebSocket()

        // Fallback polling every 10s
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) {
            [weak self] _ in
            Task { @MainActor in self?.fetchPendingIncidents() }
        }

        // Refresh nearby vet places periodically.
        vetPlacesTimer?.invalidate()
        Task { await fetchNearbyVetPlaces() }
        vetPlacesTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) {
            [weak self] _ in
            Task { await self?.fetchNearbyVetPlaces() }
        }
    }

    func stopMonitoring() {
        guard isMonitoring else { return }
        isMonitoring = false
        locationTimer?.invalidate()
        locationTimer = nil
        pollTimer?.invalidate()
        pollTimer = nil
        vetPlacesTimer?.invalidate()
        vetPlacesTimer = nil
        disconnectWebSocket()
    }

    // MARK: - Native POI Search

    func fetchNearbyVetPlaces() async {
        guard let userLocation else { return }
        guard !isFetchingVetPlaces else { return }
        isFetchingVetPlaces = true
        defer { isFetchingVetPlaces = false }

        let region = MKCoordinateRegion(
            center: userLocation,
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
                print("Failed MKLocalSearch for \(query): \(error)")
            }
        }

        var seen = Set<String>()
        let places = mergedItems.compactMap { item -> NearbyVetPlace? in
            let coordinate = item.placemark.coordinate
            let name = item.name ?? "Vet Clinic"
            let key =
                "\(name.lowercased())|\(String(format: "%.5f", coordinate.latitude))|\(String(format: "%.5f", coordinate.longitude))"
            guard !seen.contains(key) else { return nil }
            seen.insert(key)

            let subtitle = item.placemark.title ?? ""
            return NearbyVetPlace(
                id: key,
                name: name,
                coordinate: coordinate,
                subtitle: subtitle
            )
        }

        nearbyVetPlaces = Array(places.prefix(20))
    }

    private func pingLocation() async {
        guard let token = KeychainManager.shared.getString(key: .accessToken),
              let location = userLocation
        else { return }

        do {
            let endpoint = RescuerEndpoint.updateLocation(
                token: token, lat: location.latitude, lng: location.longitude,
                incidentId: activeRescueId, eta: nil)
            struct PingResponse: Decodable { let ok: Bool? }
            let _: PingResponse = try await NetworkManager.shared.request(endpoint: endpoint)
        } catch {
            print("Failed to ping location: \(error)")
        }
    }

    // Fetch active rescue ID so location pings include incidentId for WS broadcast
    private func fetchActiveRescueId() async {
        guard let token = KeychainManager.shared.getString(key: .accessToken) else { return }

        struct ActiveRescueResponse: Decodable {
            let incident: ActiveRescueDTO?
        }
        struct ActiveRescueDTO: Decodable {
            let id: String
            let status: String
        }

        do {
            let result: ActiveRescueResponse = try await NetworkManager.shared.request(
                endpoint: IncidentEndpoint.activeRescue(token: token),
                keyDecodingStrategy: .useDefaultKeys
            )
            if let incident = result.incident,
               incident.status == "dispatched" || incident.status == "active" {
                activeRescueId = incident.id
                print("📋 [RescuerMap] Restored active rescue ID: \(incident.id)")
            }
        } catch {
            print("Failed to fetch active rescue ID: \(error)")
        }
    }

    // MARK: - WebSocket

    private func connectWebSocket() {
        guard let userId = KeychainManager.shared.getString(key: .userID) else {
            print("❌ [WS] No userID in Keychain — cannot connect WebSocket")
            return
        }

        let baseURL = AppConfig.ApiEndpoints.baseURL
            .replacingOccurrences(of: "http://", with: "ws://")
            .replacingOccurrences(of: "https://", with: "wss://")
            .replacingOccurrences(of: "/api/", with: "")

        // Normalise UUID to lowercase — must match what trackingServer stores
        let normalisedUserId = userId.lowercased()
        let wsURLString = "\(baseURL)/ws/track?role=rescuer&userId=\(normalisedUserId)"
        guard let url = URL(string: wsURLString) else {
            print("❌ [WS] Invalid URL: \(wsURLString)")
            return
        }

        wsTask?.cancel(with: .goingAway, reason: nil)
        wsConnected = false

        print("🔗 [WS] Connecting rescuer: \(wsURLString)")

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        let session = URLSession(configuration: config)
        wsTask = session.webSocketTask(with: url)
        wsTask?.resume()
        wsConnected = true

        print("✅ [WS] Rescuer WebSocket connected")

        // Start ping keepalive every 15s so iOS doesn't kill the connection
        startWSPingTimer()
        receiveWSMessage()
    }

    private var wsPingTimer: Timer?

    private func startWSPingTimer() {
        wsPingTimer?.invalidate()
        wsPingTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.wsTask?.sendPing { error in
                    if let error {
                        print("⚠️ [WS] Ping failed: \(error.localizedDescription) — reconnecting")
                        Task { @MainActor in
                            self?.wsConnected = false
                            self?.wsPingTimer?.invalidate()
                            self?.connectWebSocket()
                        }
                    }
                }
            }
        }
    }

    private func disconnectWebSocket() {
        wsPingTimer?.invalidate()
        wsPingTimer = nil
        wsTask?.cancel(with: .goingAway, reason: nil)
        wsTask = nil
        wsConnected = false
    }

    private func receiveWSMessage() {
        wsTask?.receive { [weak self] result in
            switch result {
            case let .success(message):
                if case let .string(text) = message,
                   let data = text.data(using: .utf8) {
                    self?.handleWSMessage(data)
                }
                self?.receiveWSMessage()
            case .failure(let error):
                print("❌ [WS] Receive error: \(error.localizedDescription)")
                Task { @MainActor in
                    self?.wsConnected = false
                    self?.wsPingTimer?.invalidate()
                    // Reconnect after 3s (reduced from 5s for faster recovery)
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                    print("🔄 [WS] Reconnecting rescuer WebSocket...")
                    self?.connectWebSocket()
                }
            }
        }
    }

    private func handleWSMessage(_ data: Data) {
        struct WSMessage: Decodable {
            let type: String
            let incidentId: String?
            let severity: String?
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
            case "new_incident":
                if let n = msg.notification {
                    LocalNotificationService.shared.fire(title: n.title, body: n.body)
                } else {
                    // Fallback if backend doesn't send notification key
                    LocalNotificationService.shared.fire(
                        title: "🐾 Animal in distress nearby!",
                        body: "A \(msg.severity ?? "injured") animal was reported near you. Tap to respond."
                    )
                }
                self.fetchPendingIncidents()
            default:
                break
            }
        }
    }

    // MARK: - Incidents

    func fetchPendingIncidents() {
        Task {
            isLoading = true
            errorMessage = nil

            guard let token = KeychainManager.shared.getString(key: .accessToken) else {
                errorMessage = "Authentication token missing."
                isLoading = false
                return
            }

            do {
                struct PendingIncidentsResponse: Decodable {
                    let incidents: [RecentActivityModel]
                }

                let endpoint = IncidentEndpoint.pendingIncidents(token: token)
                let result: PendingIncidentsResponse = try await NetworkManager.shared.request(
                    endpoint: endpoint,
                    keyDecodingStrategy: .useDefaultKeys)

                self.pendingIncidents = result.incidents
            } catch {
                self.errorMessage = "Failed to load pending incidents."
                print("Error fetching incidents: \(error)")
            }

            isLoading = false
        }
    }

    func acceptIncident(id: String) async -> Bool {
        guard let token = KeychainManager.shared.getString(key: .accessToken) else {
            return false
        }

        do {
            struct AcceptResponse: Decodable {
                let success: Bool
                let error: String?
            }

            let endpoint = IncidentEndpoint.acceptIncident(token: token, id: id)
            let result: AcceptResponse = try await NetworkManager.shared.request(
                endpoint: endpoint,
                keyDecodingStrategy: .useDefaultKeys)

            if result.success {
                activeRescueId = id
                fetchPendingIncidents()
                return true
            }
            return false
        } catch {
            print("Failed to accept incident: \(error)")
            return false
        }
    }
}
