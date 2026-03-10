import Foundation

enum IncidentEndpoint: Endpoint {
    case createIncident(token: String, title: String, locationName: String, lat: Double, lng: Double, photoUrl: String, severity: String)
    case myReports(token: String)
    case myRescues(token: String)
    case activeIncident(token: String)
    case nearbyActiveIncidents(token: String, lat: Double, lng: Double, radius: Double)
    case witnessIncident(token: String, id: String, severity: String)
    case heatmap(limit: Int)
    case activeRescue(token: String)
    case pendingIncidents(token: String)
    case uploadPhoto(token: String, imageData: Data)
    case acceptIncident(token: String, id: String)
    case completeIncident(token: String, id: String, rescuePhotoUrl: String?, dropOffType: String?)
    case getConditionLog(token: String, id: String)
    case postConditionLog(token: String, id: String, stage: String, note: String?)

    var path: String {
        switch self {
        case .createIncident:
            return "incidents"
        case .myReports:
            return "incidents/my-reports"
        case .myRescues:
            return "incidents/my-rescues"
        case .activeIncident:
            return "incidents/active"
        case .nearbyActiveIncidents:
            return "incidents/nearby-active"
        case .witnessIncident(_, let id, _):
            return "incidents/\(id)/witness"
        case .heatmap:
            return "incidents/heatmap"
        case .activeRescue:
            return "incidents/my-active-rescue"
        case .pendingIncidents:
            return "incidents/pending"
        case .uploadPhoto:
            return "upload/photo"
        case .acceptIncident(_, let id):
            return "incidents/\(id)/accept"
        case .completeIncident(_, let id, _, _):
            return "incidents/\(id)/complete"
        case .getConditionLog(_, let id):
            return "incidents/\(id)/condition-log"
        case .postConditionLog(_, let id, _, _):
            return "incidents/\(id)/condition-log"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .createIncident, .uploadPhoto:
            return .post
        case .myReports, .myRescues, .activeIncident, .nearbyActiveIncidents, .activeRescue, .pendingIncidents, .heatmap, .getConditionLog:
            return .get
        case .acceptIncident, .completeIncident:
            return .patch
        case .witnessIncident, .postConditionLog:
            return .post
        }
    }

    var headers: [String: String]? {
        switch self {
        case .uploadPhoto(let token, _):
            // Multer/Cloudinary expectation for multipart is handled by NetworkManager if we pass Data
            // But currently NetworkManager seems to only support JSON.
            // Let's check NetworkManager.swift to see how it handles Data or Multi-part.
            return [
                "Authorization": "Bearer \(token)"
            ]
        case .createIncident(let token, _, _, _, _, _, _),
            .myReports(let token),
            .myRescues(let token),
            .activeIncident(let token),
            .nearbyActiveIncidents(let token, _, _, _),
            .witnessIncident(let token, _, _),
            .activeRescue(let token),
            .pendingIncidents(let token),
            .acceptIncident(let token, _),
            .completeIncident(let token, _, _, _),
            .getConditionLog(let token, _),
            .postConditionLog(let token, _, _, _):
            return [
                "Content-Type": "application/json",
                "Authorization": "Bearer \(token)",
            ]
        case .heatmap:
            return [
                "Content-Type": "application/json",
            ]
        }
    }

    var body: Encodable? {
        switch self {
        case .createIncident(
            _, let title, let locationName, let lat, let lng, let photoUrl, let severity):
            struct IncidentPayload: Encodable {
                let title: String
                let locationName: String
                let lat: Double
                let lng: Double
                let photoUrl: String
                let severity: String

                enum CodingKeys: String, CodingKey {
                    case title
                    case locationName = "location_name"
                    case lat, lng, photoUrl, severity
                }
            }
            return IncidentPayload(
                title: title, locationName: locationName, lat: lat, lng: lng, photoUrl: photoUrl,
                severity: severity)
        case .completeIncident(_, _, let rescuePhotoUrl, let dropOffType):
            struct CompletePayload: Encodable {
                let rescuePhotoUrl: String?
                let dropOffType: String?
            }
            return CompletePayload(rescuePhotoUrl: rescuePhotoUrl, dropOffType: dropOffType)
        case .witnessIncident(_, _, let severity):
            struct WitnessPayload: Encodable {
                let severity: String
            }
            return WitnessPayload(severity: severity)
        case .postConditionLog(_, _, let stage, let note):
            struct ConditionPayload: Encodable {
                let stage: String
                let note: String?
                let photoUrl: String?
            }
            return ConditionPayload(stage: stage, note: note, photoUrl: nil)
        case .myReports, .myRescues, .activeIncident, .nearbyActiveIncidents, .heatmap,
            .activeRescue, .pendingIncidents, .acceptIncident, .uploadPhoto, .getConditionLog:
            return nil
        }
    }

    var queryItems: [URLQueryItem]? {
        switch self {
        case .nearbyActiveIncidents(_, let lat, let lng, let radius):
            return [
                URLQueryItem(name: "lat", value: String(lat)),
                URLQueryItem(name: "lng", value: String(lng)),
                URLQueryItem(name: "radius", value: String(radius)),
            ]
        case .heatmap(let limit):
            return [
                URLQueryItem(name: "limit", value: String(limit)),
            ]
        default:
            return nil
        }
    }
}
