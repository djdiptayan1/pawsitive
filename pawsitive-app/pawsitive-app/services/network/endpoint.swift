//
//  endpoint.swift
//  recap
//
//  Created by Diptayan Jash on 09/03/26.
//

import Foundation

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
    case patch = "PATCH"
}

protocol Endpoint {
    var baseURL: String { get }
    var path: String { get }
    var method: HTTPMethod { get }
    var headers: [String: String]? { get }
    var body: Encodable? { get }
    var queryItems: [URLQueryItem]? { get }
}

extension Endpoint {
    var baseURL: String {
        return AppConfig.ApiEndpoints.baseURL
    }

    var headers: [String: String]? {
        return ["Content-Type": "application/json"]
    }

    var body: Encodable? {
        return nil
    }

    var queryItems: [URLQueryItem]? {
        return nil
    }
}

enum NetworkError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case decodingError(Error)
    case encodingError(Error)
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "The URL provided was invalid."
        case .invalidResponse: return "The server response was invalid."
        case .httpError(let code): return "Server returned an error. Status code: \(code)"
        case .decodingError(let error): return "Failed to parse data: \(error.localizedDescription)"
        case .encodingError(let error):
            return "Failed to encode body: \(error.localizedDescription)"
        case .unknown(let error): return "An unknown error occurred: \(error.localizedDescription)"
        }
    }
}
