import Foundation
import Logging
import OluttaShared
import PostgresNIO

extension UnsubscribeFromStoreCommand: AuthenticatedCommandExecutable {
    static func execute(
        logger: Logger,
        identity: UserIdentity,
        pg: PostgresClient,
        request: Request,
    ) async throws -> Response {
        try await pg.withTransaction { tx in
            try await UserRepository.removePushNotificationSubscription(
                connection: tx,
                deviceId: request.deviceId,
                storeId: request.storeId,
                userId: identity.userId,
                logger: logger,
            )
            return Response()
        }
    }
}
