import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject var state: AppState
    @State private var isDropTargeted = false

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 12) {
                if state.videoURL == nil {
                    dropZone
                } else {
                    ZStack {
                        PlayerView(player: state.player)
                        if state.cropEnabled {
                            CropOverlay()
                        }
                    }
                    .background(Color.black)
                    .cornerRadius(8)
                    .frame(minHeight: 300)

                    HStack {
                        Button(action: state.playSelection) {
                            Label("预览选段", systemImage: "play.fill")
                        }
                        Button(action: state.pause) {
                            Label("暂停", systemImage: "pause.fill")
                        }

                        // 裁剪开关
                        Toggle(isOn: Binding(
                            get: { state.cropEnabled },
                            set: { on in
                                state.cropEnabled = on
                                if on && state.cropRect == CGRect(x: 0, y: 0, width: 1, height: 1) {
                                    // 默认选中中间 80%，引导用户调整
                                    state.cropRect = CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.8)
                                }
                            }
                        )) {
                            Label("裁剪", systemImage: "crop")
                        }
                        .toggleStyle(.button)

                        Spacer()
                        Button("更换视频…") { state.openVideoPanel() }
                        Button(role: .destructive, action: state.clearVideo) {
                            Label("清空", systemImage: "trash")
                        }
                    }

                    TrimTimelineView()
                }
            }
            .padding()

            Divider()

            ControlPanel()
        }
        // 整个窗口都接受拖入视频（已加载时可拖入新视频替换）
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted, perform: handleDrop)
        .overlay {
            if isDropTargeted {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 3, dash: [10]))
                    .padding(8)
                    .allowsHitTesting(false)
            }
        }
        .alert("出错了", isPresented: Binding(
            get: { state.errorMessage != nil },
            set: { if !$0 { state.errorMessage = nil } }
        )) {
            Button("好") { state.errorMessage = nil }
        } message: {
            Text(state.errorMessage ?? "")
        }
        .frame(minWidth: 900, minHeight: 600)
    }

    /// 解析 Finder 拖来的文件 URL（兼容 Data / URL 两种返回形式）
    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first(where: {
            $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
        }) else { return false }

        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            var url: URL?
            if let data = item as? Data {
                url = URL(dataRepresentation: data, relativeTo: nil)
            } else if let u = item as? URL {
                url = u
            }
            guard let url else { return }
            DispatchQueue.main.async {
                if VideoFormat.isSupported(url) {
                    state.loadVideo(url)
                } else {
                    state.errorMessage = "不支持的视频格式：\(url.pathExtension)"
                }
            }
        }
        return true
    }

    private var dropZone: some View {
        VStack(spacing: 16) {
            Image(systemName: "film.stack")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("把视频拖到这里，或")
                .foregroundColor(.secondary)
            Button("选择视频…") { state.openVideoPanel() }
                .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8]))
                .foregroundColor(isDropTargeted ? .accentColor : .secondary.opacity(0.5))
        )
    }
}
