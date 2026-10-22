import Foundation

public struct PassageResult: Codable, Hashable, Sendable {
    public var attempts: Int = 0
    public var bestScore: Int = 0
    public var total: Int = 0
    public var lastAttempt: Date?
}

/// 学習記録。JSON 1 ファイルに保存する。
public struct ProgressData: Codable, Sendable {
    public var schemaVersion = 1
    public var cards: [String: CardState] = [:]
    public var passages: [String: PassageResult] = [:]
    /// "yyyy-MM-dd" → その日の回答数
    public var daily: [String: Int] = [:]

    public init() {}
}

public final class ProgressStore {
    public private(set) var data: ProgressData
    public let url: URL

    public init(url: URL) {
        self.url = url
        if let d = try? Data(contentsOf: url),
           let decoded = try? Self.decoder.decode(ProgressData.self, from: d) {
            data = decoded
        } else {
            data = ProgressData()
        }
    }

    public func state(for itemID: String) -> CardState {
        data.cards[itemID] ?? CardState()
    }

    @discardableResult
    public func record(itemID: String, grade: Grade, now: Date = Date()) -> CardState {
        let next = Scheduler.review(state(for: itemID), grade: grade, now: now)
        data.cards[itemID] = next
        data.daily[Self.dayKey(now), default: 0] += 1
        save()
        return next
    }

    public func recordPassage(id: String, score: Int, total: Int, now: Date = Date()) {
        var r = data.passages[id] ?? PassageResult()
        r.attempts += 1
        r.bestScore = max(r.bestScore, score)
        r.total = total
        r.lastAttempt = now
        data.passages[id] = r
        data.daily[Self.dayKey(now), default: 0] += total
        save()
    }

    public func reset() {
        data = ProgressData()
        save()
    }

    /// 連続学習日数（今日または昨日から遡る）
    public func streak(now: Date = Date()) -> Int {
        let cal = Calendar.current
        var day = cal.startOfDay(for: now)
        if data.daily[Self.dayKey(day)] == nil {
            day = cal.date(byAdding: .day, value: -1, to: day)!
        }
        var n = 0
        while data.daily[Self.dayKey(day), default: 0] > 0 {
            n += 1
            day = cal.date(byAdding: .day, value: -1, to: day)!
        }
        return n
    }

    public func save() {
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            try Self.encoder.encode(data).write(to: url, options: .atomic)
        } catch {
            NSLog("progress save failed: \(error)")
        }
    }

    public func export(to dest: URL) throws {
        try Self.encoder.encode(data).write(to: dest, options: .atomic)
    }

    public func importData(from src: URL) throws {
        data = try Self.decoder.decode(ProgressData.self, from: Data(contentsOf: src))
        save()
    }

    public static func dayKey(_ date: Date) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.sortedKeys]
        return e
    }()

    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}
