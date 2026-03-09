import Foundation

enum RescuerEndpoint: Endpoint {
    case updateLocation(token: String, lat: Double, lng: Double, incidentId: String?, eta: Int?)
    case nearbyRescuers(token: String, lat: Double, lng: Double, radius: Double)

    var path: String {
        switch self {
        case .updateLocation:
            return "rescuers/location"
        case .nearbyRescuers:
            return "rescuers/nearby"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .updateLocation:
            return .post
        case .nearbyRescuers:
            return .get
        }
    }

    var headers: [String: String]? {
        switch self {
        case .updateLocation(let token, _, _, _, _),
            .nearbyRescuers(let token, _, _, _):
            return [
                "Content-Type": "application/json",
                "Authorization": "Bearer \(token)",
            ]
        }
    }

    var body: Encodable? {
        switch self {
        case .updateLocation(_, let lat, let lng, let incidentId, let eta):
            struct LocationPayload: Encodable {
                let lat: Double
                let lng: Double
                let incidentId: String?
                let eta: Int?
            }
            return LocationPayload(lat: lat, lng: lng, incidentId: incidentId, eta: eta)
        case .nearbyRescuers:
            return nil
        }
    }

    var queryItems: [URLQueryItem]? {
        switch self {
        case .nearbyRescuers(_, let lat, let lng, let radius):
            return [
                URLQueryItem(name: "lat", value: String(lat)),
                URLQueryItem(name: "lng", value: String(lng)),
                URLQueryItem(name: "radius", value: String(radius)),
            ]
        case .updateLocation:
            return nil
        }
    }
}
