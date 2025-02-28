import Foundation

enum TimeoutError: Error {
    case timedOut
}

func withTimeout<T: Sendable>(seconds: Int, operation: @Sendable @escaping () async throws -> T) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await Task.sleep(for: .seconds(Double(seconds)))
            throw TimeoutError.timedOut
        }
        group.addTask {
            try await operation()
        }
        let result = try await group.next()!
        group.cancelAll()
        return result
    }
}
