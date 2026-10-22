import SwiftUI
import KokugoCore

struct PassageView: View {
    @Environment(AppModel.self) private var model
    @AppStorage(SettingsKey.vertical) private var vertical = true
    @AppStorage(SettingsKey.fontSize) private var fontSize = 22.0
    var passageID: String

    /// 設問ID → 選んだ選択肢の元の添字
    @State private var answers: [String: Int] = [:]
    @State private var graded = false
    /// 設問ID → 表示順（元の添字の並び）。正解の位置が毎回変わるようにする
    @State private var order: [String: [Int]] = [:]

    var body: some View {
        if let p = model.library.packs.flatMap({ $0.passages ?? [] }).first(where: { $0.id == passageID }) {
            HSplitView {
                VStack(spacing: 0) {
                    JapaneseTextView(html: Markup.html(p.text, kanbun: p.kanbun ?? false),
                                     vertical: vertical, fontSize: fontSize, kanbun: p.kanbun ?? false)
                    if let src = p.source {
                        Text(src).font(.caption).foregroundStyle(.secondary).padding(6)
                    }
                }
                .frame(minWidth: 420, maxWidth: .infinity)

                questions(p).frame(minWidth: 340, idealWidth: 420, maxWidth: 560)
            }
            .navigationTitle(p.title)
            .onAppear { if order.isEmpty { shuffle(p) } }
        }
    }

    private func questions(_ p: Passage) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    LevelChip(level: p.level)
                    Text(p.genre).foregroundStyle(.secondary)
                }
                ForEach(Array(p.questions.enumerated()), id: \.element.id) { n, q in
                    VStack(alignment: .leading, spacing: 8) {
                        Text("問\(n + 1)　\(Markup.plain(q.prompt))").font(.body.weight(.semibold))
                            .fixedSize(horizontal: false, vertical: true)
                        ForEach(Array((order[q.id] ?? Array(q.choices.indices)).enumerated()), id: \.element) { pos, i in
                            Button { if !graded { answers[q.id] = i } } label: {
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: answers[q.id] == i ? "largecircle.fill.circle" : "circle")
                                    Text("\(["ア", "イ", "ウ", "エ", "オ", "カ"][min(pos, 5)])　\(Markup.plain(q.choices[i]))")
                                        .fixedSize(horizontal: false, vertical: true)
                                        .multilineTextAlignment(.leading)
                                    Spacer(minLength: 0)
                                    if graded && i == q.answer { Image(systemName: "checkmark").foregroundStyle(.green) }
                                }
                                .padding(8)
                                .background(rowColor(q, i), in: RoundedRectangle(cornerRadius: 6))
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                        if graded, let ex = q.explanation {
                            Text(Markup.plain(ex)).font(.callout).foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .textSelection(.enabled)
                        }
                    }
                }
                if graded {
                    let score = p.questions.filter { answers[$0.id] == $0.answer }.count
                    Text("得点 \(score) / \(p.questions.count)").font(.title3.bold())
                    if let c = p.commentary {
                        GroupBox("本文の要旨・解説") {
                            Text(Markup.plain(c)).fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    Button("もう一度解く") { answers = [:]; graded = false; shuffle(p) }
                } else {
                    Button("採点する") {
                        graded = true
                        let score = p.questions.filter { answers[$0.id] == $0.answer }.count
                        model.recordPassage(p.id, score: score, total: p.questions.count)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(answers.count < p.questions.count)
                }
            }
            .padding(20)
        }
    }

    private func shuffle(_ p: Passage) {
        order = Dictionary(uniqueKeysWithValues: p.questions.map { ($0.id, Array($0.choices.indices).shuffled()) })
    }

    private func rowColor(_ q: Question, _ i: Int) -> Color {
        guard graded else { return answers[q.id] == i ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.06) }
        if i == q.answer { return .green.opacity(0.15) }
        if answers[q.id] == i { return .red.opacity(0.15) }
        return Color.secondary.opacity(0.06)
    }
}
