import AsyncHTTPClient
import Crypto
import Foundation
import HTTPTypes
import JWTKit
import Logging

struct SignInWithAppleService: Sendable {
    private let logger: Logger
    private let httpClient: HTTPClient
    private let decoder: JSONDecoder

    let bundleIdentifier: String
    let clientSecret: String

    init(
        logger: Logger = Logger(label: "SignInWithAppleService"),
        httpClient: HTTPClient,
        decoder: JSONDecoder,
        bundleIdentifier: String,
        teamIdentifier: String,
        privateKeyId: String,
        privateKey: String,
    ) async throws {
        self.logger = logger
        self.httpClient = httpClient
        self.bundleIdentifier = bundleIdentifier
        self.decoder = decoder
        // create client secret
        let authToken = AppleAuthToken(
            clientId: bundleIdentifier,
            teamId: teamIdentifier,
        )
        let keys = JWTKeyCollection()
        let ecdsaKey = try ES256PrivateKey(pem: privateKey)
        await keys.add(ecdsa: ecdsaKey, kid: JWKIdentifier(string: privateKeyId))
        clientSecret = try await keys.sign(authToken, kid: JWKIdentifier(string: privateKeyId))
    }

    func sendTokenRequest(type: GrantType) async throws -> SignInWithAppleTokenResponse {
        // request
        var request = HTTPClientRequest(url: "https://appleid.apple.com/auth/token")
        request.method = .POST
        request.headers.add(name: "Content-Type", value: "application/x-www-form-urlencoded")
        // form data
        var formItems: [(String, String)] = []
        formItems.append(("client_id", bundleIdentifier))
        formItems.append(("client_secret", clientSecret))
        formItems.append(("grant_type", type: type.grantType))
        if case let .authorizationCode(code) = type {
            formItems.append(("code", code))
        }
        if case let .refreshToken(refreshToken) = type {
            formItems.append(("refresh_token", refreshToken))
        }
        let formString = formItems
            .map { key, value in
                guard let encodedKey = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                      let encodedValue = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
                else {
                    return ""
                }
                return "\(encodedKey)=\(encodedValue)"
            }
            .joined(separator: "&")
        guard let data = formString.data(using: .utf8) else {
            throw SignInWithAppleServiceError.failedToEncodeRequest
        }
        request.body = .bytes(data)
        // response
        let response = try await httpClient.execute(request, timeout: .seconds(30))
        let body = try await response.body.collect(upTo: 1024 * 1024)
        if response.status != .ok {
            if let errorResponse = try? decoder.decode(AppleErrorResponse.self, from: body) {
                throw SignInWithAppleServiceError.appleError(errorResponse.error)
            }
            throw SignInWithAppleServiceError.unexpectedResponse
        }
        return try decoder.decode(SignInWithAppleTokenResponse.self, from: body)
    }

    @discardableResult
    func verifyIdToken(idToken: String, nonce: String) async throws -> AppleIdentityToken {
        // obtain apple public key
        let appleKeys = try await getPublicKeys()
        let appleJWTKeys = JWTKeyCollection()
        try await appleJWTKeys.add(jwks: appleKeys)
        // verify jwt
        let payload = try await appleJWTKeys.verify(idToken, as: AppleIdentityToken.self)
        // nonce
        guard let nonceData = nonce.data(using: .utf8) else {
            throw SignInWithAppleServiceError.invalidNonce
        }
        // apple returns hashed nonce, hash for comparison
        let hashedNonce = SHA256.hash(data: nonceData)
        let hashedNonceString = hashedNonce.compactMap {
            String(format: "%02x", $0)
        }.joined()
        guard payload.nonce == hashedNonceString else {
            throw SignInWithAppleServiceError.invalidNonce
        }
        // audience
        try payload.aud.verifyIntendedAudience(includes: bundleIdentifier)
        // issuer
        guard payload.iss.value == "https://appleid.apple.com" else {
            throw SignInWithAppleServiceError.invalidIssuer
        }
        // expiration
        try payload.exp.verifyNotExpired()
        return payload
    }

    private func getPublicKeys() async throws -> JWKS {
        let request = HTTPClientRequest(url: "https://appleid.apple.com/auth/keys")
        let response = try await httpClient.execute(request, timeout: .seconds(30))
        guard response.status == .ok else {
            logger.error("failed to fetch apple public keys", metadata: ["status": "\(response.status)"])
            throw SignInWithAppleServiceError.failedToFetchPublicKeys
        }
        let body = try await response.body.collect(upTo: 1024 * 1024)
        let keys = try decoder.decode(JWKS.self, from: body)
        return keys
    }

    enum GrantType {
        case authorizationCode(code: String)
        case refreshToken(refreshToken: String)

        var grantType: String {
            switch self {
            case .authorizationCode: "authorization_code"
            case .refreshToken: "refresh_token"
            }
        }
    }
}

enum SignInWithAppleServiceError: Error {
    case invalidNonce
    case invalidIssuer
    case failedToFetchPublicKeys
    case appleError(String)
    case unexpectedResponse
    case failedToEncodeRequest
}

struct AppleIdentityToken: JWTPayload, Sendable {
    let iss: IssuerClaim
    let sub: SubjectClaim
    let aud: AudienceClaim
    let iat: IssuedAtClaim
    let exp: ExpirationClaim
    let nonce: String?
    let email: String?
    let emailVerified: String?
    let isPrivateEmail: String?
    let realUserStatus: Int?
    let authTime: Int?
    let transferSub: String?

    func verify(using _: some JWTAlgorithm) throws {
        try exp.verifyNotExpired()
    }
}

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

struct AppleAuthToken: JWTPayload {
    let iss: IssuerClaim
    let iat: IssuedAtClaim
    let exp: ExpirationClaim
    let aud: AudienceClaim
    let sub: SubjectClaim

    init(clientId: String, teamId: String) {
        iss = IssuerClaim(value: teamId)
        iat = IssuedAtClaim(value: Date())
        exp = ExpirationClaim(value: Date().addingTimeInterval(15777000))
        aud = AudienceClaim(value: "https://appleid.apple.com")
        sub = SubjectClaim(value: clientId)
    }

    func verify(using _: some JWTAlgorithm) throws {
        try exp.verifyNotExpired()
    }
}
