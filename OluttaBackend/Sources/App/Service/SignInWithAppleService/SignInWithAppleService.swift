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
    private let encoder: JSONEncoder

    let appIdentifier: String
    let authenticationMethod: AuthenticationMethod

    init(
        logger: Logger = Logger(label: "AppleService"),
        httpClient: HTTPClient,
        appIdentifier: String,
        authenticationMethod: AuthenticationMethod
    ) {
        self.logger = logger
        self.httpClient = httpClient
        self.appIdentifier = appIdentifier
        self.authenticationMethod = authenticationMethod
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        self.decoder = decoder
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        self.encoder = encoder
    }

    enum AuthenticationMethod: Sendable {
        case jwt(
            pemString: String,
            keyIdentifier: String,
            teamIdentifier: String
        )

        func generateClientSecret(for clientId: String) async throws -> String {
            switch self {
            case let .jwt(pemString, keyIdentifier, teamIdentifier):
                let authToken = AppleAuthToken(
                    clientId: clientId,
                    teamId: teamIdentifier
                )
                let keys = JWTKeyCollection()
                let ecdsaKey = try ES256PrivateKey(pem: pemString)
                await keys.add(ecdsa: ecdsaKey, kid: JWKIdentifier(string: keyIdentifier))
                return try await keys.sign(authToken, kid: JWKIdentifier(string: keyIdentifier))
            }
        }
    }

    func sendTokenRequest(type: GrantType) async throws -> SignInWithAppleTokenResponse {
        // request
        var request = HTTPClientRequest(url: "https://appleid.apple.com/auth/token")
        request.method = .POST
        request.headers.add(name: "Content-Type", value: "application/x-www-form-urlencoded")
        // client secret
        let clientSecret = try await authenticationMethod.generateClientSecret(for: appIdentifier)
        // form data
        var formItems: [(String, String)] = []
        formItems.append(("client_id", appIdentifier))
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
        let appleKeys = try await getPublicKeys()
        let appleJWTKeys = JWTKeyCollection()
        try await appleJWTKeys.add(jwks: appleKeys)
        let payload = try await appleJWTKeys.verify(idToken, as: AppleIdentityToken.self)
        // nonce
        guard let nonceData = nonce.data(using: .utf8) else {
            throw SignInWithAppleServiceError.invalidNonce
        }
        let hashedNonce = SHA256.hash(data: nonceData)
        let hashedNonceString = hashedNonce.compactMap {
            String(format: "%02x", $0)
        }.joined()
        guard payload.nonce == hashedNonceString else {
            throw SignInWithAppleServiceError.invalidNonce
        }
        // audience
        try payload.aud.verifyIntendedAudience(includes: appIdentifier)
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
            case .authorizationCode: return "authorization_code"
            case .refreshToken: return "refresh_token"
            }
        }
    }
}

enum SignInWithAppleServiceError: Error, CustomStringConvertible {
    case invalidNonce
    case invalidIssuer
    case failedToFetchPublicKeys
    case appleError(String)
    case unexpectedResponse
    case failedToEncodeRequest

    var description: String {
        switch self {
        case .invalidNonce:
            return "The nonce in the identity token does not match the expected nonce"
        case .invalidIssuer:
            return "The issuer of the identity token is not Apple"
        case .failedToFetchPublicKeys:
            return "Failed to fetch Apple's public keys"
        case let .appleError(error):
            return "Apple returned an error: \(error)"
        case .unexpectedResponse:
            return "Unexpected response from Apple"
        case .failedToEncodeRequest:
            return "Failed to encode the token request"
        }
    }
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
        self.iss = IssuerClaim(value: teamId)
        self.iat = IssuedAtClaim(value: Date())
        self.exp = ExpirationClaim(value: Date().addingTimeInterval(15777000))
        self.aud = AudienceClaim(value: "https://appleid.apple.com")
        self.sub = SubjectClaim(value: clientId)
    }

    func verify(using _: some JWTAlgorithm) throws {
        try exp.verifyNotExpired()
    }
}
