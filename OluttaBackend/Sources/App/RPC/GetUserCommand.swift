import Foundation
import Hummingbird
import Logging
import OluttaShared
import PostgresNIO

extension GetUserCommand {
    static func execute(
        logger: Logger,
        identity: UserIdentity,
        pg: PostgresClient,
        request: Request
    ) async throws -> Response {
        return try await pg.withTransaction { tx in
            let userId = identity.deviceId
            let user = try await UserRepository.getUser(connection: tx, logger: logger, userId: userId)
            guard let user else { throw HTTPError(.notFound) }
            return Response(
                id: user.id,
                subscriptions: user.subscriptions.map { .init(storeId: $0.storeId) }
            )
        }
    }
}
