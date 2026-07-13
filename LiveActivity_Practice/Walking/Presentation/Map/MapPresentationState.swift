import CoreLocation
import Foundation

enum MapProviderKind: String, CaseIterable, Identifiable {
    case apple
    case tmap

    var id: Self { self }

    var displayName: String {
        switch self {
        case .apple: "Apple 지도"
        case .tmap: "Tmap"
        }
    }
}

struct MapCameraCommand: Equatable {
    enum Target: Equatable {
        case userLocation
        case route
    }

    let id: Int
    let target: Target
}

struct MapPresentationState: Equatable {
    let route: WalkingRoute?
    let currentLocation: Coordinate?
    let currentHeading: CLLocationDirection?
    let currentLocationAccuracy: CLLocationAccuracy?
    let cameraCommand: MapCameraCommand?
}

struct MapLandmarkSelection {
    let maneuver: WalkingManeuver
    let landmark: Landmark
}

extension WalkingRoute {
    func mapLandmarkSelections(maximumCount: Int = 10) -> [MapLandmarkSelection] {
        guard maximumCount > 0 else { return [] }
        var used = Set<String>()
        let selections = maneuvers
            .sorted { $0.routeIndex < $1.routeIndex }
            .compactMap { maneuver -> MapLandmarkSelection? in
                guard let landmark = maneuver.landmark,
                      used.insert(landmark.id).inserted else { return nil }
                return MapLandmarkSelection(maneuver: maneuver, landmark: landmark)
            }

        guard selections.count > maximumCount, maximumCount > 1 else {
            return Array(selections.prefix(maximumCount))
        }
        return (0..<maximumCount).map { index in
            let position = Double(index) * Double(selections.count - 1) / Double(maximumCount - 1)
            return selections[Int(position.rounded())]
        }
    }
}
