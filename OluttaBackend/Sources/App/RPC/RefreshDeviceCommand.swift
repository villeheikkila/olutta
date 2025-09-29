import Foundation
import Logging
import OluttaShared
import PostgresNIO

extension RefreshDeviceCommand {
    static func execute(
        logger: Logger,
        identity: UserIdentity,
        pg: PostgresClient,
        request: Request
    ) async throws -> Response {
        return try await pg.withTransaction { tx in
            try await UserRepository.updateUserDevice(
                connection: tx,
                logger: logger,
                userId: identity.userId,
                deviceId: identity.deviceId,
                pushNotificationToken: request.pushNotificationToken
            )
            return Response()
        }
    }
}
