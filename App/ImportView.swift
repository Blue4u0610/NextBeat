import SwiftUI
import UIKit

struct ImportView: View {
    @EnvironmentObject private var model: NextBeatModel
    @State private var json = ""
    @State private var candidate: WeekPlan?
    @State private var issue: String?
    @State private var saved = false
    @FocusState private var isEditingJSON: Bool

    private enum ImportAction { case preview, apply }

    var body: some View {
        ScrollViewReader { proxy in
            importForm
                .onChange(of: candidate) { _, plan in
                    if plan != nil {
                        withAnimation { proxy.scrollTo("import-preview", anchor: .top) }
                    }
                }
                .onChange(of: saved) { _, didSave in
                    if didSave {
                        withAnimation { proxy.scrollTo("import-top", anchor: .top) }
                    }
                }
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("导入计划")
        #if DEBUG
        .onAppear {
            if let fixture = ProcessInfo.processInfo.environment["NEXTBEAT_UI_TEST_JSON"] {
                setJSON(fixture)
            }
            if let clipboard = ProcessInfo.processInfo.environment["NEXTBEAT_UI_TEST_CLIPBOARD"] {
                UIPasteboard.general.string = clipboard
            }
        }
        #endif
    }

    private var importForm: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("粘贴一周计划")
                        .font(.title2.bold())
                    Text("复制完整的七天 JSON，先预览确认，或直接应用。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .id("import-top")
                VStack(alignment: .leading, spacing: 10) {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 10) { pasteButtons }
                        VStack(spacing: 10) { pasteButtons }
                    }
                    .controlSize(.large)
                    .tint(NextBeatPalette.accent)
                    Text("直接应用也会完整验证；同一周的旧计划将被整周替换。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let issue {
                    Label(issue, systemImage: "exclamationmark.triangle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                        .accessibilityIdentifier("import-error")
                }
                if saved {
                    Label("已保存；已请求桌面小组件刷新。", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(NextBeatPalette.accent)
                        .accessibilityIdentifier("import-success")
                }

                HStack {
                    Text("计划内容")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Button("填入示例") {
                        setJSON((try? PlanValidator.export(PreviewFixtures.week)) ?? "")
                    }
                    .font(.subheadline)
                }
                TextEditor(text: Binding(get: { json }, set: { setJSON($0) }))
                    .font(.footnote.monospaced())
                    .focused($isEditingJSON)
                    .frame(height: 250)
                    .padding(7)
                    .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 15))
                    .accessibilityLabel("周计划 JSON")

                Button {
                    processJSON(.preview)
                } label: {
                    Label("验证并预览", systemImage: "checkmark.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(NextBeatPalette.accent)
                .disabled(json.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if let candidate { preview(candidate).id("import-preview") }
            }
            .padding(20)
            .frame(maxWidth: 650)
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private var pasteButtons: some View {
        Button {
            paste(.preview)
        } label: {
            Label("粘贴并预览", systemImage: "doc.text.magnifyingglass")
                .font(.subheadline.weight(.semibold))
                .fixedSize(horizontal: true, vertical: false)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .accessibilityHint("读取剪贴板并验证，预览后由你确认保存")

        Button {
            paste(.apply)
        } label: {
            Label("粘贴并应用", systemImage: "checkmark.circle")
                .font(.subheadline.weight(.semibold))
                .fixedSize(horizontal: true, vertical: false)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .accessibilityHint("读取剪贴板，通过完整验证后立即保存并替换同一周的旧计划")
    }

    private func resetFeedback() {
        candidate = nil
        issue = nil
        saved = false
    }

    private func setJSON(_ text: String) {
        resetFeedback()
        json = text
    }

    private func paste(_ action: ImportAction) {
        isEditingJSON = false
        resetFeedback()
        guard let pasted = UIPasteboard.general.string,
              !pasted.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            issue = "剪贴板中没有可读取的文本，未修改任何计划。请先复制完整的七天 JSON，或在输入框中长按粘贴。"
            return
        }
        setJSON(pasted)
        processJSON(action)
    }

    private func processJSON(_ action: ImportAction) {
        isEditingJSON = false
        resetFeedback()
        do {
            let plan = try PlanValidator.decode(json)
            switch action {
            case .preview:
                candidate = plan
            case .apply:
                try model.save(plan)
                saved = true
            }
        } catch {
            issue = error.localizedDescription
        }
    }

    private func preview(_ plan: WeekPlan) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("预览 · \(plan.weekStart)")
                .font(.headline)
            Text("时区：\(plan.timezone)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if model.plans.contains(where: { $0.weekStart == plan.weekStart }) {
                Text("保存后会整周替换此周的旧计划。")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.orange)
            }
            ForEach(plan.days, id: \.date) { day in
                VStack(alignment: .leading, spacing: 5) {
                    Text("\(day.date) · \(day.items.count) 项")
                        .font(.subheadline.weight(.semibold))
                    ForEach(day.items.indices, id: \.self) { index in
                        let item = day.items[index]
                        Text("\(item.start)–\(item.end)  \(item.title)")
                            .font(.footnote)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 5)
                Divider()
            }
            Button {
                do {
                    try model.save(plan)
                    candidate = nil
                    issue = nil
                    saved = true
                } catch {
                    issue = error.localizedDescription
                }
            } label: {
                Text("确认保存这一周")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(NextBeatPalette.accent)
        }
        .padding(18)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
    }
}

#Preview("导入") {
    NavigationStack { ImportView() }
        .environmentObject(NextBeatModel(previewPlans: []))
}

#Preview("导入 · 深色大字") {
    NavigationStack { ImportView() }
        .environmentObject(NextBeatModel(previewPlans: []))
        .preferredColorScheme(.dark)
        .environment(\.dynamicTypeSize, .accessibility1)
}
