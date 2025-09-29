import Foundation
import Logging
import OluttaShared
import PostgresNIO

extension SubscribeToStoreCommand {
    static func execute(
        logger: Logger,
        identity: UserIdentity,
        pg: PostgresClient,
        request: Request
    ) async throws -> Response {
        return try await pg.withTransaction { tx in
            try await UserRepository.addPushNotificationSubscription(
                connection: tx,
                deviceId: identity.deviceId,
                storeId: request.storeId,
                logger: logger
            )
            return Response()
        }
    }
}
