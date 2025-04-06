import CoreLocation
import OluttaShared

extension StoreEntity {
    var location: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
