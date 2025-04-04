import Crypto
import Foundation
import HTTPTypes

public enum SignatureError: Error {
    case encodingFailure(String)
    case missingSignature
    case missingBodyHash
    case invalidBodyHash
    case invalidSignature
}

public extension HTTPField.Name {
    static let requestSignature = Self("X-Request-Signature")!
    static let bodyHash = Self("X-Body-Hash")!
}

public struct SignatureService: Sendable {
    private let symmetricKey: SymmetricKey
    
    public init(secretKey: String) {
        self.symmetricKey = SymmetricKey(data: secretKey.data(using: .utf8)!)
    }
    
    public func createSignature(
        method: HTTPRequest.Method,
        path: String,
        headers: HTTPFields,
        body: Data?
    ) throws(SignatureError) -> (signature: String, bodyHash: String?) {
        var modifiedHeaders = headers
        let bodyHash: String? = if let body, !body.isEmpty {
            computeBodyHash(data: body)
        } else {
            nil
        }
        if let bodyHash {
            modifiedHeaders.append(.init(name: .bodyHash, value: bodyHash))
        }
        let signature = try createSignatureInternal(
            method: method,
            path: path,
            headers: modifiedHeaders,
            bodyHash: bodyHash
        )
        return (signature, bodyHash)
    }
    
    public func verifySignature(
        method: HTTPRequest.Method,
        path: String,
        headers: HTTPFields,
        body: Data
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
        let computedSignature = try createSignatureInternal(
            method: method,
            path: path,
            headers: headers,
            bodyHash: headers[.bodyHash]
        )
        guard computedSignature == signatureHeader else {
            throw .invalidSignature
        }
    }
    
    private func createSignatureInternal(
        method: HTTPRequest.Method,
        path: String,
        headers: HTTPFields,
        bodyHash: String?
    ) throws(SignatureError) -> String {
        var signatureComponents = [String]()
        signatureComponents.append(method.rawValue)
        signatureComponents.append(path)
        let defaultHeadersToIgnore: Set<HTTPField.Name> = [
            .accept,
            .userAgent,
            .acceptLanguage,
            .acceptEncoding,
            .connection
        ]
        
        for field in headers {
            // Skip the signature header and default iOS headers
            if field.name != .requestSignature && !defaultHeadersToIgnore.contains(field.name) {
                signatureComponents.append("\(field.name.canonicalName):\(field.value)")
            }
        }
        
        if let bodyHash {
            signatureComponents.append(bodyHash)
        }
        let stringToSign = signatureComponents.joined(separator: "\n")
        guard let data = stringToSign.data(using: .utf8) else {
            throw .encodingFailure("failed to encode signature string as utf-8")
        }
        let signature = HMAC<SHA256>.authenticationCode(for: data, using: symmetricKey)
        return Data(signature).base64EncodedString()
    }

    public func computeBodyHash(data: Data) -> String {
        let hash = SHA256.hash(data: data)
        return Data(hash).base64EncodedString()
    }
}
