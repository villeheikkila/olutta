import Foundation
import Logging

struct Repositories {
    let alko: AlkoRepository
    let untappd: UntappdRepository

    init(logger: Logger) {
        alko = .init()
        untappd = .init()
    }
}
