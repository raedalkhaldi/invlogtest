import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int, message: String?)
    case decodingError(Error)
    case networkError(Error)
    case unauthorized
    case tokenExpired
    case unknown

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid server response"
        case .httpError(let statusCode, let message):
            return message ?? "Server error (\(statusCode))"
        case .decodingError:
            return "Failed to process server response"
        case .networkError(let error):
            return error.localizedDescription
        case .unauthorized:
            return "Please sign in again"
        case .tokenExpired:
            return "Session expired"
        case .unknown:
            return "An unexpected error occurred"
        }
    }
}
