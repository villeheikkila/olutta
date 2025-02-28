import Foundation
import Logging
import PGMQ
import PostgresNIO

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
        handler: @escaping MessageHandler<ContextContext>
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
        maxConcurrentJobs: Int = 1
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
        pollInterval: TimeInterval = 1
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

public actor QueueManager<Context: QueueContextProtocol> {
    private let context: Context
    private let poolConfig: SharedPoolConfig
    private var queueHandlers: [String: (policy: QueuePolicy, handler: @Sendable (Context, PGMQMessage) async throws -> Void)]
    private var isRunning = false
    private var activeJobs = 0
    private var activeJobsPerQueue: [String: Int] = [:]
    private var queueTasks: [String: Task<Void, Never>] = [:]

    public init(
        context: Context,
        poolConfig: SharedPoolConfig
    ) {
        self.context = context
        self.poolConfig = poolConfig
        queueHandlers = [:]
    }

    public func registerQueue(
        name: String,
        policy: QueuePolicy,
        handler: @Sendable @escaping (Context, PGMQMessage) async throws -> Void
    ) {
        queueHandlers[name] = (policy, handler)
    }

    public func stop() async {
        isRunning = false
        for task in queueTasks.values {
            task.cancel()
        }
        queueTasks.removeAll()

        while activeJobs > 0 {
            context.logger.debug("Waiting for \(activeJobs) active jobs to complete")
            try? await Task.sleep(for: .seconds(1))
        }
        context.logger.info("QueueManager stopped")
    }

    private func canProcessMore(queueName: String, policy: QueuePolicy) -> Bool {
        let queueJobs = activeJobsPerQueue[queueName, default: 0]
        return activeJobs < poolConfig.maxConcurrentJobs &&
            queueJobs < policy.maxConcurrentJobs
    }

    public func start() {
        guard !isRunning else {
            context.logger.warning("attempted to start already running QueueManager")
            return
        }
        context.logger.info("starting QueueManager")
        isRunning = true
        for (queueName, queueConfig) in queueHandlers {
            let task = Task {
                await processQueue(
                    name: queueName,
                    policy: queueConfig.policy,
                    handler: queueConfig.handler
                )
            }
            queueTasks[queueName] = task
        }
    }

    private func processQueue(
        name queueName: String,
        policy: QueuePolicy,
        handler: @escaping MessageHandler<Context>
    ) async {
        while isRunning {
            do {
                guard canProcessMore(queueName: queueName, policy: policy) else {
                    try await Task.sleep(for: .seconds(1))
                    continue
                }
                let queueAvailableSlots = policy.maxConcurrentJobs - activeJobsPerQueue[queueName, default: 0]
                let globalAvailableSlots = poolConfig.maxConcurrentJobs - activeJobs
                let effectiveBatchSize = min(
                    policy.batchSize,
                    queueAvailableSlots,
                    globalAvailableSlots
                )
                let messages = try await context.pgmq.read(
                    queue: queueName,
                    vt: policy.visibilityTimeout,
                    qty: effectiveBatchSize
                )
                guard !messages.isEmpty else {
                    try await Task.sleep(for: .seconds(poolConfig.pollInterval))
                    continue
                }
                if policy.isSequential {
                    await processSequentially(
                        messages,
                        queueName: queueName,
                        policy: policy,
                        handler: handler
                    )
                } else {
                    await processParallel(
                        messages,
                        queueName: queueName,
                        policy: policy,
                        handler: handler
                    )
                }
            } catch {
                context.logger.error("error processing queue \(queueName): \(String(reflecting: error))")
                try? await Task.sleep(for: .seconds(5))
            }
        }
    }

    private func processSequentially(
        _ messages: [PGMQMessage],
        queueName: String,
        policy: QueuePolicy,
        handler: @escaping @Sendable (Context, PGMQMessage) async throws -> Void
    ) async {
        for message in messages {
            do {
                try await withTimeout(seconds: policy.visibilityTimeout) {
                    await self.processMessage(message, queueName: queueName, policy: policy, handler: handler)
                }
            } catch TimeoutError.timedOut {
                await handleMessageFailure(
                    message,
                    error: TimeoutError.timedOut,
                    queueName: queueName,
                    policy: policy
                )
            } catch {
                await handleMessageFailure(message, error: error, queueName: queueName, policy: policy)
            }
        }
    }

    private func processParallel(
        _ messages: [PGMQMessage],
        queueName: String,
        policy: QueuePolicy,
        handler: @escaping @Sendable (Context, PGMQMessage) async throws -> Void
    ) async {
        await withTaskGroup(of: Void.self) { group in
            for message in messages {
                group.addTask {
                    await self.processMessage(message, queueName: queueName, policy: policy, handler: handler)
                }
            }
        }
    }

    private func processMessage(_ message: PGMQMessage, queueName: String, policy: QueuePolicy, handler: @escaping @Sendable (Context, PGMQMessage) async throws -> Void) async {
        incrementActiveJobs(queueName: queueName)
        defer { decrementActiveJobs(queueName: queueName) }

        context.logger.debug("processing message \(message.id) from queue \(queueName)")
        do {
            try await handler(context, message)
            _ = try await context.pgmq.archive(queue: queueName, id: message.id)
            context.logger.debug("successfully processed and archived message \(message.id) from \(queueName)")
        } catch {
            context.logger.error("failed to process message \(message.id) from \(queueName): \(String(reflecting: error))")
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

    private func handleMessageFailure(_ message: PGMQMessage, error: Error, queueName: String, policy: QueuePolicy) async {
        do {
            if message.readCount >= policy.maxRetries {
                context.logger.warning("message \(message.id) from \(queueName) exceeded max retries (\(policy.maxRetries))")
                if policy.shouldMoveToDLQ {
                    try await moveToDLQ(message, error: error, queueName: queueName)
                    context.logger.info("moved failed message \(message.id) to DLQ for \(queueName)")
                } else {
                    _ = try await context.pgmq.archive(queue: queueName, id: message.id)
                    context.logger.info("archived failed message \(message.id) from \(queueName) without moving to DLQ")
                }
            } else {
                _ = try await context.pgmq.setVt(queue: queueName, id: message.id, vt: Int(policy.retryDelay))
                context.logger.debug("scheduled retry for message \(message.id) from \(queueName) (attempt \(message.readCount + 1))")
            }
        } catch {
            context.logger.error("error handling message failure for \(message.id) from \(queueName): \(String(reflecting: error))")
        }
    }

    private func moveToDLQ(
        _ message: PGMQMessage,
        error: Error,
        queueName: String
    ) async throws {
        let dlqName = "\(queueName)_dlq"
        _ = try await context.pgmq.send(
            queue: dlqName,
            message: DLQMessage(message: message, error: error.localizedDescription),
            delay: 0
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
        context: PostgresEncodingContext<some PostgresJSONEncoder>
    ) throws {
        try context.jsonEncoder.encode(self, into: &byteBuffer)
    }
}
