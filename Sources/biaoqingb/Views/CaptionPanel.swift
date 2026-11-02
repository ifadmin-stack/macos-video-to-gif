import SwiftUI

struct CaptionPanel: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("文字").font(.headline)
                Spacer()
                Button(action: state.addCaption) {
                    Label("添加", systemImage: "plus")
                }
                .disabled(state.videoURL == nil || state.trimDuration <= 0)
                Button(role: .destructive, action: removeSelected) {
                    Image(systemName: "trash")
                }
                .help("删除选中文字")
                .disabled(state.selectedCaptionID == nil)
            }

            List(selection: $state.selectedCaptionID) {
                ForEach(state.captions) { caption in
                    HStack {
                        Text(caption.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "（空白）" : caption.text)
                            .lineLimit(1)
                        Spacer()
                        Text("\(formatTime(caption.start))–\(formatTime(caption.end))")
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                    .font(.caption)
                    .tag(caption.id)
                }
            }
            .listStyle(.inset)
            .frame(minHeight: 100, maxHeight: 160)
            .overlay {
                if state.captions.isEmpty {
                    Text(state.videoURL == nil ? "请先导入视频" : "点击“添加”创建第一条文字")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .allowsHitTesting(false)
                }
            }

            if let selectedCaption {
                Divider()
                ScrollView {
                    CaptionEditor(caption: captionBinding(for: selectedCaption.id))
                }
            } else if !state.captions.isEmpty {
                Text("选择一条文字进行编辑")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer(minLength: 0)
        }
        .disabled(state.isProcessing)
    }

    private var selectedCaption: Caption? {
        guard let id = state.selectedCaptionID else { return nil }
        return state.captions.first { $0.id == id }
    }

    private func captionBinding(for id: Caption.ID) -> Binding<Caption> {
        Binding(
            get: { state.captions.first { $0.id == id } ?? Caption(text: "", start: 0, end: 0.1) },
            set: state.updateCaption
        )
    }

    private func removeSelected() {
        guard let id = state.selectedCaptionID else { return }
        state.removeCaption(id: id)
    }

    private func formatTime(_ time: Double) -> String {
        String(format: "%.1fs", time)
    }
}

private struct CaptionEditor: View {
    @EnvironmentObject var state: AppState
    @Binding var caption: Caption

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("内容")
                .font(.caption)
                .foregroundColor(.secondary)
            TextField("输入表情文字", text: $caption.text, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...3)

            Stepper(value: $caption.start, in: 0...max(0, state.duration), step: 0.1) {
                HStack {
                    Text("开始")
                    Spacer()
                    Text(formatTime(caption.start)).monospacedDigit()
                }
            }

            Stepper(value: $caption.end, in: 0...max(0, state.duration), step: 0.1) {
                HStack {
                    Text("结束")
                    Spacer()
                    Text(formatTime(caption.end)).monospacedDigit()
                }
            }

            Picker("位置", selection: $caption.position) {
                ForEach(CaptionPosition.allCases) { position in
                    Text(position.title).tag(position)
                }
            }
            .pickerStyle(.segmented)

            HStack {
                Text("字号")
                Slider(value: $caption.fontSize, in: 12...96, step: 1)
                Text("\(Int(caption.fontSize))")
                    .monospacedDigit()
                    .frame(width: 28, alignment: .trailing)
            }

            Picker("颜色", selection: $caption.color) {
                ForEach(CaptionColor.allCases) { color in
                    Text(color.title).tag(color)
                }
            }

            Toggle("添加描边", isOn: $caption.hasStroke)

            Text("时间以原视频为准；只有选段内的文字会进入 GIF。")
                .font(.caption2)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.bottom, 4)
    }

    private func formatTime(_ time: Double) -> String {
        String(format: "%.1fs", time)
    }
}
