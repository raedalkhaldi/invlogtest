import Foundation

/// API response wrapper matching backend transform interceptor
struct APIResponse<T: Decodable>: Decodable {
    let data: T
    let meta: ResponseMeta?
}

struct ResponseMeta: Decodable {
    let timestamp: String?
    let cursor: String?
    let hasMore: Bool?
    let page: Int?
    let perPage: Int?
    let totalPages: Int?
    let totalCount: Int?
}

struct ErrorResponse: Decodable {
    let statusCode: Int
    let message: String
    let error: String?
}

actor APIClient {
    static let shared = APIClient()

    private let session: URLSession
    private let baseURL: URL
    private let decoder: JSONDecoder
    private let keychainManager = KeychainManager()
    private var isRefreshing = false

    #if DEBUG
    private static let defaultBaseURL = URL(string: "http://localhost:3000/api/v1")!
    #else
    private static let defaultBaseURL = URL(string: "https://invlog-api.fly.dev/api/v1")!
    #endif

    init(
        baseURL: URL = defaultBaseURL,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.session = session

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: string) { return date }
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: string) { return date }
            // Fallback: common date formats
            let df = DateFormatter()
            df.locale = Locale(identifier: "en_US_POSIX")
            for fmt in ["yyyy-MM-dd'T'HH:mm:ss.SSSZ", "yyyy-MM-dd'T'HH:mm:ssZ", "yyyy-MM-dd"] {
                df.dateFormat = fmt
                if let date = df.date(from: string) { return date }
            }
            // Return current date instead of crashing on unexpected format
            return Date()
        }
        self.decoder = decoder
    }

    func request<T: Decodable>(
        _ endpoint: APIEndpoint,
        responseType: T.Type
    ) async throws -> T {
        var lastError: Error = APIError.unknown

        for attempt in 0..<3 {
            do {
                var urlRequest = try endpoint.urlRequest(baseURL: baseURL)
                urlRequest = addAuthHeader(to: urlRequest)

                let (data, response) = try await session.data(for: urlRequest)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw APIError.invalidResponse
                }

                // Handle 401 — try refresh once
                if httpResponse.statusCode == 401 {
                    try await refreshAccessToken()
                    var retryRequest = try endpoint.urlRequest(baseURL: baseURL)
                    retryRequest = addAuthHeader(to: retryRequest)
                    let (retryData, retryResponse) = try await session.data(for: retryRequest)

                    guard let retryHttp = retryResponse as? HTTPURLResponse else {
                        throw APIError.invalidResponse
                    }

                    guard (200...299).contains(retryHttp.statusCode) else {
                        throw parseError(statusCode: retryHttp.statusCode, data: retryData)
                    }

                    return try decoder.decode(T.self, from: retryData)
                }

                // Retry on 5xx or 429 with exponential backoff
                if ((500...599).contains(httpResponse.statusCode) || httpResponse.statusCode == 429),
                   attempt < 2 {
                    lastError = parseError(statusCode: httpResponse.statusCode, data: data)
                    try await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(attempt + 1))) * 500_000_000)
                    continue
                }

                guard (200...299).contains(httpResponse.statusCode) else {
                    throw parseError(statusCode: httpResponse.statusCode, data: data)
                }

                return try decoder.decode(T.self, from: data)
            } catch let error as APIError {
                // Don't retry client errors (except 429 handled above)
                throw error
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                // Network errors — retry with backoff
                lastError = error
                if attempt < 2 {
                    try? await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(attempt + 1))) * 500_000_000)
                    continue
                }
                throw error
            }
        }

        throw lastError
    }

    /// For endpoints that return APIResponse<T> wrapper
    func requestWrapped<T: Decodable>(
        _ endpoint: APIEndpoint,
        responseType: T.Type
    ) async throws -> (data: T, meta: ResponseMeta?) {
        let response: APIResponse<T> = try await request(endpoint, responseType: APIResponse<T>.self)
        return (data: response.data, meta: response.meta)
    }

    /// For endpoints with no response body (204, etc.)
    func requestVoid(_ endpoint: APIEndpoint) async throws {
        var lastError: Error = APIError.unknown

        for attempt in 0..<3 {
            do {
                var urlRequest = try endpoint.urlRequest(baseURL: baseURL)
                urlRequest = addAuthHeader(to: urlRequest)

                let (data, response) = try await session.data(for: urlRequest)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw APIError.invalidResponse
                }

                if httpResponse.statusCode == 401 {
                    try await refreshAccessToken()
                    var retryRequest = try endpoint.urlRequest(baseURL: baseURL)
                    retryRequest = addAuthHeader(to: retryRequest)
                    let (retryData, retryResponse) = try await session.data(for: retryRequest)
                    guard let retryHttp = retryResponse as? HTTPURLResponse,
                          (200...299).contains(retryHttp.statusCode) else {
                        throw parseError(statusCode: (retryResponse as? HTTPURLResponse)?.statusCode ?? 500, data: retryData)
                    }
                    return
                }

                // Retry on 5xx or 429
                if ((500...599).contains(httpResponse.statusCode) || httpResponse.statusCode == 429),
                   attempt < 2 {
                    lastError = parseError(statusCode: httpResponse.statusCode, data: data)
                    try? await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(attempt + 1))) * 500_000_000)
                    continue
                }

                guard (200...299).contains(httpResponse.statusCode) else {
                    throw parseError(statusCode: httpResponse.statusCode, data: data)
                }

                return
            } catch let error as APIError {
                throw error
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                lastError = error
                if attempt < 2 {
                    try? await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(attempt + 1))) * 500_000_000)
                    continue
                }
                throw error
            }
        }

        throw lastError
    }

    // MARK: - Direct Upload (for presigned S3/MinIO URLs)

    /// Upload raw data directly to a presigned URL (bypasses API base URL)
    func uploadData(_ data: Data, to url: URL, contentType: String) async throws {
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.setValue("\(data.count)", forHTTPHeaderField: "Content-Length")

        let (_, response) = try await session.upload(for: request, from: data)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 500
            throw APIError.httpError(statusCode: statusCode, message: "Upload failed")
        }
    }

    // MARK: - Private

    private func addAuthHeader(to request: URLRequest) -> URLRequest {
        var request = request
        if let token = keychainManager.getAccessToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    private func refreshAccessToken() async throws {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        guard let refreshToken = keychainManager.getRefreshToken() else {
            throw APIError.unauthorized
        }

        let endpoint = APIEndpoint.refreshToken(token: refreshToken)
        let urlRequest = try endpoint.urlRequest(baseURL: baseURL)
        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            keychainManager.clearTokens()
            throw APIError.unauthorized
        }

        struct TokenResponse: Decodable {
            let data: TokenData
            struct TokenData: Decodable {
                let accessToken: String
                let refreshToken: String
            }
        }

        let tokenResponse = try decoder.decode(TokenResponse.self, from: data)
        keychainManager.saveAccessToken(tokenResponse.data.accessToken)
        keychainManager.saveRefreshToken(tokenResponse.data.refreshToken)
    }

    private func parseError(statusCode: Int, data: Data) -> APIError {
        if let errorResponse = try? decoder.decode(ErrorResponse.self, from: data) {
            return .httpError(statusCode: statusCode, message: errorResponse.message)
        }
        return .httpError(statusCode: statusCode, message: nil)
    }
}
