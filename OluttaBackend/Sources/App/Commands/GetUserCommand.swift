import Foundation
import Hummingbird
import Logging
import OluttaShared
import PostgresNIO

extension GetUserCommand: AuthenticatedCommandExecutable {
    static func execute(
        logger: Logger,
        identity: UserIdentity,
        deps: CommandDependencies,
        request _: Request,
    ) async throws -> Response {
        try await deps.pg.withConnection { tx in
            let user = try await UserRepository.getUser(connection: tx, logger: logger, userId: identity.userId)
            guard let user else { throw HTTPError(.notFound) }
            return Response(
                subscriptions: user.subscriptions.map { .init(storeId: $0.storeId) },
            )
        }
    }
}
