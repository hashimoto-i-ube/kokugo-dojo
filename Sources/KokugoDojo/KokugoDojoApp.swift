import SwiftUI
import AppKit
import KokugoCore

@main
struct KokugoDojoApp: App {
    @State private var model = AppModel()
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        WindowGroup("国語道場") {
            RootView()
                .environment(model)
                .frame(minWidth: 960, minHeight: 640)
                .task {
                    if UserDefaults.standard.bool(forKey: SettingsKey.autoUpdate) {
                        await model.checkForUpdates(userInitiated: false)
                    }
                }
        }
        .commands {
            CommandGroup(after: .appInfo) {
                Button("アップデートを確認…") {
                    Task { await model.checkForUpdates(userInitiated: true) }
                }
            }
        }

        Settings {
            SettingsView()
                .environment(model)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // swift run で起動したときも通常のアプリとして前面に出す
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
