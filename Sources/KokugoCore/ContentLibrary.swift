import Foundation

/// 同梱パックとダウンロード済みパックを読み込み、パック ID ごとに新しい方を採用する。
public struct ContentLibrary: Sendable {
    public var packs: [ContentPack]
    /// 読み込めなかったファイルとその理由
    public var problems: [String]

    public init(packs: [ContentPack] = [], problems: [String] = []) {
        self.packs = packs
        self.problems = problems
    }

    public static func load(directories: [URL]) -> ContentLibrary {
        var best: [String: ContentPack] = [:]
        var problems: [String] = []
        let fm = FileManager.default
        for dir in directories {
            guard let files = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { continue }
            for file in files where file.pathExtension == "json" && file.lastPathComponent != "manifest.json" {
                do {
                    let pack = try decodePack(Data(contentsOf: file))
                    if let current = best[pack.id],
                       compareVersions(current.version, pack.version) != .orderedAscending {
                        continue
                    }
                    best[pack.id] = pack
                } catch {
                    problems.append("\(file.lastPathComponent): \(error.localizedDescription)")
                }
            }
        }
        let order = Subject.allCases
        let packs = best.values.sorted {
            let a = order.firstIndex(of: $0.subject)!, b = order.firstIndex(of: $1.subject)!
            return a == b ? $0.id < $1.id : a < b
        }
        return ContentLibrary(packs: packs, problems: problems)
    }

    public static func decodePack(_ data: Data) throws -> ContentPack {
        let pack = try JSONDecoder().decode(ContentPack.self, from: data)
        guard pack.schemaVersion <= ContentPack.supportedSchema else {
            throw ContentError.unsupportedSchema(pack.schemaVersion)
        }
        return pack
    }

    public func packs(for subject: Subject) -> [ContentPack] {
        packs.filter { $0.subject == subject }
    }

    public var allDecks: [Deck] { packs.flatMap(\.decks) }

    public func deck(id: String) -> Deck? {
        allDecks.first { $0.id == id }
    }

    public func items(subject: Subject? = nil, levels: ClosedRange<Int> = 1...5) -> [(Deck, StudyItem)] {
        packs.filter { subject == nil || $0.subject == subject }
            .flatMap(\.decks)
            .flatMap { d in d.items.filter { levels.contains($0.level.rawValue) }.map { (d, $0) } }
    }
}

public enum ContentError: LocalizedError {
    case unsupportedSchema(Int)
    case checksumMismatch(String)
    case badResponse(String)

    public var errorDescription: String? {
        switch self {
        case .unsupportedSchema(let v): return "スキーマ v\(v) には未対応です（アプリの更新が必要です）"
        case .checksumMismatch(let f): return "\(f) のチェックサムが一致しません"
        case .badResponse(let s): return "サーバー応答エラー: \(s)"
        }
    }
}
