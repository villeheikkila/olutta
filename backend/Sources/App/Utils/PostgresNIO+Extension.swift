import Foundation
@preconcurrency import PostgresNIO

extension PostgresConnection {
    @_disfavoredOverload
    func execute(_ sql: String) async throws {
        _ = try await query(sql).get()
    }

    func begin() async throws {
        try await execute("BEGIN")
    }

    func commit() async throws {
        try await execute("COMMIT")
    }

    func rollback() async throws {
        try await execute("ROLLBACK")
    }
}

extension PostgresClient {
    func ping() async throws -> Bool {
        do {
            _ = try await query("SELECT 1")
            return true
        } catch {
            return false
        }
    }
}

public extension PostgresClient {
    @discardableResult
    func withTransaction<Result>(_ closure: (PostgresConnection) async throws -> Result) async throws -> Result {
        try await withConnection { connection in
            try await connection.begin()
            do {
                let result = try await closure(connection)
                try await connection.commit()
                return result
            } catch {
                try await connection.rollback()
                throw error
            }
        }
    }
}
