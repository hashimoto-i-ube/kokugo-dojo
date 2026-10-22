import Foundation

/// 学習レベル。1=高校入学程度 〜 5=旧帝大・医学部レベル。
public enum Level: Int, Codable, CaseIterable, Comparable, Sendable, Identifiable {
    case l1 = 1, l2, l3, l4, l5

    public var id: Int { rawValue }

    public var title: String {
        switch self {
        case .l1: return "Lv.1 高校入門"
        case .l2: return "Lv.2 高校基礎"
        case .l3: return "Lv.3 共通テスト"
        case .l4: return "Lv.4 難関大"
        case .l5: return "Lv.5 旧帝大・医学部"
        }
    }

    public var shortTitle: String { "Lv.\(rawValue)" }

    public static func < (lhs: Level, rhs: Level) -> Bool { lhs.rawValue < rhs.rawValue }
}

/// 分野。コンテンツパックはいずれかの分野に属する。
public enum Subject: String, Codable, CaseIterable, Sendable, Identifiable {
    case kanji, vocabulary, modernReading, kobunWords, kobunGrammar, kanbun, knowledge

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .kanji: return "漢字"
        case .vocabulary: return "語彙"
        case .modernReading: return "現代文読解"
        case .kobunWords: return "古文単語"
        case .kobunGrammar: return "古典文法"
        case .kanbun: return "漢文句法"
        case .knowledge: return "基礎知識・文学史"
        }
    }

    public var symbol: String {
        switch self {
        case .kanji: return "character.ja"
        case .vocabulary: return "text.book.closed"
        case .modernReading: return "doc.text"
        case .kobunWords: return "scroll"
        case .kobunGrammar: return "list.bullet.indent"
        case .kanbun: return "character.textbox.ja"
        case .knowledge: return "building.columns"
        }
    }
}

/// 表示方向の指定。auto は利用者設定に従う。
public enum WritingMode: String, Codable, Sendable {
    case vertical, horizontal, auto
}

public enum CardKind: String, Codable, Sendable {
    /// 表裏カード。クイズでは同じデッキの他の答えから選択肢を自動生成する。
    case flash
    /// 作成者が選択肢を用意した多肢選択問題。
    case choice
}

public struct StudyItem: Codable, Hashable, Sendable, Identifiable {
    public var id: String
    public var level: Level
    /// 問題文（インライン記法可。Markup 参照）
    public var prompt: String
    /// 正解
    public var answer: String
    /// 誤答の選択肢（choice のとき必須、flash では任意）
    public var distractors: [String]?
    /// 解説
    public var note: String?
    public var tags: [String]?

    public init(id: String, level: Level, prompt: String, answer: String,
                distractors: [String]? = nil, note: String? = nil, tags: [String]? = nil) {
        self.id = id
        self.level = level
        self.prompt = prompt
        self.answer = answer
        self.distractors = distractors
        self.note = note
        self.tags = tags
    }
}

public struct Deck: Codable, Hashable, Sendable, Identifiable {
    public var id: String
    public var title: String
    public var description: String?
    public var kind: CardKind
    /// 問題文の上に出す指示（例: 「傍線部の読みを答えよ」）
    public var instruction: String?
    public var writing: WritingMode?
    /// true なら問題文を漢文（訓点）として描画する
    public var kanbun: Bool?
    public var items: [StudyItem]
}

public struct Question: Codable, Hashable, Sendable, Identifiable {
    public var id: String
    public var prompt: String
    public var choices: [String]
    /// choices 中の正解の添字（0 始まり）
    public var answer: Int
    public var explanation: String?
}

/// 読解用の本文と設問。
public struct Passage: Codable, Hashable, Sendable, Identifiable {
    public var id: String
    public var title: String
    /// 評論 / 小説 / 古文 / 漢文 など
    public var genre: String
    public var level: Level
    public var source: String?
    public var kanbun: Bool?
    /// 本文（インライン記法可。段落は空行で区切る）
    public var text: String
    public var questions: [Question]
    public var commentary: String?
}

/// 解説ページ（活用表・句法一覧など）。body は HTML 断片。
public struct Lesson: Codable, Hashable, Sendable, Identifiable {
    public var id: String
    public var title: String
    public var level: Level
    public var body: String
}

public struct ContentPack: Codable, Hashable, Sendable, Identifiable {
    public static let supportedSchema = 1

    public var schemaVersion: Int
    public var id: String
    public var subject: Subject
    public var title: String
    /// 例: "2026.10.22"。数値比較で新旧を判定する。
    public var version: String
    /// 準拠する学習指導要領（例: "H30" = 平成30年告示）
    public var curriculum: String
    public var decks: [Deck]
    public var passages: [Passage]?
    public var lessons: [Lesson]?

    public var itemCount: Int {
        decks.reduce(0) { $0 + $1.items.count } + (passages?.reduce(0) { $0 + $1.questions.count } ?? 0)
    }
}

/// 配信用マニフェスト。content/manifest.json と同形式。
public struct ContentManifest: Codable, Sendable {
    public struct Entry: Codable, Sendable, Hashable {
        public var id: String
        public var file: String
        public var version: String
        public var sha256: String
        public var bytes: Int
    }

    public var schemaVersion: Int
    /// 最低限必要なアプリのバージョン。これより古いアプリは新パックを取り込まない。
    public var minAppVersion: String
    public var curriculum: String
    public var curriculumNote: String?
    public var generatedAt: String
    public var packs: [Entry]
}

/// "2026.10.22" や "1.2.0" のようなドット区切りのバージョン比較。
public func compareVersions(_ a: String, _ b: String) -> ComparisonResult {
    let pa = a.split(separator: ".").map { Int($0) ?? 0 }
    let pb = b.split(separator: ".").map { Int($0) ?? 0 }
    for i in 0..<max(pa.count, pb.count) {
        let x = i < pa.count ? pa[i] : 0
        let y = i < pb.count ? pb[i] : 0
        if x != y { return x < y ? .orderedAscending : .orderedDescending }
    }
    return .orderedSame
}
