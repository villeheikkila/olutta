import APNS
import APNSCore
import AsyncHTTPClient
import Foundation
import NIOPosix
import ServiceLifecycle

public struct APNSService: Service, Sendable {
    public let apnsClient: APNSClient<JSONDecoder, JSONEncoder>

    public init(
        privateKey: String,
        keyIdentifier: String,
        teamIdentifier: String,
        environment: APNSEnvironment,
    ) throws {
        apnsClient = try APNSClient(
            configuration: .init(
                authenticationMethod: .jwt(
                    privateKey: .loadFrom(string: privateKey),
                    keyIdentifier: keyIdentifier,
                    teamIdentifier: teamIdentifier,
                ),
                environment: environment,
            ),
            eventLoopGroupProvider: .shared(MultiThreadedEventLoopGroup.singleton),
            responseDecoder: JSONDecoder(),
            requestEncoder: JSONEncoder(),
        )
    }

    public func run() async throws {
        try? await gracefulShutdown()
        try await shutdown()
    }

    public func shutdown() async throws {
        try await apnsClient.shutdown()
    }
}
