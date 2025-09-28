import Logging

public extension Logger.Level {
    init(from string: String) {
        self = Logger.Level(rawValue: string.lowercased()) ?? .info
    }
}
