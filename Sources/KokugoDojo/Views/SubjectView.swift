import SwiftUI
import KokugoCore

struct SubjectView: View {
    @Environment(AppModel.self) private var model
    var subject: Subject

    var body: some View {
        let packs = model.library.packs(for: subject)
        let decks = packs.flatMap(\.decks)
        let passages = packs.flatMap { $0.passages ?? [] }.sorted { $0.level < $1.level }
        let lessons = packs.flatMap { $0.lessons ?? [] }.sorted { $0.level < $1.level }
        let st = model.stats(subject: subject)

        List {
            Section {
                HStack(spacing: 12) {
                    NavigationLink(value: Route.study(subject: subject, deckID: nil, mode: .flash)) {
                        Label("\(subject.title)をまとめて学習", systemImage: "rectangle.on.rectangle.angled")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(decks.isEmpty)
                    NavigationLink(value: Route.study(subject: subject, deckID: nil, mode: .quiz)) {
                        Label("4択テスト", systemImage: "checklist")
                    }
                    .buttonStyle(.bordered)
                    .disabled(decks.isEmpty)
                    Spacer()
                    Text("復習 \(st.due)・学習済み \(st.seen)/\(st.total)").foregroundStyle(.secondary).monospacedDigit()
                }
                .padding(.vertical, 6)
            }

            if !lessons.isEmpty {
                Section("解説") {
                    ForEach(lessons) { l in
                        NavigationLink(value: Route.lesson(id: l.id)) {
                            HStack {
                                LevelChip(level: l.level)
                                Text(l.title)
                            }
                        }
                    }
                }
            }

            if !decks.isEmpty {
                Section("問題集") {
                    ForEach(decks) { d in DeckRow(deck: d) }
                }
            }

            if !passages.isEmpty {
                Section("読解演習") {
                    ForEach(passages) { p in
                        NavigationLink(value: Route.passage(id: p.id)) {
                            HStack {
                                LevelChip(level: p.level)
                                Text(p.genre).font(.caption).padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(.quaternary, in: Capsule())
                                Text(p.title)
                                Spacer()
                                if let r = model.progress.data.passages[p.id] {
                                    Text("最高 \(r.bestScore)/\(r.total)").foregroundStyle(.secondary).monospacedDigit()
                                }
                            }
                        }
                    }
                }
            }

            if packs.isEmpty {
                Text("この分野のコンテンツはまだありません。").foregroundStyle(.secondary)
            } else {
                Section {
                    ForEach(packs) { p in
                        Text("\(p.title)  v\(p.version)・学習指導要領 \(p.curriculum)")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle(subject.title)
        .routeDestinations()
    }
}

struct DeckRow: View {
    @Environment(AppModel.self) private var model
    var deck: Deck

    var body: some View {
        let st = model.stats(deck: deck)
        let levels = Set(deck.items.map(\.level)).sorted()
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(deck.title).font(.body.weight(.medium))
                HStack(spacing: 6) {
                    if let lo = levels.first, let hi = levels.last {
                        Text(lo == hi ? lo.shortTitle : "\(lo.shortTitle)〜\(hi.rawValue)")
                    }
                    Text("\(deck.items.count)問")
                    if let d = deck.description { Text(d).lineLimit(1) }
                }
                .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            LevelBar(stats: st).frame(width: 90)
            Text("\(st.seen)/\(st.total)").monospacedDigit().foregroundStyle(.secondary).frame(width: 64, alignment: .trailing)
            NavigationLink(value: Route.study(subject: nil, deckID: deck.id, mode: .flash)) { Text("学習") }
                .buttonStyle(.bordered)
            NavigationLink(value: Route.study(subject: nil, deckID: deck.id, mode: .quiz)) { Text("テスト") }
                .buttonStyle(.bordered)
            NavigationLink(value: Route.browse(deckID: deck.id)) { Image(systemName: "list.bullet") }
                .buttonStyle(.borderless)
                .help("一覧")
        }
        .padding(.vertical, 3)
    }
}

struct LevelChip: View {
    var level: Level
    var body: some View {
        Text(level.shortTitle)
            .font(.caption2.weight(.semibold)).monospacedDigit()
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(color.opacity(0.18), in: Capsule())
            .foregroundStyle(color)
    }
    private var color: Color {
        [Color.green, .teal, .blue, .purple, .red][level.rawValue - 1]
    }
}

struct DeckBrowserView: View {
    @Environment(AppModel.self) private var model
    var deckID: String
    @State private var query = ""

    var body: some View {
        if let deck = model.library.deck(id: deckID) {
            let rows = deck.items.filter {
                query.isEmpty || Markup.plain($0.prompt).contains(query) || $0.answer.contains(query) || ($0.note ?? "").contains(query)
            }
            Table(rows) {
                TableColumn("Lv") { LevelChip(level: $0.level) }.width(46)
                TableColumn("問題") { Text(Markup.plain($0.prompt)) }
                TableColumn("答え") { Text(Markup.plain($0.answer)) }
                TableColumn("解説") { Text(Markup.plain($0.note ?? "")).foregroundStyle(.secondary) }
                TableColumn("状態") { it in
                    let s = model.progress.state(for: it.id)
                    Text(s.isNew ? "未学習" : s.isMature ? "定着" : "学習中 \(Int(s.interval))日")
                        .foregroundStyle(s.isNew ? .secondary : s.isMature ? Color.green : Color.primary)
                }.width(90)
            }
            .searchable(text: $query)
            .navigationTitle(deck.title)
        }
    }
}

struct LessonView: View {
    @Environment(AppModel.self) private var model
    @AppStorage(SettingsKey.fontSize) private var fontSize = 22.0
    var lessonID: String

    var body: some View {
        if let lesson = model.library.packs.flatMap({ $0.lessons ?? [] }).first(where: { $0.id == lessonID }) {
            HTMLDocumentView(document: JapaneseTextView.lessonDocument(body: lesson.body, fontSize: fontSize * 0.75))
                .navigationTitle(lesson.title)
        }
    }
}
