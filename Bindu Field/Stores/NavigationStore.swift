import SwiftUI
import Observation

@MainActor
@Observable
final class NavigationStore {
    static let shared = NavigationStore()
    /// Default to Field (tag 1). Map sits at tag 0 as the front-door
    /// surface on first launch (the post-Birth sequence lands users in
    /// Field for ongoing use).
    var selectedTab: Int = 1
    private init() {}
}
