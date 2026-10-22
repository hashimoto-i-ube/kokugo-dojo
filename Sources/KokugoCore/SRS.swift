import Foundation

/// 自己評価。
public enum Grade: Int, Codable, CaseIterable, Sendable {
    case again = 0, hard, good, easy

    public var title: String {
        switch self {
        case .again: return "もう一度"
        case .hard: return "あいまい"
        case .good: return "覚えた"
        case .easy: return "簡単"
        }
    }
}

/// 1 項目ぶんの記憶状態（SM-2 を簡略化したもの）。
public struct CardState: Codable, Hashable, Sendable {
    public var ease: Double = 2.5
    /// 次回までの間隔（日）
    public var interval: Double = 0
    public var due: Date = .distantPast
    public var reps: Int = 0
    public var lapses: Int = 0
    public var lastReviewed: Date?
    public var firstSeen: Date?
    public var correct: Int = 0
    public var wrong: Int = 0

    public init() {}

    /// 間隔 21 日以上を「定着」とみなす。
    public var isMature: Bool { interval >= 21 }
    public var isNew: Bool { reps == 0 && lastReviewed == nil }
}

public enum Scheduler {
    public static func review(_ s: CardState, grade: Grade, now: Date = Date()) -> CardState {
        var s = s
        if s.firstSeen == nil { s.firstSeen = now }
        s.lastReviewed = now
        switch grade {
        case .again:
            s.lapses += s.reps > 0 ? 1 : 0
            s.reps = 0
            s.interval = 0
            s.ease = max(1.3, s.ease - 0.2)
            s.wrong += 1
            // 同じセッション内で再出題されるよう 1 分後
            s.due = now.addingTimeInterval(60)
            return s
        case .hard:
            s.ease = max(1.3, s.ease - 0.15)
            s.interval = s.reps == 0 ? 1 : max(1, s.interval * 1.2)
        case .good:
            switch s.reps {
            case 0: s.interval = 1
            case 1: s.interval = 3
            default: s.interval = max(s.interval + 1, s.interval * s.ease)
            }
        case .easy:
            s.ease += 0.15
            switch s.reps {
            case 0: s.interval = 4
            default: s.interval = max(s.interval + 1, s.interval * s.ease * 1.3)
            }
        }
        s.reps += 1
        s.correct += 1
        s.interval = min(s.interval, 365)
        s.due = Calendar.current.startOfDay(for: now).addingTimeInterval(s.interval * 86_400)
        return s
    }
}
