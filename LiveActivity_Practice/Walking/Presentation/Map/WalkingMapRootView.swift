import SwiftUI

struct WalkingMapRootView: View {
    @AppStorage("selectedMapProvider") private var selectedMapProviderRawValue = MapProviderKind.tmap.rawValue

    private var selectedMapProvider: MapProviderKind {
        MapProviderKind(rawValue: selectedMapProviderRawValue) ?? .tmap
    }

    var body: some View {
        WalkingNavigationView(
            selectedMapProvider: Binding(
                get: { selectedMapProvider },
                set: { selectedMapProviderRawValue = $0.rawValue }
            )
        )
    }
}
