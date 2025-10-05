import OSLog
import SwiftUI

@main
struct Entrypoint: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var appModel: AppModel

    init() {
        let rpcClient = RPCClient(
            baseURL: URL(string: "http://127.0.0.1:3000")!,
            secretKey: "a1b2c3d4e5f6g7h8i9j0k",
            rpcPath: "/v1/rpc",
        )
        let keychain = Keychain(service: Bundle.main.bundleIdentifier!)
        _appModel = State(initialValue: AppModel(
            rpcClient: rpcClient,
            keychain: keychain,
        ))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appModel)
                .task {
                    await appModel.initializeAuthManager()
                }
        }
    }
}

struct ContentView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        switch appModel.status {
        case .loading:
            ProgressView()
        case .unauthenticated:
            IntroPage()
        case .ready:
            AuthenticatedState()
        case let .error(error):
            Text(error.localizedDescription)
        }
    }
}

struct AuthenticatedState: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        StoreMap()
            .task {
                await appModel.intializeAppData()
            }
            .onReceive(
                for: .pushNotificationTokenObtained,
                subject: PushNotificationManager.shared,
            ) { message in
                Task {
                    await appModel.updatePushNotificationToken(message.token)
                }
            }
    }
}
