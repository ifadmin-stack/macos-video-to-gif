import SwiftUI

@main
struct BiaoQingBApp: App {
    @StateObject private var state = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(state)
                .frame(minWidth: 900, minHeight: 620)
        }
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("打开视频…") { state.openVideoPanel() }
                    .keyboardShortcut("o", modifiers: .command)
            }
        }
    }
}
