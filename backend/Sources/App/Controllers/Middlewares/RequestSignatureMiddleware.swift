import Crypto
import Foundation
import HTTPTypes
import Hummingbird
import NIOCore
import NIOHTTPTypes

extension HTTPField.Name {
    static let requestSignature = Self("X-Request-Signature")!
}

public struct RequestSignatureMiddleware<Context: RequestContext>: RouterMiddleware {
    private let secretKey: String

    public init(secretKey: String) {
        self.secretKey = secretKey
    }

    public func handle(_ request: Request, context: Context, next: (Request, Context) async throws -> Response) async throws -> Response {
        guard let signatureHeader = request.headers[.requestSignature] else { throw HTTPError(.badRequest, message: "unknown") }
        let urlString = request.uri.string
        guard let urlData = urlString.data(using: .utf8) else {
            throw HTTPError(.internalServerError, message: "failed to encode url")
        }
        let key = SymmetricKey(data: secretKey.data(using: .utf8)!)
        let signature = HMAC<SHA256>.authenticationCode(for: urlData, using: key)
        let expectedSignature = Data(signature).base64EncodedString()
        guard signatureHeader == expectedSignature else {
            throw HTTPError(.unauthorized, message: "invalid signature")
        }
        return try await next(request, context)
    }
}
