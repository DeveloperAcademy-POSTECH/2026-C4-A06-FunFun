import SwiftUI

struct TMapEngine: WalkingMapEngine {
    func makeMapView(state: MapPresentationState) -> some View {
        TMapRouteView(state: state)
    }
}
