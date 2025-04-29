import OluttaShared
import SwiftUI

struct StoreSheet: View {
    @Environment(AppModel.self) private var appModel
    @Binding var settingsDetent: PresentationDetent
    @Binding var selectedStore: StoreEntity?
    @State private var searchText = ""
    @State private var isPresented = false

    var body: some View {
        NavigationStack {
            Group {
                if let store = selectedStore {
                    StoreDetailView(
                        navigationTitle: store.name,
                        storeId: store.id,
                        searchText: $searchText,
                        isPresented: $isPresented,
                        onClose: {
                            withAnimation {
                                searchText = ""
                                selectedStore = nil
                            }
                        }
                    )
                    .task {
                        await appModel.getProductsByStoreId(id: store.id)
                    }
                } else {
                    StoreListView(
                        searchText: $searchText,
                        settingsDetent: $settingsDetent,
                        selectedStore: $selectedStore
                    )
                }
            }
        }
        .onChange(of: searchText) { _, newValue in
            settingsDetent = newValue.isEmpty && !isPresented ? .height(256) : .medium
        }
    }
}

struct StoreDetailView: View {
    @State private var selectedStyle: String = "All"
    let navigationTitle: String
    let storeId: UUID
    @Environment(AppModel.self) private var appModel
    @Binding var searchText: String
    @Binding var isPresented: Bool
    let onClose: (() -> Void)?

    var beers: [ProductEntity] { appModel.productsByStore[storeId] ?? [] }

    var body: some View {
        List(beers) { beer in
            BeerRow(beer: beer)
                .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        .searchable(text: $searchText, isPresented: $isPresented)
        .animation(.smooth, value: selectedStyle)
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let onClose {
                ToolbarItem(placement: .topBarLeading) {
                    CloseButtonView(action: onClose)
                }
            }
//            ToolbarItem(placement: .topBarTrailing) {
//                Menu {
//                    Picker("Style", selection: $selectedStyle) {
//                        Text("All").tag("All")
//                        ForEach(beers.groupedBeerStyles, id: \.category) { group in
//                            Section(header: Text(group.category)) {
//                                if group.styles.count > 1, !group.styles.map(\.name).contains(group.category) {
//                                    Text("\(group.category) (\(group.categoryCount))")
//                                        .tag(group.category)
//                                }
//                                ForEach(group.styles, id: \.name) { style in
//                                    Text("\(style.name) (\(style.count))")
//                                        .tag(style.name)
//                                }
//                            }
//                        }
//                    }
//                } label: {
//                    Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
//                }
//            }
        }
    }

//    private var filteredByStyle: [BeerEntity] {
//        if selectedStyle == "All" {
//            return beers
//        }
//        if let categoryGroup = beers.groupedBeerStyles.first(where: { $0.category == selectedStyle }) {
//            return beers.filter { beer in
//                categoryGroup.styles.map(\.name).contains(beer.beerStyle)
//            }
//        }
//        return beers.filter { $0.beerStyle == selectedStyle }.sorted { $0.rating ?? 0 > $1.rating ?? 0 }
//    }
//
//    private var filteredBeers: [BeerEntity] {
//        if searchText.isEmpty {
//            return filteredByStyle
//        }
//
//        return filteredByStyle.filter { beer in
//            beer.name.localizedCaseInsensitiveContains(searchText) ||
//                beer.beerStyle.localizedCaseInsensitiveContains(searchText)
//        }
//    }
}

struct StoreListView: View {
    @Environment(AppModel.self) private var appModel
    @Binding var searchText: String
    @Binding var settingsDetent: PresentationDetent
    @Binding var selectedStore: StoreEntity?
    @State private var previousDetent: PresentationDetent?

    var body: some View {
        List {
            if searchText.isEmpty {
                NavigationLink {
                    AvailableToOrderScreen()
                        .onAppear {
                            previousDetent = settingsDetent
                            if settingsDetent != .large {
                                withAnimation {
                                    settingsDetent = .large
                                }
                            }
                        }
                        .onDisappear {
                            if let previousDetent {
                                withAnimation {
                                    settingsDetent = previousDetent
                                }
                            }
                        }
                } label: {
                    HStack {
                        Text("Available to Order")
                            .font(.headline)
                            .foregroundColor(.primary)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 8)
                }
                .listRowBackground(Color.clear)
            } else {
                ForEach(filteredStores) { store in
                    StoreRow(store: store)
                        .listRowBackground(Color.clear)
                        .onTapGesture {
                            withAnimation {
                                selectedStore = store
                            }
                        }
                }
            }
        }
        .listStyle(.plain)
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("Stores")
    }

    private var filteredStores: [StoreEntity] {
        if searchText.isEmpty {
            return []
        }
        return appModel.stores.filter { store in
            store.name.localizedCaseInsensitiveContains(searchText)
        }
    }
}

struct AvailableToOrderScreen: View {
    @Environment(AppModel.self) private var appModel
    @State private var searchText = ""
    @State private var isPresented = false

    var body: some View {
        StoreDetailView(
            navigationTitle: "Available to Order",
            storeId: UUID(),
            searchText: $searchText,
            isPresented: $isPresented,
            onClose: nil
        )
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(BackgroundClearView())
    }
}

struct BackgroundClearView: UIViewRepresentable {
    func makeUIView(context _: Context) -> UIView {
        let view = UIView()
        DispatchQueue.main.async {
            view.superview?.superview?.backgroundColor = .clear
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootViewController = window.rootViewController
            {
                findNavigationController(in: rootViewController)?.navigationBar.setBackgroundImage(UIImage(), for: .default)
                findNavigationController(in: rootViewController)?.navigationBar.shadowImage = UIImage()
                findNavigationController(in: rootViewController)?.navigationBar.isTranslucent = true
            }
        }
        return view
    }

    func updateUIView(_: UIView, context _: Context) {}

    private func findNavigationController(in viewController: UIViewController) -> UINavigationController? {
        if let navigationController = viewController as? UINavigationController {
            return navigationController
        }

        for child in viewController.children {
            if let found = findNavigationController(in: child) {
                return found
            }
        }

        return nil
    }
}

struct StoreRow: View {
    let store: StoreEntity

    var body: some View {
        VStack(alignment: .leading) {
            Text(store.name)
                .font(.headline)
            Text(store.city)
                .font(.subheadline)
                .foregroundColor(.gray)
        }
    }
}
