import ClusterMap
import MapKit
import SwiftUI

@main
struct Entrypoint: App {
    @State private var appModel = AppModel(httpClient: .init(
        baseURL: URL(string: "http://localhost:3000")!,
        secretKey: "a1b2c3d4e5f6g7h8i9j0k"
    ))
    @State private var timer: Timer? = nil

    var body: some Scene {
        WindowGroup {
            LoadingWrapper {
                StoreMap()
            }
            .environment(appModel)
            .task {
                await appModel.initialize()
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
        if appModel.isLoading {
            ProgressView()
        } else {
            content()
        }
    }
}
