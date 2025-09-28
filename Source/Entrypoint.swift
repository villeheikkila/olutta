import OSLog
import SwiftUI

@main
struct Entrypoint: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var appModel = AppModel(httpClient: .init(
        baseURL: URL(string: "https://73259ff8b11b.ngrok-free.app")!,
        secretKey: "a1b2c3d4e5f6g7h8i9j0k",
    ), keychain: Keychain(service: Bundle.main.bundleIdentifier!))

    var body: some Scene {
        WindowGroup {
            LoadingWrapper {
                StoreMap()
            }
            .environment(appModel)
            .onReceive(for: .pushNotificationTokenObtained, subject: PushNotificationManager.shared) { message in Task {
                appModel.refreshPushNotificationToken(pushNotificationToken: message.token)
            }
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
