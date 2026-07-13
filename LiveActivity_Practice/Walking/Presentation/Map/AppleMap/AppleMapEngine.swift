import SwiftUI

struct AppleMapEngine: WalkingMapEngine {
    func makeMapView(state: MapPresentationState) -> some View {
        AppleMapRouteView(state: state)
    }
}
