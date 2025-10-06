import CoreLocation
import OluttaShared

extension Store.Entity {
    var location: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
