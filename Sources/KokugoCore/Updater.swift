import Foundation
import CryptoKit

/// コンテンツとアプリ本体の更新を確認する。
///
/// コンテンツ: `<contentBaseURL>/manifest.json` を取得し、手元より新しいパックを
/// ダウンロードしてチェックサムを検証したうえで `downloadDirectory` に保存する。
/// アプリ本体: GitHub Releases の最新タグと現在のバージョンを比較する。
public struct Updater: Sendable {
    public var contentBaseURL: URL
    public var releasesAPI: URL?
    public var downloadDirectory: URL
    public var appVersion: String

    public init(contentBaseURL: URL, releasesAPI: URL?, downloadDirectory: URL, appVersion: String) {
        self.contentBaseURL = contentBaseURL
        self.releasesAPI = releasesAPI
        self.downloadDirectory = downloadDirectory
        self.appVersion = appVersion
    }

    public struct ContentResult: Sendable {
        public var updated: [String]
        public var skipped: [String]
        public var manifest: ContentManifest
    }

    public struct AppRelease: Sendable {
        public var version: String
        public var url: URL
        public var notes: String
    }

    public func updateContent(current: [ContentPack]) async throws -> ContentResult {
        let manifestURL = contentBaseURL.appendingPathComponent("manifest.json")
        let manifest = try JSONDecoder().decode(ContentManifest.self, from: try await fetch(manifestURL))
        var updated: [String] = []
        var skipped: [String] = []
        if compareVersions(appVersion, manifest.minAppVersion) == .orderedAscending {
            return ContentResult(updated: [], skipped: manifest.packs.map(\.id), manifest: manifest)
        }
        try FileManager.default.createDirectory(at: downloadDirectory, withIntermediateDirectories: true)
        let versions = Dictionary(current.map { ($0.id, $0.version) }, uniquingKeysWith: { a, _ in a })
        for entry in manifest.packs {
            if let have = versions[entry.id], compareVersions(have, entry.version) != .orderedAscending {
                continue
            }
            let data = try await fetch(contentBaseURL.appendingPathComponent(entry.file))
            let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
            guard digest == entry.sha256 else { throw ContentError.checksumMismatch(entry.file) }
            do {
                _ = try ContentLibrary.decodePack(data)
            } catch {
                skipped.append(entry.id)
                continue
            }
            let name = (entry.file as NSString).lastPathComponent
            try data.write(to: downloadDirectory.appendingPathComponent(name), options: .atomic)
            updated.append(entry.id)
        }
        return ContentResult(updated: updated, skipped: skipped, manifest: manifest)
    }

    /// 新しいリリースがあれば返す
    public func checkAppRelease() async throws -> AppRelease? {
        guard let api = releasesAPI else { return nil }
        struct Release: Decodable { let tag_name: String; let html_url: URL; let body: String? }
        let r = try JSONDecoder().decode(Release.self, from: try await fetch(api))
        let latest = r.tag_name.hasPrefix("v") ? String(r.tag_name.dropFirst()) : r.tag_name
        guard compareVersions(appVersion, latest) == .orderedAscending else { return nil }
        return AppRelease(version: latest, url: r.html_url, notes: r.body ?? "")
    }

    private func fetch(_ url: URL) async throws -> Data {
        var req = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
        req.setValue("KokugoDojo/\(appVersion)", forHTTPHeaderField: "User-Agent")
        let (data, resp) = try await URLSession.shared.data(for: req)
        if let http = resp as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw ContentError.badResponse("\(http.statusCode) \(url.lastPathComponent)")
        }
        return data
    }
}
