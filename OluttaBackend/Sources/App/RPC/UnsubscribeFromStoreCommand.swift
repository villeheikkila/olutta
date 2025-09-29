import Foundation
import Logging
import OluttaShared
import PostgresNIO

extension UnsubscribeFromStoreCommand {
    static func execute(
        logger: Logger,
        identity: UserIdentity,
        pg: PostgresClient,
        request: Request
    ) async throws -> Response {
        return try await pg.withTransaction { tx in
            try await UserRepository.removePushNotificationSubscription(
                connection: tx,
                deviceId: identity.deviceId,
                storeId: request.storeId,
                logger: logger
            )
            return Response()
        }
    }
}
