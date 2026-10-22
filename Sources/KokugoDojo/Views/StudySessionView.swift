import SwiftUI
import KokugoCore

struct StudySessionView: View {
    @Environment(AppModel.self) private var model
    @AppStorage(SettingsKey.vertical) private var vertical = true
    @AppStorage(SettingsKey.fontSize) private var fontSize = 22.0

    var subject: Subject?
    var deckID: String?
    var mode: StudyMode

    @State private var queue: [QueueEntry] = []
    @State private var loaded = false
    @State private var index = 0
    @State private var revealed = false
    @State private var choices: [String] = []
    @State private var picked: String?
    @State private var correctCount = 0
    @State private var wrongCount = 0
    @State private var requeued: Set<String> = []

    private var title: String {
        if let deckID, let d = model.library.deck(id: deckID) { return d.title }
        return subject?.title ?? "今日の学習"
    }

    var body: some View {
        Group {
            if !loaded {
                ProgressView()
            } else if queue.isEmpty {
                ContentUnavailableView("今日の学習は完了です", systemImage: "checkmark.seal",
                                       description: Text("復習期限の来た問題も新出問題もありません。設定で1日の新出数や目標レベルを変更できます。"))
            } else if index >= queue.count {
                summary
            } else {
                card(queue[index])
            }
        }
        .navigationTitle("\(title)・\(mode.title)")
        .onAppear(perform: load)
    }

    private func load() {
        guard !loaded else { return }
        let deck = deckID.flatMap { model.library.deck(id: $0) }
        var q = model.queue(subject: subject, deck: deck)
        // テストモードでは期限に関係なく出題する（デッキ指定時）
        if q.isEmpty, mode == .quiz, let deck {
            q = deck.items.filter { model.levelRange.contains($0.level.rawValue) }.shuffled().prefix(20)
                .map { QueueEntry(deck: deck, item: $0) }
        }
        queue = q
        loaded = true
        prepare()
    }

    private func prepare() {
        revealed = false
        picked = nil
        guard index < queue.count else { return }
        let e = queue[index]
        choices = usesChoices(e) ? StudyQueue.choices(for: e.item, in: e.deck) : []
    }

    private func usesChoices(_ e: QueueEntry) -> Bool {
        mode == .quiz || e.deck.kind == .choice
    }

    // MARK: カード

    @ViewBuilder private func card(_ e: QueueEntry) -> some View {
        VStack(spacing: 0) {
            HStack {
                LevelChip(level: e.item.level)
                Text(e.deck.title).foregroundStyle(.secondary)
                Spacer()
                Text("正解 \(correctCount)・誤答 \(wrongCount)").foregroundStyle(.secondary).monospacedDigit()
                Text("\(index + 1) / \(queue.count)").monospacedDigit()
            }
            .padding(.horizontal, 20).padding(.vertical, 10)
            ProgressView(value: Double(index), total: Double(max(queue.count, 1))).padding(.horizontal, 20)

            if let ins = e.deck.instruction {
                Text(ins).font(.callout).foregroundStyle(.secondary).padding(.top, 10)
            }

            JapaneseTextView(html: Markup.html(e.item.prompt, kanbun: e.deck.kanbun ?? false),
                             vertical: vertical && e.deck.writing != .horizontal,
                             fontSize: fontSize * 1.3, centered: true, kanbun: e.deck.kanbun ?? false)
                .frame(maxWidth: .infinity, minHeight: 220, maxHeight: .infinity)
                .padding(.horizontal, 20)
                .id(e.item.id)

            Divider()
            answerArea(e)
                .padding(20)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 200)
        }
    }

    @ViewBuilder private func answerArea(_ e: QueueEntry) -> some View {
        if usesChoices(e) {
            VStack(spacing: 10) {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(Array(choices.enumerated()), id: \.offset) { i, c in
                        Button { choose(c, entry: e) } label: {
                            HStack {
                                Text("\(i + 1)").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                                Text(Markup.plain(c)).font(.system(size: fontSize * 0.8, design: .serif))
                                    .multilineTextAlignment(.leading)
                                Spacer()
                                if revealed && c == e.item.answer { Image(systemName: "checkmark.circle.fill").foregroundStyle(.green) }
                                if revealed && c == picked && c != e.item.answer { Image(systemName: "xmark.circle.fill").foregroundStyle(.red) }
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(background(for: c, entry: e), in: RoundedRectangle(cornerRadius: 8))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(revealed)
                        .keyboardShortcut(KeyEquivalent(Character("\(i + 1)")), modifiers: [])
                    }
                }
                if revealed {
                    note(e)
                    Button("次へ", action: next).keyboardShortcut(.return, modifiers: []).buttonStyle(.borderedProminent)
                }
            }
        } else if !revealed {
            Button { revealed = true } label: {
                Text("答えを見る").frame(width: 220).padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent).controlSize(.large)
            .keyboardShortcut(.space, modifiers: [])
        } else {
            VStack(spacing: 12) {
                Text(Markup.plain(e.item.answer))
                    .font(.system(size: fontSize * 1.1, weight: .semibold, design: .serif))
                    .textSelection(.enabled)
                note(e)
                HStack(spacing: 10) {
                    ForEach(Grade.allCases, id: \.self) { g in
                        Button { grade(g, entry: e) } label: {
                            VStack(spacing: 2) {
                                Text(g.title)
                                Text("\(g.rawValue + 1)").font(.caption2).foregroundStyle(.secondary)
                            }
                            .frame(width: 90)
                        }
                        .buttonStyle(.bordered)
                        .tint(g == .again ? .red : g == .hard ? .orange : g == .good ? .green : .blue)
                        .keyboardShortcut(KeyEquivalent(Character("\(g.rawValue + 1)")), modifiers: [])
                    }
                }
            }
        }
    }

    @ViewBuilder private func note(_ e: QueueEntry) -> some View {
        if let n = e.item.note, !n.isEmpty {
            Text(Markup.plain(n))
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .textSelection(.enabled)
                .frame(maxWidth: 640)
        }
    }

    private func background(for c: String, entry e: QueueEntry) -> some ShapeStyle {
        if revealed && c == e.item.answer { return AnyShapeStyle(Color.green.opacity(0.15)) }
        if revealed && c == picked { return AnyShapeStyle(Color.red.opacity(0.15)) }
        return AnyShapeStyle(.quaternary.opacity(0.6))
    }

    // MARK: 操作

    private func choose(_ c: String, entry e: QueueEntry) {
        guard !revealed else { return }
        picked = c
        revealed = true
        let ok = c == e.item.answer
        model.record(e.item.id, grade: ok ? .good : .again)
        if ok { correctCount += 1 } else { wrongCount += 1; requeue(e) }
    }

    private func grade(_ g: Grade, entry e: QueueEntry) {
        model.record(e.item.id, grade: g)
        if g == .again { wrongCount += 1; requeue(e) } else { correctCount += 1 }
        next()
    }

    /// 間違えた問題はセッションの後ろでもう一度出す（1 回まで）
    private func requeue(_ e: QueueEntry) {
        guard !requeued.contains(e.id) else { return }
        requeued.insert(e.id)
        queue.append(e)
    }

    private func next() {
        index += 1
        prepare()
    }

    private var summary: some View {
        VStack(spacing: 16) {
            Image(systemName: "flag.checkered").font(.system(size: 44))
            Text("おつかれさまでした").font(.title.bold())
            Text("正解 \(correctCount)・誤答 \(wrongCount)").font(.title3).monospacedDigit()
            let total = correctCount + wrongCount
            if total > 0 {
                Text("正答率 \(Int(Double(correctCount) / Double(total) * 100))%").foregroundStyle(.secondary)
            }
        }
    }
}
