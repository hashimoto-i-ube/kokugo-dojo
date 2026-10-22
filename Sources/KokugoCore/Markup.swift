import Foundation

/// コンテンツ用のインライン記法を HTML に変換する。
///
/// - `{漢字|かんじ}`      ルビ
/// - `[[本文]]`           傍線（縦書きでは右傍線）
/// - `[[本文|ア]]`        記号付き傍線
/// - `**本文**`           傍点（圏点）
/// - `__A__`              空欄（記号入りの枠）
/// - 空行で段落、改行で行替え
///
/// 漢文モード（kanbun: true）では、加えて
/// - `字（ニ）`           送り仮名（カタカナ）
/// - `字〔レ〕`           返り点（レ・一・二・上・下・甲・乙 など。`一レ` も可）
/// - `{字|よみ}`          読みのルビ（再読文字の読みなど）
public enum Markup {
    public static func html(_ source: String, kanbun: Bool = false) -> String {
        let normalized = source.replacingOccurrences(of: "\r\n", with: "\n")
        let paragraphs = normalized.components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .newlines) }
            .filter { !$0.isEmpty }
        if paragraphs.count <= 1 {
            return inline(normalized.trimmingCharacters(in: .newlines), kanbun: kanbun)
        }
        return paragraphs.map { "<p>\(inline($0, kanbun: kanbun))</p>" }.joined()
    }

    /// 記法を取り除いたプレーンテキスト（検索・選択肢表示用）
    public static func plain(_ source: String) -> String {
        var p = Parser(Array(source), kanbun: false, plain: true)
        return p.parse(until: nil)
    }

    public static func inline(_ source: String, kanbun: Bool) -> String {
        var p = Parser(Array(source), kanbun: kanbun, plain: false)
        return p.parse(until: nil)
    }

    public static func escape(_ s: String) -> String {
        var out = ""
        out.reserveCapacity(s.count)
        for c in s {
            switch c {
            case "&": out += "&amp;"
            case "<": out += "&lt;"
            case ">": out += "&gt;"
            case "\"": out += "&quot;"
            default: out.append(c)
            }
        }
        return out
    }

    private struct Parser {
        let c: [Character]
        let kanbun: Bool
        let plain: Bool
        var i = 0

        init(_ c: [Character], kanbun: Bool, plain: Bool) {
            self.c = c
            self.kanbun = kanbun
            self.plain = plain
        }

        func peek(_ s: String, at j: Int? = nil) -> Bool {
            let start = j ?? i
            let chars = Array(s)
            guard start + chars.count <= c.count else { return false }
            for k in 0..<chars.count where c[start + k] != chars[k] { return false }
            return true
        }

        /// `open` の直後から `close` までの位置を探す（入れ子なし）
        func find(_ close: String, from j: Int) -> Int? {
            var k = j
            while k < c.count {
                if peek(close, at: k) { return k }
                k += 1
            }
            return nil
        }

        mutating func parse(until terminator: String?) -> String {
            var out = ""
            while i < c.count {
                if let t = terminator, peek(t) { return out }
                if peek("[[") {
                    i += 2
                    let inner = parse(until: "]]")
                    i = min(i + 2, c.count)
                    // 記号付き傍線 [[本文|ア]]
                    var body = inner
                    var label: String?
                    if let bar = lastTopLevelBar(in: inner) {
                        body = String(inner[..<bar])
                        label = String(inner[inner.index(after: bar)...])
                    }
                    if plain {
                        out += body
                    } else if let label {
                        out += "<span class=\"bosen\">\(body)</span><span class=\"bosen-label\">\(label)</span>"
                    } else {
                        out += "<span class=\"bosen\">\(body)</span>"
                    }
                    continue
                }
                if peek("**") {
                    i += 2
                    let inner = parse(until: "**")
                    i = min(i + 2, c.count)
                    out += plain ? inner : "<em class=\"boten\">\(inner)</em>"
                    continue
                }
                if peek("__"), let end = find("__", from: i + 2), end > i + 2 {
                    let label = String(c[(i + 2)..<end])
                    i = end + 2
                    out += plain ? "（\(label)）" : "<span class=\"blank\">\(escape(label))</span>"
                    continue
                }
                if c[i] == "{", let bar = find("|", from: i + 1), let end = find("}", from: bar + 1),
                   !c[(i + 1)..<bar].contains("}") {
                    let base = String(c[(i + 1)..<bar])
                    let ruby = String(c[(bar + 1)..<end])
                    i = end + 1
                    if plain {
                        out += base
                    } else {
                        out += "<ruby>\(escape(base))<rt>\(escape(ruby))</rt></ruby>"
                        out += kanbun ? kanbunMarks() : ""
                    }
                    continue
                }
                if c[i] == "\n" {
                    i += 1
                    out += plain ? "\n" : "<br>"
                    continue
                }
                let ch = c[i]
                i += 1
                if plain {
                    out.append(ch)
                } else if kanbun, isKanbunBase(ch) {
                    let marks = kanbunMarks()
                    if marks.isEmpty {
                        out += escape(String(ch))
                    } else {
                        out += "<span class=\"kb\">\(escape(String(ch)))\(marks)</span>"
                    }
                } else {
                    out += escape(String(ch))
                }
            }
            return out
        }

        /// 直後に続く （送り仮名） 〔返り点〕 を読み取り、HTML を返す
        mutating func kanbunMarks() -> String {
            var okuri: String?
            var kaeri: String?
            var progressed = true
            while progressed {
                progressed = false
                if okuri == nil, i < c.count, c[i] == "（", let end = find("）", from: i + 1),
                   c[(i + 1)..<end].allSatisfy(isKatakanaLike) {
                    okuri = String(c[(i + 1)..<end])
                    i = end + 1
                    progressed = true
                }
                if kaeri == nil, i < c.count, c[i] == "〔", let end = find("〕", from: i + 1) {
                    kaeri = String(c[(i + 1)..<end])
                    i = end + 1
                    progressed = true
                }
            }
            var html = ""
            if let okuri { html += "<span class=\"okuri\">\(escape(okuri))</span>" }
            if let kaeri { html += "<span class=\"kaeri\">\(escape(kaeri))</span>" }
            return html
        }

        func isKanbunBase(_ ch: Character) -> Bool {
            guard let s = ch.unicodeScalars.first else { return false }
            return (0x3400...0x9FFF).contains(s.value) || (0xF900...0xFAFF).contains(s.value)
                || ch == "々" || ch == "〇"
        }

        func isKatakanaLike(_ ch: Character) -> Bool {
            guard let s = ch.unicodeScalars.first else { return false }
            return (0x30A0...0x30FF).contains(s.value) || (0x3040...0x309F).contains(s.value)
        }

        /// ルビ等の HTML タグ内にない最後の `|`
        func lastTopLevelBar(in s: String) -> String.Index? {
            var depth = 0
            var result: String.Index?
            var idx = s.startIndex
            while idx < s.endIndex {
                let ch = s[idx]
                if ch == "<" { depth += 1 } else if ch == ">" { depth -= 1 } else if ch == "|" && depth == 0 { result = idx }
                idx = s.index(after: idx)
            }
            return result
        }
    }
}
