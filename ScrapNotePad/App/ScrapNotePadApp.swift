import SwiftUI

@main
struct ScrapNotePadApp: App {
    @StateObject private var store = NotebookStore()

    var body: some Scene {
        WindowGroup {
            RootSplitView()
                .environmentObject(store)
        }
    }
}
