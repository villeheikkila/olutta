import APNS
import APNSCore
import AsyncHTTPClient
import Foundation
import NIOPosix
import PostgresNIO
import ServiceLifecycle

struct APNSService: Service, Sendable {
    let apnsClient: APNSClient<JSONDecoder, JSONEncoder>
    let pg: PostgresClient
    let apnsTopic: String

    init(
        privateKey: String,
        keyIdentifier: String,
        teamIdentifier: String,
        environment: APNSEnvironment,
        apnsTopic: String,
        pg: PostgresClient,
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
        self.apnsTopic = apnsTopic
        self.pg = pg
    }

    func sendPushNotifications(pushNotificationToken: String, title: APNSAlertNotificationContent.StringValue?, subtitle: APNSAlertNotificationContent.StringValue?, body: APNSAlertNotificationContent.StringValue?) async throws {
        do {
            try await apnsClient.sendAlertNotification(
                .init(alert: .init(title: title, subtitle: subtitle, body: body), expiration: .immediately, priority: .immediately, topic: apnsTopic, payload: EmptyPayload()),
                deviceToken: pushNotificationToken,
            )
        } catch let error as APNSCore.APNSError where error.reason == .badDeviceToken {
            try await pg.withTransaction { _ in
                // try await deviceReDpository.removePushNotificationToken(tx, pushNotificationToken: pushNotificationToken)
            }
        }
    }

    func run() async throws {
        try? await gracefulShutdown()
        try await shutdown()
    }

    func shutdown() async throws {
        try await apnsClient.shutdown()
    }
}
