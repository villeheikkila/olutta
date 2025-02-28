import Foundation
import Logging

struct Repositories {
    let alko: AlkoRepository

    init(logger: Logger) {
        alko = .init(logger: logger)
    }
}
