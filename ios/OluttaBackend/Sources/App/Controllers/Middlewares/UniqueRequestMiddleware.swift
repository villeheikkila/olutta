import Crypto
import Foundation
import HTTPTypes
import Hummingbird
import HummingbirdRedis
import RediStack

public struct UniqueRequestMiddleware<Context: RequestContext>: RouterMiddleware {
    private let persist: RedisPersistDriver

    public init(persist: RedisPersistDriver) {
        self.persist = persist
    }

    public func handle(_ request: Request, context: Context, next: (Request, Context) async throws -> Response) async throws -> Response {
        guard let requestId = request.headers[.requestId] else {
            context.logger.error("missing request ID header")
            throw HTTPError(.badRequest, message: "missing request ID")
        }
        do {
            let timestamp = Date().timeIntervalSince1970
            try await persist.create(key: createKey(requestId), value: timestamp)
            return try await next(request, context)
        } catch let error as PersistError {
            if case .duplicate = error {
                context.logger.warning("duplicate request ID detected: \(requestId)")
                throw HTTPError(.forbidden, message: "Invalid request")
            } else {
                context.logger.error("persist error checking request ID: \(error)")
                throw HTTPError(.internalServerError, message: "unable to process request")
            }
        } catch {
            context.logger.error("error checking request ID: \(error)")
            throw HTTPError(.internalServerError, message: "unable to process request")
        }
    }

    private func createKey(_ requestId: String) -> String {
        "request_id:\(requestId)"
    }
}
