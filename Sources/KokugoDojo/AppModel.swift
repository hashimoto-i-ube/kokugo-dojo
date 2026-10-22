import Foundation
import SwiftUI
import KokugoCore

enum AppInfo {
    static let repository = "hashimoto-i-ube/kokugo-dojo"
    static let defaultContentURL = "https://raw.githubusercontent.com/\(repository)/main/content"
    static let releasesAPI = URL(string: "https://api.github.com/repos/\(repository)/releases/latest")!

    static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }
}

enum SettingsKey {
    static let vertical = "vertical"
    static let fontSize = "fontSize"
    static let newPerDay = "newPerDay"
    static let autoUpdate = "autoUpdate"
    static let contentURL = "contentURL"
    static let dataDirectory = "dataDirectory"
    static let levelMin = "levelMin"
    static let levelMax = "levelMax"
}

@MainActor
@Observable
final class AppModel {
    var library = ContentLibrary()
    let progress: ProgressStore
    /// 進捗が変わるたびに増やし、ビューの再計算を促す
    var revision = 0
    var updateStatus: String?
    var isUpdating = false
    var availableRelease: Updater.AppRelease?

    let dataDirectory: URL
    var downloadedPacksDirectory: URL { dataDirectory.appendingPathComponent("packs", isDirectory: true) }

    init() {
        UserDefaults.standard.register(defaults: [
            SettingsKey.vertical: true,
            SettingsKey.fontSize: 22.0,
            SettingsKey.newPerDay: 20,
            SettingsKey.autoUpdate: true,
            SettingsKey.contentURL: AppInfo.defaultContentURL,
            SettingsKey.levelMin: 1,
            SettingsKey.levelMax: 5,
        ])
        dataDirectory = Self.resolveDataDirectory()
        progress = ProgressStore(url: dataDirectory.appendingPathComponent("progress.json"))
        reload()
    }

    /// 既定は ~/Library/Application Support/KokugoDojo。設定で外部ボリュームにも変更可能。
    static func resolveDataDirectory() -> URL {
        if let custom = UserDefaults.standard.string(forKey: SettingsKey.dataDirectory), !custom.isEmpty {
            return URL(fileURLWithPath: custom, isDirectory: true)
        }
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("KokugoDojo", isDirectory: true)
    }

    /// アプリ同梱のパック。開発時（swift run）はリポジトリの content/packs を探す。
    static var bundledPacksDirectory: URL? {
        if let res = Bundle.main.resourceURL?.appendingPathComponent("content/packs"),
           FileManager.default.fileExists(atPath: res.path) {
            return res
        }
        var dir = Bundle.main.executableURL?.deletingLastPathComponent()
        while let d = dir, d.path != "/" {
            let candidate = d.appendingPathComponent("content/packs")
            if FileManager.default.fileExists(atPath: candidate.path) { return candidate }
            dir = d.deletingLastPathComponent()
        }
        return nil
    }

    func reload() {
        let dirs = [Self.bundledPacksDirectory, downloadedPacksDirectory].compactMap { $0 }
        library = ContentLibrary.load(directories: dirs)
        revision += 1
    }

    var levelRange: ClosedRange<Int> {
        let lo = UserDefaults.standard.integer(forKey: SettingsKey.levelMin)
        let hi = UserDefaults.standard.integer(forKey: SettingsKey.levelMax)
        let a = min(max(lo, 1), 5), b = min(max(hi, 1), 5)
        return min(a, b)...max(a, b)
    }

    // MARK: 学習

    func record(_ itemID: String, grade: Grade) {
        progress.record(itemID: itemID, grade: grade)
        revision += 1
    }

    func recordPassage(_ id: String, score: Int, total: Int) {
        progress.recordPassage(id: id, score: score, total: total)
        revision += 1
    }

    func queue(subject: Subject?, deck: Deck? = nil) -> [QueueEntry] {
        let pairs: [(Deck, StudyItem)]
        if let deck {
            pairs = deck.items.filter { levelRange.contains($0.level.rawValue) }.map { (deck, $0) }
        } else {
            pairs = library.items(subject: subject, levels: levelRange)
        }
        let newLimit = UserDefaults.standard.integer(forKey: SettingsKey.newPerDay)
        return StudyQueue.build(from: pairs, progress: progress, newLimit: max(0, newLimit - newLearnedToday(subject: subject)))
    }

    func newLearnedToday(subject: Subject?) -> Int {
        let start = Calendar.current.startOfDay(for: Date())
        let ids = Set(library.items(subject: subject).map(\.1.id))
        return progress.data.cards.filter { id, s in
            ids.contains(id) && (s.firstSeen ?? .distantPast) >= start
        }.count
    }

    struct Stats {
        var total = 0, seen = 0, mature = 0, due = 0
    }

    func stats(subject: Subject? = nil, deck: Deck? = nil, level: Level? = nil) -> Stats {
        _ = revision
        let now = Date()
        var st = Stats()
        let items: [StudyItem]
        if let deck { items = deck.items } else { items = library.items(subject: subject).map(\.1) }
        for it in items where level == nil || it.level == level {
            st.total += 1
            let s = progress.state(for: it.id)
            if !s.isNew {
                st.seen += 1
                if s.isMature { st.mature += 1 }
                if s.due <= now { st.due += 1 }
            }
        }
        return st
    }

    // MARK: 更新

    var updater: Updater {
        let raw = UserDefaults.standard.string(forKey: SettingsKey.contentURL) ?? AppInfo.defaultContentURL
        return Updater(contentBaseURL: URL(string: raw) ?? URL(string: AppInfo.defaultContentURL)!,
                       releasesAPI: AppInfo.releasesAPI,
                       downloadDirectory: downloadedPacksDirectory,
                       appVersion: AppInfo.version)
    }

    func checkForUpdates(userInitiated: Bool) async {
        guard !isUpdating else { return }
        isUpdating = true
        defer { isUpdating = false }
        updateStatus = "更新を確認中…"
        do {
            let result = try await updater.updateContent(current: library.packs)
            if !result.updated.isEmpty { reload() }
            var msg = result.updated.isEmpty ? "コンテンツは最新です" : "\(result.updated.count) 件のパックを更新しました"
            if !result.skipped.isEmpty { msg += "（\(result.skipped.count) 件はアプリ更新後に利用可能）" }
            updateStatus = msg
        } catch {
            updateStatus = userInitiated ? "コンテンツ更新に失敗: \(error.localizedDescription)" : nil
        }
        availableRelease = try? await updater.checkAppRelease()
    }

    /// ダウンロード済みパックを削除し、同梱版に戻す
    func removeDownloadedContent() {
        try? FileManager.default.removeItem(at: downloadedPacksDirectory)
        reload()
        updateStatus = "同梱コンテンツに戻しました"
    }
}
