import Crypto
import Foundation
import HTTPTypes

public enum SignatureError: Error, Equatable {
    case encodingFailure(String)
    case missingSignature
    case missingBodyHash
    case invalidBodyHash
    case invalidSignature
}

public extension HTTPField.Name {
    static let requestSignature = Self("X-Request-Signature")!
    static let bodyHash = Self("X-Body-Hash")!
    static let requestId = Self("X-Request-ID")!
}

public struct SignatureService: Sendable {
    private let symmetricKey: SymmetricKey

    public init(secretKey: String) {
        symmetricKey = SymmetricKey(data: secretKey.data(using: .utf8)!)
    }

    public func verifySignature(
        method: HTTPRequest.Method,
        scheme: String?,
        authority: String?,
        path: String,
        headers: HTTPFields,
        body: Data,
    ) throws(SignatureError) {
        guard let signatureHeader = headers[.requestSignature] else {
            throw .missingSignature
        }
        if !body.isEmpty {
            let computedBodyHash = computeBodyHash(data: body)
            guard let providedBodyHash = headers[.bodyHash] else {
                throw .missingBodyHash
            }
            guard computedBodyHash == providedBodyHash else {
                throw .invalidBodyHash
            }
        }
        let computedSignature = try createSignature(
            method: method,
            scheme: scheme,
            authority: authority,
            path: path,
            headers: headers,
        )
        guard computedSignature == signatureHeader else {
            throw .invalidSignature
        }
    }

    public func computeBodyHash(data: Data) -> String {
        let hash = SHA256.hash(data: data)
        return Data(hash).base64EncodedString()
    }

    public func createSignature(
        method: HTTPRequest.Method,
        scheme: String?,
        authority: String?,
        path: String,
        headers: HTTPFields,
    ) throws(SignatureError) -> String {
        var signatureComponents = [String]()
        signatureComponents.append(method.rawValue)
        if let scheme {
            signatureComponents.append(scheme)
        }
        if let authority {
            signatureComponents.append(authority)
        }
        signatureComponents.append(path)
        let includedHeaders: Set<HTTPField.Name> = [
            .requestId,
            .bodyHash,
        ]
        let sortedHeaders = headers
            .filter { includedHeaders.contains($0.name) }
            .sorted { $0.name.canonicalName < $1.name.canonicalName }
        for field in sortedHeaders {
            signatureComponents.append("\(field.name.canonicalName):\(field.value)")
        }
        let stringToSign = signatureComponents.joined(separator: "-").trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = stringToSign.data(using: .utf8) else {
            throw .encodingFailure("failed to encode signature string as utf-8")
        }
        let signature = HMAC<SHA256>.authenticationCode(for: data, using: symmetricKey)
        return Data(signature).base64EncodedString()
    }
}
