//
//  TokenService.swift
//  realtime-api
//

import Foundation

struct TokenRequest: Codable {
    let voice: String
}

struct TokenResponse: Codable {
    let token: String
    let endpoint: String
}

enum TokenServiceError: LocalizedError {
    case invalidURL(String)
    case networkError(underlying: Error, url: URL)
    case invalidResponse
    case serverError(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .invalidURL(let urlString):
            return "Invalid backend URL: \(urlString)"
        case .networkError(let underlying, let url):
            return "Couldn’t reach backend at \(url.host ?? url.absoluteString). Is it running? (\(underlying.localizedDescription))"
        case .invalidResponse:
            return "Invalid response from backend"
        case .serverError(let statusCode, let message):
            return "Backend error (HTTP \(statusCode)): \(message)"
        }
    }
}

class TokenService {
    private let backendURL: String

    init(backendURL: String = TokenService.defaultBackendURL) {
        self.backendURL = backendURL
    }

    private static var defaultBackendURL: String {
        if let envValue = ProcessInfo.processInfo.environment["BACKEND_URL"], !envValue.isEmpty {
            return envValue
        }

        if let plistValue = Bundle.main.object(forInfoDictionaryKey: "BACKEND_URL") as? String, !plistValue.isEmpty {
            return plistValue
        }

#if targetEnvironment(simulator)
        return "http://127.0.0.1:8000"
#else
        return "http://localhost:8000"
#endif
    }

    func fetchToken(voice: String = "alloy") async throws -> TokenResponse {
        let urlString = "\(backendURL)/api/v1/token"
        guard let url = URL(string: urlString) else {
            throw TokenServiceError.invalidURL(urlString)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(TokenRequest(voice: voice))

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw TokenServiceError.invalidResponse
            }

            guard httpResponse.statusCode == 200 else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw TokenServiceError.serverError(statusCode: httpResponse.statusCode, message: errorMessage)
            }

            let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
            return tokenResponse

        } catch let error as TokenServiceError {
            throw error
        } catch {
            throw TokenServiceError.networkError(underlying: error, url: url)
        }
    }
}
