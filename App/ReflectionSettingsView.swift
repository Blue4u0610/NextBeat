import SwiftUI

struct ReflectionSettingsView: View {
    @EnvironmentObject private var model: NextBeatModel
    @State private var draft = ReflectionSettings.defaultValue
    @State private var error: String?
    @State private var hasSaved = false
    @State private var hasInitialized = false

    var body: some View {
        Form {
            Section {
                Toggle("显示自省语", isOn: $draft.isEnabled)
                    .tint(NextBeatPalette.accent)
                TextField("写一句给自己的话", text: $draft.text, axis: .vertical)
                    .lineLimit(2...4)
                    .textInputAutocapitalization(.never)
                    .accessibilityLabel("自省语内容")
                Text("显示在纵向超大组件顶部。关闭后仍会保留文字，随时可以重新开启。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } header: {
                Text("桌面大组件")
            }

            Section {
                Button {
                    save()
                } label: {
                    Text("保存并更新小组件")
                        .frame(maxWidth: .infinity)
                        .fontWeight(.semibold)
                }
                .disabled(draft == model.reflectionSettings)

                if hasSaved && draft == model.reflectionSettings {
                    Label("已保存。小组件会按系统调度刷新。", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(NextBeatPalette.accent)
                        .font(.footnote)
                }
                if let error {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.footnote)
                }
            }
        }
        .navigationTitle("设置")
        .onAppear {
            if !hasInitialized {
                draft = model.reflectionSettings
                hasInitialized = true
            }
        }
        .onChange(of: draft) { _, _ in
            error = nil
        }
    }

    private func save() {
        do {
            try model.saveReflectionSettings(draft)
            draft = model.reflectionSettings
            hasSaved = true
        } catch {
            self.error = error.localizedDescription
        }
    }
}

#Preview("自省语设置") {
    NavigationStack { ReflectionSettingsView() }
        .environmentObject(NextBeatModel(previewPlans: [PreviewFixtures.week]))
}
