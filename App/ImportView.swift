import SwiftUI
import UIKit

struct ImportView: View {
    @EnvironmentObject private var model: NextBeatModel
    @State private var json = ""
    @State private var candidate: WeekPlan?
    @State private var issue: String?
    @State private var saved = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("粘贴一周计划")
                        .font(.title2.bold())
                    Text("从周一到周日恰好七天；没有事项的日期请填写空 items。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Button {
                        if let pasted = UIPasteboard.general.string, !pasted.isEmpty {
                            json = pasted
                        } else {
                            issue = "剪贴板中没有可读取的文本。请在输入框中长按并选择“粘贴”。"
                        }
                    } label: {
                        Label("从剪贴板粘贴", systemImage: "doc.on.clipboard")
                    }
                    Spacer()
                    Button("填入示例") { json = (try? PlanValidator.export(PreviewFixtures.week)) ?? "" }
                }
                .buttonStyle(.bordered)
                TextEditor(text: $json)
                    .font(.footnote.monospaced())
                    .frame(minHeight: 250)
                    .padding(7)
                    .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 15))
                    .accessibilityLabel("周计划 JSON")

                Button {
                    do {
                        candidate = try PlanValidator.decode(json)
                        issue = nil
                        saved = false
                    } catch {
                        candidate = nil
                        issue = error.localizedDescription
                    }
                } label: {
                    Label("验证并预览", systemImage: "checkmark.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(NextBeatPalette.accent)
                .disabled(json.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if let issue {
                    Label(issue, systemImage: "exclamationmark.triangle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                }
                if let candidate { preview(candidate) }
                if saved {
                    Label("已保存；已请求桌面小组件刷新。", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(NextBeatPalette.accent)
                }
            }
            .padding(20)
            .frame(maxWidth: 650)
            .frame(maxWidth: .infinity)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("导入计划")
        #if DEBUG
        .onAppear {
            if let fixture = ProcessInfo.processInfo.environment["NEXTBEAT_UI_TEST_JSON"] {
                json = fixture
            }
        }
        #endif
        .onChange(of: json) { _, _ in
            candidate = nil
            issue = nil
            saved = false
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
