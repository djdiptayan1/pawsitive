import Foundation

enum IncidentEndpoint: Endpoint {
    case createIncident(token: String, title: String, locationName: String, lat: Double, lng: Double, photoUrl: String, severity: String)
    case myReports(token: String)
    case myRescues(token: String)
    case activeIncident(token: String)
    case activeRescue(token: String)
    case pendingIncidents(token: String)
    case uploadPhoto(token: String, imageData: Data)
    case acceptIncident(token: String, id: String)
    case completeIncident(token: String, id: String, rescuePhotoUrl: String?, dropOffType: String?)

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
        }
    }

    var method: HTTPMethod {
        switch self {
        case .createIncident, .uploadPhoto:
            return .post
        case .myReports, .myRescues, .activeIncident, .activeRescue, .pendingIncidents:
            return .get
        case .acceptIncident, .completeIncident:
            return .patch
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
            .activeRescue(let token),
            .pendingIncidents(let token),
            .acceptIncident(let token, _),
            .completeIncident(let token, _, _, _):
            return [
                "Content-Type": "application/json",
                "Authorization": "Bearer \(token)",
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
        case .myReports, .myRescues, .activeIncident, .activeRescue, .pendingIncidents,
            .acceptIncident, .uploadPhoto:
            return nil
        }
    }
}
