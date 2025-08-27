import ClusterMap
import MapKit
import SwiftUI

@main
struct Entrypoint: App {
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
