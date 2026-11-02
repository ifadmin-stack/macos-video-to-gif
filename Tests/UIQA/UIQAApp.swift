import SwiftUI

/// 独立 QA 应用入口：复用生产界面，通过启动参数载入明确的测试视频。
@main
struct UIQAApp: App {
    @StateObject private var state = AppState()

    var body: some Scene {
        WindowGroup {
            QAContentView()
                .environmentObject(state)
                .frame(minWidth: 900, minHeight: 620)
        }
        .windowResizability(.contentMinSize)
    }
}

private struct QAContentView: View {
    @EnvironmentObject var state: AppState
    @State private var didLoadTestVideo = false

    var body: some View {
        ContentView()
            .onAppear {
                guard !didLoadTestVideo else { return }
                didLoadTestVideo = true
                let arguments = CommandLine.arguments
                guard let flagIndex = arguments.firstIndex(of: "--qa-video"),
                      arguments.indices.contains(flagIndex + 1) else {
                    return
                }
                state.loadVideo(URL(fileURLWithPath: arguments[flagIndex + 1]))
            }
    }
}
