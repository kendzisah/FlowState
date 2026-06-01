import WidgetKit
import SwiftUI

/// All five widget surfaces ship from this single extension bundle so the
/// Live Activity and home-screen widgets share the App Group, the shared
/// types in `Shared/`, and the AppIntent definitions in `AppIntents/`.
@main
struct FlowStateActivityExtensionBundle: WidgetBundle {
    var body: some Widget {
        FlowStateLiveActivity()
        LockScreenRectangularWidget()
        SmallRecommendationWidget()
        MediumTop3Widget()
        SmallParkedWidget()
    }
}
