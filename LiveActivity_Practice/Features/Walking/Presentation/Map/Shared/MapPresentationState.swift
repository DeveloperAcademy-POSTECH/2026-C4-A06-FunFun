//  MapPresentationState.swift
//  LiveActivity_Practice
//
//  Created by 현진백 on 2026/07/14.
//

import CoreLocation
import Foundation

struct MapCameraCommand: Equatable {
    enum Target: Equatable {
        case userLocation
        case route
        case coordinate(Coordinate)
    }

    let id: Int
    let target: Target
}

struct MapPresentationState: Equatable {
    let route: WalkingRoute?
    let deviationPath: [Coordinate]
    let passedRouteIndex: Int
    let currentLocation: Coordinate?
    let currentHeading: CLLocationDirection?
    let currentLocationAccuracy: CLLocationAccuracy?
    let navigationBearing: CLLocationDirection?
    let navigationAlignmentID: Int?
    let isNavigating: Bool
    let cameraCommand: MapCameraCommand?
    let showLandmarks: Bool
    let landmarkScaleThreshold: Double
    let showTurnMarkers: Bool
    let approachingThreshold: Double
    let previewDestination: PlaceSearchResult?
    var onMapTapped: ((Coordinate) -> Void)?
    var onMapViewportChanged: ((CLLocationDirection, CGPoint?) -> Void)? = nil

    static func == (lhs: MapPresentationState, rhs: MapPresentationState) -> Bool {
        lhs.route == rhs.route
        && lhs.deviationPath == rhs.deviationPath
        && lhs.passedRouteIndex == rhs.passedRouteIndex
        && lhs.currentLocation == rhs.currentLocation
        && lhs.currentHeading == rhs.currentHeading
        && lhs.currentLocationAccuracy == rhs.currentLocationAccuracy
        && lhs.navigationBearing == rhs.navigationBearing
        && lhs.navigationAlignmentID == rhs.navigationAlignmentID
        && lhs.isNavigating == rhs.isNavigating
        && lhs.cameraCommand == rhs.cameraCommand
        && lhs.showLandmarks == rhs.showLandmarks
        && lhs.landmarkScaleThreshold == rhs.landmarkScaleThreshold
        && lhs.showTurnMarkers == rhs.showTurnMarkers
        && lhs.approachingThreshold == rhs.approachingThreshold
        && lhs.previewDestination == rhs.previewDestination
    }
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
