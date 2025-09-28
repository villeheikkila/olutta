import AsyncHTTPClient
import Foundation
import HummingbirdRedis
import OpenAI
import PGMQ
import PostgresNIO

struct Context: QueueContextProtocol {
    let pgmq: PGMQ
    let pg: PostgresClient
    let openRouter: OpenAI
    let logger: Logger
    let alkoService: AlkoService
    let untappdService: UntappdService
    let config: Config
}
