import ClusterMap
import ClusterMapSwiftUI
import MapKit
import OluttaShared
import SwiftUI

struct StoreMap: View {
    @Environment(AppModel.self) private var viewModel
    @State private var selectedStore: StoreEntity?
    @State private var mapSize: CGSize = .zero
    @State private var showSheet = true
    @State private var settingsDetent: PresentationDetent = .height(256)
    @State private var position: MapCameraPosition = .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 60.1699, longitude: 24.9384),
        span: MKCoordinateSpan(latitudeDelta: 0.2, longitudeDelta: 0.2)
    ))
    @State private var debounceTask: Task<Void, Never>?

    var body: some View {
        Map(position: $position) {
            ForEach(viewModel.storeAnnotations) { annotation in
                Annotation(annotation.store.name, coordinate: annotation.coordinate, anchor: .bottom) {
                    AlkoMarker()
                        .onTapGesture {
                            withAnimation {
                                selectedStore = annotation.store
                            }
                        }
                }
            }
            ForEach(viewModel.clusters) { cluster in
                Annotation("", coordinate: cluster.coordinate, anchor: .bottom) {
                    AlkoMarker(count: cluster.count)
                        .onTapGesture {
                            withAnimation {
                                position = .region(MKCoordinateRegion(
                                    center: cluster.coordinate,
                                    span: MKCoordinateSpan(
                                        latitudeDelta: (position.region?.span.latitudeDelta ?? 0.2) * 0.7,
                                        longitudeDelta: (position.region?.span.longitudeDelta ?? 0.2) * 0.7
                                    )
                                ))
                            }
                        }
                }
            }
            UserAnnotation()
        }
        .mapStyle(.standard)
        .mapControls {
            MapUserLocationButton()
            MapCompass()
            MapScaleView()
        }
        .readSize(onChange: { size in
            mapSize = size
        })
        .onMapCameraChange { context in
            debounceTask?.cancel()
            debounceTask = Task {
                try? await Task.sleep(for: .milliseconds(100))
                guard !Task.isCancelled else { return }
                await viewModel.reloadAnnotations(mapSize: mapSize, region: context.region)
            }
        }
        .onChange(of: selectedStore) { _, newValue in
            if newValue == nil {
                settingsDetent = .height(256)
            } else {
                settingsDetent = .medium
                if let store = newValue {
                    withAnimation {
                        position = .region(MKCoordinateRegion(
                            center: CLLocationCoordinate2D(
                                latitude: store.latitude - 0.003,
                                longitude: store.longitude
                            ),
                            span: MKCoordinateSpan(
                                latitudeDelta: 0.01,
                                longitudeDelta: 0.01
                            )
                        ))
                    }
                }
            }
        }
        .task {
            await viewModel.initializeClusters()
            await viewModel.reloadAnnotations(mapSize: mapSize, region: MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 60.1699, longitude: 24.9384),
                span: MKCoordinateSpan(latitudeDelta: 0.2, longitudeDelta: 0.2)
            ))
        }
        .sheet(isPresented: $showSheet) {
            StoreSheet(
                settingsDetent: $settingsDetent,
                selectedStore: $selectedStore
            )
            .presentationBackground(.ultraThinMaterial)
            .presentationDetents([.height(256), .medium, .large], selection: $settingsDetent)
            .presentationBackgroundInteraction(.enabled)
            .presentationCornerRadius(12)
            .presentationDragIndicator(.hidden)
            .interactiveDismissDisabled()
        }
    }
}
