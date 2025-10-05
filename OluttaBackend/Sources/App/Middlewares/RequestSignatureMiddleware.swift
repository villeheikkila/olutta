import Crypto
import Foundation
import HTTPTypes
import Hummingbird
import NIOCore
import NIOHTTPTypes
import OluttaShared

public struct RequestSignatureMiddleware<Context: RequestContext>: RouterMiddleware {
    private let signatureService: SignatureService

    public init(signatureService: SignatureService) {
        self.signatureService = signatureService
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
            var newRequest = request
            newRequest.body = .init(buffer: buffer)
            return try await next(newRequest, context)
        } catch let error as SignatureError {
            context.logger.error("signature verification failed: \(error)")
            // hide error from client
            throw HTTPError(.internalServerError)
        } catch {
            context.logger.error("unexpected error: \(error)")
            throw HTTPError(.internalServerError)
        }
    }
}
