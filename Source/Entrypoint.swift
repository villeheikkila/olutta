import OSLog
import SwiftUI

@main
struct Entrypoint: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var appModel: AppModel

    init() {
        let rpcClient = RPCClient(
            baseURL: URL(string: "http://localhost:3000")!,
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
                    await appModel.initialize()
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
}

struct ContentView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        switch appModel.authManager.authStatus {
        case .loading:
            ProgressView()
        case .authenticated:
            StoreMap()
        case .unauthenticated:
            IntroPage()
        }
    }
}
