//
//  UserModel.swift
//  pawsitive-app
//
//  Created by Diptayan Jash on 09/03/26.
//

import Foundation

// Full user profile model matching backend response
struct UserProfile: Codable, Identifiable {
    let id: String
    let email: String
    let fullName: String?
    let role: String
    let phone: String?
    let avatarUrl: String?
    let verifiedRescuer: Bool
    let associatedNgoId: String?
    let createdAt: String
    let updatedAt: String
    let ngo: NGO?
    let reportsFiled: Int?
    let activeReports: Int?
    let animalsHelped: Int?
    let rescuesCompleted: Int?
    let activeRescues: Int?
    let recentActivities: [RecentActivityModel]?

    // Pawsitive Credits (rescuer only)
    let totalCredits: Int?
    let tierName: String?
    let tierBadge: String?

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case fullName = "full_name"
        case role
        case phone
        case avatarUrl = "avatar_url"
        case verifiedRescuer = "verified_rescuer"
        case associatedNgoId = "associated_ngo_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case ngo
        case reportsFiled = "reports_filed"
        case activeReports = "active_reports"
        case animalsHelped = "animals_helped"
        case rescuesCompleted = "rescues_completed"
        case activeRescues = "active_rescues"
        case recentActivities = "recent_activities"
        case totalCredits = "total_credits"
        case tierName = "tier_name"
        case tierBadge = "tier_badge"
    }
}

struct RecentActivityModel: Codable, Identifiable {
    let id: String
    let title: String?
    let status: String?
    let createdAt: String?
    let severity: String?
    let photoUrl: String?
    let locationName: String?
    let lat: Double?
    let lng: Double?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case status
        case createdAt = "created_at"
        case severity
        case photoUrl = "photo_url"
        case locationName = "location_name"
        case lat
        case lng
    }
}

struct NGO: Codable {
    let name: String?
    let operatingCity: String?

    enum CodingKeys: String, CodingKey {
        case name
        case operatingCity = "operating_city"
    }
}

// API response wrapper
struct ProfileResponse: Codable {
    let user: UserProfile
}
