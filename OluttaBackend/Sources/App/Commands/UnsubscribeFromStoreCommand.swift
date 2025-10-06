import Foundation
import Logging
import OluttaShared
import PostgresNIO

extension UnsubscribeFromStoreCommand: AuthenticatedCommandExecutable {
    static func execute(
        logger: Logger,
        identity: UserIdentity,
        deps: CommandDependencies,
        request: Request,
    ) async throws -> Response {
        try await deps.pg.withTransaction { tx in
            try await UserRepository.removePushNotificationSubscription(
                connection: tx,
                deviceId: identity.deviceId,
                storeId: request.storeId,
                userId: identity.userId,
                logger: logger,
            )
            return Response()
        }
    }
}
