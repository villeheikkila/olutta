import Foundation
import PostgresNIO

func buildQueue(context: Context) async throws -> QueueManager<Context> {
    let queueManager = QueueManager(
        context: context,
        poolConfig: .init(
            maxConcurrentJobs: 3,
            pollInterval: 1
        )
    )
    let jobs: [QueueConfiguration<Context>] = [
        alkoQueue,
    ]
    for config in jobs {
        await queueManager.registerQueue(
            name: config.name,
            policy: config.policy,
            handler: config.handler
        )
    }
    return queueManager
}
