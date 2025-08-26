import OSLog

extension Logger {
    init(label: String) {
        self.init(subsystem: "Olutta", category: label)
    }
}
