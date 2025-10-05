import Foundation

struct SignInWithAppleTokenResponse: Codable, Sendable {
    let accessToken: String
    let expiresIn: TimeInterval
    let idToken: String?
    let refreshToken: String
    let tokenType: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case expiresIn = "expires_in"
        case idToken = "id_token"
        case refreshToken = "refresh_token"
        case tokenType = "token_type"
    }
}

struct AppleErrorResponse: Codable, Sendable {
    let error: String
}
