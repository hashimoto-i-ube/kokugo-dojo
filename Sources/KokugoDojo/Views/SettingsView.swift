import SwiftUI
import AppKit
import UniformTypeIdentifiers
import KokugoCore

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @AppStorage(SettingsKey.vertical) private var vertical = true
    @AppStorage(SettingsKey.fontSize) private var fontSize = 22.0
    @AppStorage(SettingsKey.newPerDay) private var newPerDay = 20
    @AppStorage(SettingsKey.levelMin) private var levelMin = 1
    @AppStorage(SettingsKey.levelMax) private var levelMax = 5
    @AppStorage(SettingsKey.autoUpdate) private var autoUpdate = true
    @AppStorage(SettingsKey.contentURL) private var contentURL = AppInfo.defaultContentURL
    @AppStorage(SettingsKey.dataDirectory) private var dataDirectory = ""
    @State private var confirmReset = false

    var body: some View {
        TabView {
            Form {
                Toggle("縦書きで表示する", isOn: $vertical)
                LabeledContent("文字の大きさ") {
                    Slider(value: $fontSize, in: 14...36, step: 1) { Text("") }
                    Text("\(Int(fontSize))pt").monospacedDigit().frame(width: 44)
                }
                Stepper("1日の新出問題数: \(newPerDay)", value: $newPerDay, in: 0...200, step: 5)
                Picker("出題レベル（下限）", selection: $levelMin) {
                    ForEach(Level.allCases) { Text($0.title).tag($0.rawValue) }
                }
                Picker("出題レベル（上限）", selection: $levelMax) {
                    ForEach(Level.allCases) { Text($0.title).tag($0.rawValue) }
                }
            }
            .tabItem { Label("学習", systemImage: "book") }

            Form {
                Toggle("起動時に更新を確認する", isOn: $autoUpdate)
                TextField("コンテンツ配信URL", text: $contentURL)
                HStack {
                    Button("今すぐ確認") { Task { await model.checkForUpdates(userInitiated: true) } }
                        .disabled(model.isUpdating)
                    Button("既定のURLに戻す") { contentURL = AppInfo.defaultContentURL }
                    Button("同梱コンテンツに戻す", role: .destructive) { model.removeDownloadedContent() }
                }
                if let s = model.updateStatus { Text(s).font(.caption).foregroundStyle(.secondary) }
                LabeledContent("アプリのバージョン", value: AppInfo.version)
                ForEach(model.library.packs) { p in
                    LabeledContent(p.title, value: "v\(p.version)（\(p.itemCount)問）")
                }
            }
            .tabItem { Label("更新", systemImage: "arrow.triangle.2.circlepath") }

            Form {
                LabeledContent("保存先", value: model.dataDirectory.path)
                HStack {
                    Button("保存先を変更…") { chooseDirectory() }
                    Button("既定に戻す") { dataDirectory = "" }
                }
                Text("保存先の変更は再起動後に反映されます。現在の記録は「書き出す」で移してください。")
                    .font(.caption).foregroundStyle(.secondary)
                HStack {
                    Button("学習記録を書き出す…") { exportProgress() }
                    Button("学習記録を読み込む…") { importProgress() }
                }
                Button("学習記録をリセット", role: .destructive) { confirmReset = true }
                    .confirmationDialog("すべての学習記録を消去しますか？", isPresented: $confirmReset) {
                        Button("消去", role: .destructive) { model.progress.reset(); model.revision += 1 }
                    }
            }
            .tabItem { Label("データ", systemImage: "externaldrive") }
        }
        .padding(20)
        .frame(width: 560)
    }

    private func chooseDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        if panel.runModal() == .OK, let url = panel.url {
            dataDirectory = url.appendingPathComponent("KokugoDojo").path
        }
    }

    private func exportProgress() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "kokugo-progress.json"
        panel.allowedContentTypes = [.json]
        if panel.runModal() == .OK, let url = panel.url { try? model.progress.export(to: url) }
    }

    private func importProgress() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        if panel.runModal() == .OK, let url = panel.url {
            try? model.progress.importData(from: url)
            model.revision += 1
        }
    }
}
