//
//  networkManager.swift
//  recap
//
//  Created by Diptayan Jash on 09/03/26.
//

import Combine
import Foundation

final class NetworkManager {

    static let shared = NetworkManager()

    private init() {}

    func request<T: Decodable>(
        endpoint: Endpoint, responseType: T.Type = T.self,
        keyDecodingStrategy: JSONDecoder.KeyDecodingStrategy = .convertFromSnakeCase
    ) async throws -> T {

        var urlComponents = URLComponents(string: endpoint.baseURL + endpoint.path)
        if let queryItems = endpoint.queryItems, !queryItems.isEmpty {
            urlComponents?.queryItems = queryItems
        }

        guard let url = urlComponents?.url else {
            //            print("❌ [NetworkManager] Invalid URL: \(endpoint.baseURL + endpoint.path)")
            throw NetworkError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.allHTTPHeaderFields = endpoint.headers

        // Disable caching to always get fresh data
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")

        //        print("📡 [NetworkManager] \(endpoint.method.rawValue) \(url.absoluteString)")
        //        print("   Headers: \(request.allHTTPHeaderFields ?? [:])")

        if let body = endpoint.body {
            if let dataBody = body as? Data {
                request.httpBody = dataBody
                //                print("   Body: <Data \(dataBody.count) bytes>")
            } else {
                do {
                    request.httpBody = try JSONEncoder().encode(AnyEncodable(value: body))
                    if let bodyString = String(data: request.httpBody!, encoding: .utf8) {
                        // Truncate body for logging if it's too long (e.g., base64 images)
                        let truncated =
                            bodyString.count > 200
                            ? String(bodyString.prefix(200)) + "... (\(bodyString.count) chars)"
                            : bodyString
                        //                        print("   Body: \(truncated)")
                    }
                } catch {
                    //                    print("❌ [NetworkManager] Failed to encode body: \(error)")
                    throw NetworkError.encodingError(error)
                }
            }
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ [NetworkManager] Invalid response")
            throw NetworkError.invalidResponse
        }

        //        print("📥 [NetworkManager] Response: \(httpResponse.statusCode)")

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "No error body"
            print("❌ [NetworkManager] HTTP Error \(httpResponse.statusCode): \(errorBody)")
            throw NetworkError.httpError(statusCode: httpResponse.statusCode)
        }

        let responseString = String(data: data, encoding: .utf8) ?? "No Data"
        //        print("✅ [NetworkManager] Response body (\(data.count) bytes): \(responseString)")

        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = keyDecodingStrategy

            //            print("🔄 [NetworkManager] Decoding with strategy: \(keyDecodingStrategy)")
            let decoded = try decoder.decode(T.self, from: data)
            //            print("✅ [NetworkManager] Successfully decoded response as \(T.self)")
            return decoded
        } catch {
            print("❌ [NetworkManager] Failed to decode: \(error)")
            print("   Raw data: \(responseString)")
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .keyNotFound(let key, let context):
                    print(
                        "   Missing key: \(key.stringValue) at path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))"
                    )
                case .typeMismatch(let type, let context):
                    print(
                        "   Type mismatch for type: \(type) at path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))"
                    )
                case .valueNotFound(let type, let context):
                    print(
                        "   Value not found for type: \(type) at path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))"
                    )
                case .dataCorrupted(let context):
                    print(
                        "   Data corrupted at path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))"
                    )
                @unknown default:
                    print("   Unknown decoding error")
                }
            }
            throw NetworkError.decodingError(error)
        }
    }
}

struct AnyEncodable: Encodable {
    let value: Encodable

    func encode(to encoder: Encoder) throws {
        try value.encode(to: encoder)
    }
}
