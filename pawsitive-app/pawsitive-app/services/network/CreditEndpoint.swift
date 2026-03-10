//
//  CreditEndpoint.swift
//  pawsitive-app
//
//  Created by Diptayan Jash on 10/03/26.
//

import Foundation

enum CreditEndpoint: Endpoint {
    case creditHistory(token: String, limit: Int)

    var path: String {
        switch self {
        case .creditHistory:
            return "credits/history"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .creditHistory:
            return .get
        }
    }

    var headers: [String: String]? {
        switch self {
        case .creditHistory(let token, _):
            return [
                "Content-Type": "application/json",
                "Authorization": "Bearer \(token)",
            ]
        }
    }

    var body: Encodable? {
        return nil
    }

    var queryItems: [URLQueryItem]? {
        switch self {
        case .creditHistory(_, let limit):
            return [
                URLQueryItem(name: "limit", value: String(limit))
            ]
        }
    }
}
