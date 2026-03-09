//
//  AuthEndpoint.swift
//  pawsitive-app
//
//  Created by Diptayan Jash on 09/03/26.
//

import Foundation
import Combine

enum AuthEndpoint: Endpoint {
    case getProfile(token: String)
    case uploadAvatar(token: String, base64: String)
    case updateProfile(token: String, fullName: String, role: String)

    var path: String {
        switch self {
        case .getProfile:
            return "auth/me"
        case .uploadAvatar:
            return "auth/avatar"
        case .updateProfile:
            return "auth/profile"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .getProfile:
            return .get
        case .uploadAvatar, .updateProfile:
            return .post
        }
    }

    var headers: [String: String]? {
        switch self {
        case .getProfile(let token),
             .uploadAvatar(let token, _),
             .updateProfile(let token, _, _):
            print("🔑 [AuthEndpoint] Adding Authorization header with token: \(token.prefix(20))...")
            return [
                "Content-Type": "application/json",
                "Authorization": "Bearer \(token)"
            ]
        }
    }

    var body: Encodable? {
        switch self {
        case .getProfile:
            return nil
        case .uploadAvatar(token: _, base64: let base64):
            print("🖼️ [AuthEndpoint] Uploading avatar. Base64 length: \(base64.count)")
            return ["avatarBase64": base64] as [String: String]
        case .updateProfile(token: _, fullName: let fullName, role: let role):
            print("👤 [AuthEndpoint] Updating profile: \(fullName), role: \(role)")
            return ["fullName": fullName, "role": role] as [String: String]
        }
    }
}
