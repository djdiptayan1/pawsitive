//
//  SOSViewModel.swift
//  pawsitive-app
//
//  Created by Diptayan Jash on 09/03/26.
//

import CoreLocation
import Foundation
import SwiftUI
import Combine

enum UrgencySeverity: String, CaseIterable {
    case severe = "Severe"
    case moderate = "Moderate"
    case minor = "Minor"

    var color: Color {
        switch self {
        case .severe: return AppConfig.Colors.alert
        case .moderate: return AppConfig.Colors.warning
        case .minor: return AppConfig.Colors.accent
        }
    }
}

@MainActor
final class SOSViewModel: ObservableObject {
    @Published var selectedSeverity: UrgencySeverity? = nil
    @Published var incidentTitle: String = ""
    @Published var isSubmitting = false
    @Published var submissionError: String? = nil
    @Published var showSuccessPopup = false
    @Published var showFirstAidGuide = false
    @Published var shouldOfferFirstAidAfterSuccess = true
    @Published var lastSubmittedSeverity: UrgencySeverity = .moderate

    private let networkManager = NetworkManager.shared

    func submitIncident(photo: UIImage?, location: CLLocationCoordinate2D?) async {
        guard !incidentTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            submissionError = "Please enter a descriptive title."
            return
        }
        guard let severity = selectedSeverity else {
            submissionError = "Please select an urgency level."
            return
        }
        guard let location = location else {
            submissionError = "Waiting for location data. Please ensure location services are enabled."
            return
        }
        guard let photo = photo, let imageData = photo.jpegData(compressionQuality: 0.8) else {
            submissionError = "Failed to capture photo."
            return
        }

        isSubmitting = true
        submissionError = nil

        do {
            // 1. Upload Photo
            let uploadUrlComponents = URLComponents(string: "\(AppConfig.ApiEndpoints.baseURL)upload/photo")!
            var uploadRequest = URLRequest(url: uploadUrlComponents.url!)
            uploadRequest.httpMethod = "POST"
            
            if let token = KeychainManager.shared.getString(key: .accessToken) {
                uploadRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }

            let boundary = UUID().uuidString
            uploadRequest.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

            var body = Data()
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"photo\"; filename=\"incident.jpg\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
            body.append(imageData)
            body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

            uploadRequest.httpBody = body

            let (uploadData, uploadResponse) = try await URLSession.shared.data(for: uploadRequest)

            guard let httpResponse = uploadResponse as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw URLError(.badServerResponse)
            }

            struct UploadResponse: Decodable {
                let url: String
            }
            let uploadResult = try JSONDecoder().decode(UploadResponse.self, from: uploadData)

            // 2. Submit Incident
            guard let token = KeychainManager.shared.getString(key: .accessToken) else {
                throw URLError(.userAuthenticationRequired)
            }

            struct IncidentResponse: Decodable {
                // Adjust based on actual backend response for POST /incidents
            }

            // Reverse Geocode to get a readable location name
            var locationName = "Unknown Location"
            let geocoder = CLGeocoder()
            let clLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)
            if let placemarks = try? await geocoder.reverseGeocodeLocation(clLocation), let placemark = placemarks.first {
                if let name = placemark.name, let city = placemark.locality {
                    locationName = "\(name), \(city)"
                } else if let name = placemark.name {
                    locationName = name
                } else if let city = placemark.locality {
                    locationName = city
                }
            }

            let _: IncidentResponse = try await NetworkManager.shared.request(
                endpoint: IncidentEndpoint.createIncident(
                    token: token,
                    title: incidentTitle,
                    locationName: locationName,
                    lat: location.latitude,
                    lng: location.longitude,
                    photoUrl: uploadResult.url,
                    severity: severity.rawValue
                )
            )

            isSubmitting = false
            lastSubmittedSeverity = severity
            showSuccessPopup = true
            showFirstAidGuide = false
            selectedSeverity = nil
            incidentTitle = ""

        } catch {
            isSubmitting = false
            submissionError = "Failed to report incident: \(error.localizedDescription)"
        }
    }
}
