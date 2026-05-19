import SwiftUI
import Observation

@MainActor
@Observable
final class NavigationStore {
    static let shared = NavigationStore()
    var selectedTab: Int = 0
    private init() {}
}
