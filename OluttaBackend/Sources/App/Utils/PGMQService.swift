import Foundation
import Logging
import PGMQ
import PostgresNIO
import ServiceLifecycle

public enum QueuePriority: Int, Comparable, Sendable {
    case low = 0
    case medium = 1
    case high = 2
    case critical = 3

    public static func < (lhs: QueuePriority, rhs: QueuePriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public protocol QueueContextProtocol: Sendable {
    var pgmq: PGMQ { get }
    var logger: Logger { get }
}

public typealias MessageHandler<ContextContext: QueueContextProtocol> = @Sendable (ContextContext, PGMQMessage) async throws -> Void

public struct QueueConfiguration<ContextContext: QueueContextProtocol>: Sendable {
    let name: String
    let policy: QueuePolicy
    let handler: MessageHandler<ContextContext>

    public init(
        name: String,
        policy: QueuePolicy = .init(),
        handler: @escaping MessageHandler<ContextContext>,
    ) {
        self.name = name
        self.policy = policy
        self.handler = handler
    }
}

public struct QueuePolicy: Sendable {
    let priority: QueuePriority
    let batchSize: Int
    let visibilityTimeout: Int
    let maxRetries: Int
    let retryDelay: TimeInterval
    let shouldMoveToDLQ: Bool
    let isSequential: Bool
    let maxConcurrentJobs: Int

    public init(
        priority: QueuePriority = .medium,
        batchSize: Int = 1,
        visibilityTimeout: Int = 60,
        maxRetries: Int = 1,
        retryDelay: TimeInterval = 10,
        shouldMoveToDLQ: Bool = true,
        isSequential: Bool = false,
        maxConcurrentJobs: Int = 1,
    ) {
        self.priority = priority
        self.batchSize = batchSize
        self.visibilityTimeout = visibilityTimeout
        self.maxRetries = maxRetries
        self.retryDelay = retryDelay
        self.shouldMoveToDLQ = shouldMoveToDLQ
        self.isSequential = isSequential
        self.maxConcurrentJobs = isSequential ? 1 : maxConcurrentJobs
    }
}

public struct SharedPoolConfig: Sendable {
    let maxConcurrentJobs: Int
    let pollInterval: TimeInterval

    public init(
        maxConcurrentJobs: Int = 10,
        pollInterval: TimeInterval = 1,
    ) {
        self.maxConcurrentJobs = maxConcurrentJobs
        self.pollInterval = pollInterval
    }
}

public enum QueueError: Error {
    case invalidPayload
    case invalidMessageType
    case processingFailed(String)
}

public actor PGMQService<Context: QueueContextProtocol>: Service {
    private let context: Context
    private let logger: Logger
    private let poolConfig: SharedPoolConfig
    private var queueHandlers: [String: QueueConfiguration<Context>]
    private var isRunning = false
    private var activeJobs = 0
    private var activeJobsPerQueue: [String: Int] = [:]

    init(
        context: Context,
        logger: Logger,
        poolConfig: SharedPoolConfig = .init(),
    ) {
        self.context = context
        self.logger = logger
        self.poolConfig = poolConfig
        queueHandlers = [:]
    }

    func registerQueue(_ registration: QueueConfiguration<Context>) {
        queueHandlers[registration.name] = registration
    }

    public func run() async throws {
        guard !isRunning else {
            logger.warning("attempted to start already running QueueManager")
            return
        }

        logger.info("starting QueueManager")
        isRunning = true
        try await cancelWhenGracefulShutdown {
            try await withThrowingTaskGroup(of: Void.self) { group in
                for (queueName, queueConfig) in await self.queueHandlers {
                    group.addTask {
                        try await self.processQueue(name: queueName, registration: queueConfig)
                    }
                }
                try await group.waitForAll()
            }
        }
    }

    private func processQueue(
        name queueName: String,
        registration: QueueConfiguration<Context>,
    ) async throws {
        while isRunning || !Task.isCancelled {
            do {
                let messages = try await context.pgmq.read(
                    queue: queueName,
                    vt: registration.policy.visibilityTimeout,
                    qty: registration.policy.batchSize,
                )
                guard !messages.isEmpty else {
                    try await Task.sleep(for: .seconds(poolConfig.pollInterval))
                    continue
                }
                if registration.policy.isSequential {
                    for message in messages {
                        try await processMessage(
                            message,
                            queueName: queueName,
                            policy: registration.policy,
                            handler: registration.handler,
                        )
                    }
                } else {
                    try await withThrowingTaskGroup(of: Void.self) { group in
                        for message in messages {
                            group.addTask {
                                try await self.processMessage(
                                    message,
                                    queueName: queueName,
                                    policy: registration.policy,
                                    handler: registration.handler,
                                )
                            }
                        }
                        try await group.waitForAll()
                    }
                }
            } catch {
                logger.error("Error processing queue \(queueName): \(error)")
                try await Task.sleep(for: .seconds(5))
            }
        }
    }

    private func calculateBatchSize(queueName: String, policy: QueuePolicy) -> Int {
        let queueAvailableSlots = policy.maxConcurrentJobs - activeJobsPerQueue[queueName, default: 0]
        let globalAvailableSlots = poolConfig.maxConcurrentJobs - activeJobs
        return min(policy.batchSize, queueAvailableSlots, globalAvailableSlots)
    }

    private func canProcessMore(queueName: String, policy: QueuePolicy) -> Bool {
        let queueJobs = activeJobsPerQueue[queueName, default: 0]
        return activeJobs < poolConfig.maxConcurrentJobs &&
            queueJobs < policy.maxConcurrentJobs
    }

    private func processMessage(
        _ message: PGMQMessage,
        queueName: String,
        policy: QueuePolicy,
        handler: @escaping @Sendable (Context, PGMQMessage) async throws -> Void,
    ) async throws {
        incrementActiveJobs(queueName: queueName)
        defer { decrementActiveJobs(queueName: queueName) }

        do {
            try await handler(context, message)
            _ = try await context.pgmq.archive(queue: queueName, id: message.id)
        } catch {
            await handleMessageFailure(message, error: error, queueName: queueName, policy: policy)
        }
    }

    private func incrementActiveJobs(queueName: String) {
        activeJobs += 1
        activeJobsPerQueue[queueName, default: 0] += 1
    }

    private func decrementActiveJobs(queueName: String) {
        activeJobs -= 1
        activeJobsPerQueue[queueName, default: 0] -= 1
    }

    private func handleMessageFailure(
        _ message: PGMQMessage,
        error: Error,
        queueName: String,
        policy: QueuePolicy,
    ) async {
        do {
            if message.readCount >= policy.maxRetries {
                if policy.shouldMoveToDLQ {
                    try await moveToDLQ(message, error: error, queueName: queueName)
                } else {
                    _ = try await context.pgmq.archive(queue: queueName, id: message.id)
                }
            } else {
                _ = try await context.pgmq.setVt(queue: queueName, id: message.id, vt: Int(policy.retryDelay))
            }
        } catch {
            logger.error("error handling message failure for \(message.id) from \(queueName): \(String(reflecting: error))")
        }
    }

    private func moveToDLQ(
        _ message: PGMQMessage,
        error: Error,
        queueName: String,
    ) async throws {
        let dlqName = "\(queueName)_dlq"
        _ = try await context.pgmq.send(
            queue: dlqName,
            message: DLQMessage(message: message, error: error.localizedDescription),
            delay: 0,
        )
        _ = try await context.pgmq.archive(queue: queueName, id: message.id)
    }
}

public struct DLQMessage: Sendable, Codable, PostgresEncodable {
    public static let psqlFormat: PostgresFormat = .text
    public static let psqlType: PostgresDataType = .jsonb

    let id: Int64
    let error: String

    init(message: PGMQMessage, error: String) {
        id = message.id
        self.error = error
    }

    public func encode(
        into byteBuffer: inout NIOCore.ByteBuffer,
        context: PostgresEncodingContext<some PostgresJSONEncoder>,
    ) throws {
        try context.jsonEncoder.encode(self, into: &byteBuffer)
    }
}
