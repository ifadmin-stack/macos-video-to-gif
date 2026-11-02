import SwiftUI

struct ControlPanel: View {
    @State private var selectedTab = Tab.export

    private enum Tab: Hashable {
        case export
        case captions
        case preview
    }

    var body: some View {
        VStack(spacing: 12) {
            Picker("功能", selection: $selectedTab) {
                Text("导出").tag(Tab.export)
                Text("文字").tag(Tab.captions)
                Text("GIF 预览").tag(Tab.preview)
            }
            .pickerStyle(.segmented)

            switch selectedTab {
            case .export:
                ExportPanel()
            case .captions:
                CaptionPanel()
            case .preview:
                GIFPreviewPanel()
            }
        }
        .padding()
        .frame(width: 340)
        .clipped()
    }
}
