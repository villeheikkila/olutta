import OSLog
import SwiftUI

@main
struct Entrypoint: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var appModel = AppModel(httpClient: .init(
        baseURL: URL(string: "http://localhost:3000")!,
        secretKey: "a1b2c3d4e5f6g7h8i9j0k",
    ), keychain: Keychain(service: Bundle.main.bundleIdentifier!))
    @State private var timer: Timer? = nil

    var body: some Scene {
        WindowGroup {
            LoadingWrapper {
                StoreMap()
            }
            .environment(appModel)
            .onReceive(for: .pushNotificationTokenObtained, subject: PushNotificationManager.shared) { message in
                print(message.token)
            }
        }
    }
}

struct LoadingWrapper<Content: View>: View {
    @Environment(AppModel.self) private var appModel
    let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        switch appModel.status {
        case .authenticating:
            IntroPage()
        case .loading:
            ProgressView()
                .task {
                    await appModel.initialize()
                }
        case .ready:
            content()
        case .error:
            Text("fatal")
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "AppDelegate")

    func application(_ application: UIApplication, didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        application.registerForRemoteNotifications()
        return true
    }

    func application(_: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        logger.error("Failed to register for remote notifications: \(error)")
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(_: UNUserNotificationCenter,
                                            willPresent notification: UNNotification) async -> UNNotificationPresentationOptions
    {
        let userInfo = notification.request.content.userInfo
        NotificationCenter.default.post(
            name: NSNotification.Name(rawValue: "PushNotificationReceived"),
            object: nil,
            userInfo: userInfo,
        )
        return [.sound, .badge, .banner, .list]
    }

    func application(_: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data)
    {
        let deviceTokenString = deviceToken.reduce("") { $0 + String(format: "%02X", $1) }
        NotificationCenter.default.post(
            NotificationCenter.PushNotificationTokenObtained(token: deviceTokenString),
            subject: PushNotificationManager.shared,
        )
    }
}
