import SwiftUI

@main
struct MileNoteApp: App {
    @StateObject private var store = GarageStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
        }
    }
}
