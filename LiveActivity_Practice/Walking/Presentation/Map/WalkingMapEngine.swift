import SwiftUI

@MainActor
protocol WalkingMapEngine {
    associatedtype MapContent: View

    @ViewBuilder
    func makeMapView(state: MapPresentationState) -> MapContent
}
