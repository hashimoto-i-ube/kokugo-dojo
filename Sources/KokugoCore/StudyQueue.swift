import Foundation

public struct QueueEntry: Hashable, Sendable, Identifiable {
    public var deck: Deck
    public var item: StudyItem
    public var id: String { item.id }

    public init(deck: Deck, item: StudyItem) {
        self.deck = deck
        self.item = item
    }
}

public enum StudyQueue {
    /// 復習期限の来た項目（期限の古い順）と、未学習項目（レベルの低い順）を組み合わせる。
    public static func build(from pairs: [(Deck, StudyItem)], progress: ProgressStore,
                             newLimit: Int, reviewLimit: Int = 200, now: Date = Date()) -> [QueueEntry] {
        var due: [(QueueEntry, Date)] = []
        var fresh: [QueueEntry] = []
        for (d, it) in pairs {
            let s = progress.state(for: it.id)
            if s.isNew {
                fresh.append(QueueEntry(deck: d, item: it))
            } else if s.due <= now {
                due.append((QueueEntry(deck: d, item: it), s.due))
            }
        }
        let reviews = due.sorted { $0.1 < $1.1 }.prefix(reviewLimit).map(\.0)
        // 同レベル内はシャッフルして偏りを防ぐ
        let news = Dictionary(grouping: fresh, by: { $0.item.level })
            .sorted { $0.key < $1.key }
            .flatMap { $0.value.shuffled() }
            .prefix(newLimit)
        return interleave(Array(reviews), Array(news))
    }

    /// 復習 3 問に新出 1 問の割合で混ぜる
    static func interleave(_ a: [QueueEntry], _ b: [QueueEntry]) -> [QueueEntry] {
        var out: [QueueEntry] = []
        var i = 0, j = 0
        while i < a.count || j < b.count {
            for _ in 0..<3 where i < a.count { out.append(a[i]); i += 1 }
            if j < b.count { out.append(b[j]); j += 1 }
        }
        return out
    }

    /// 4 択の選択肢を作る。作成者指定の誤答を優先し、足りなければ同じデッキの他の答えから補う。
    public static func choices(for item: StudyItem, in deck: Deck, count: Int = 4) -> [String] {
        var wrong = (item.distractors ?? []).filter { $0 != item.answer }
        if wrong.count < count - 1 {
            let pool = deck.items
                .filter { $0.id != item.id && $0.answer != item.answer && !wrong.contains($0.answer) }
                .sorted { abs($0.level.rawValue - item.level.rawValue) < abs($1.level.rawValue - item.level.rawValue) }
            // 長さが近いものを優先して紛らわしくする
            let target = item.answer.count
            let candidates = pool.prefix(40).sorted { abs($0.answer.count - target) < abs($1.answer.count - target) }
            for c in candidates.prefix(12).shuffled() where wrong.count < count - 1 {
                if !wrong.contains(c.answer) { wrong.append(c.answer) }
            }
        }
        return (Array(wrong.shuffled().prefix(count - 1)) + [item.answer]).shuffled()
    }
}
