import Crypto
import Foundation
import HTTPTypes
import Hummingbird
import NIOCore
import NIOHTTPTypes
import OluttaShared

public struct RequestSignatureMiddleware<Context: RequestContext>: RouterMiddleware {
    private let signatureService: SignatureService

    public init(secretKey: String) {
        signatureService = SignatureService(secretKey: secretKey)
    }

    public func handle(_ request: Request, context: Context, next: (Request, Context) async throws -> Response) async throws -> Response {
        let buffer = try await request.body.collect(upTo: 1024 * 1024)
        let data = Data(buffer.readableBytesView)
        do {
            try signatureService.verifySignature(
                method: request.method,
                scheme: nil,
                authority: nil,
                path: request.uri.path,
                headers: request.headers,
                body: data,
            )
            return try await next(request, context)
        } catch {
            context.logger.error("signature verification failed: \(error)")
            // return a generic unauthorized error to the client
            throw HTTPError(.unauthorized, message: "invalid request signature")
        }
    }
}
