import Foundation
import Logging

struct Repositories {
    let alko: AlkoRepository
    let untappd: UntappdRepository
    let device: DeviceRepository

    init(logger: Logger) {
        alko = .init(logger: logger)
        untappd = .init(logger: logger)
        device = .init(logger: logger)
    }
}
