import SwiftUI
import KokugoCore

enum StudyMode: String, Hashable {
    case flash, quiz
    var title: String { self == .flash ? "カード学習" : "4択テスト" }
}

enum Route: Hashable {
    case study(subject: Subject?, deckID: String?, mode: StudyMode)
    case browse(deckID: String)
    case passage(id: String)
    case lesson(id: String)
}

struct RouteDestinations: ViewModifier {
    func body(content: Content) -> some View {
        content.navigationDestination(for: Route.self) { route in
            switch route {
            case let .study(subject, deckID, mode):
                StudySessionView(subject: subject, deckID: deckID, mode: mode)
            case .browse(let id):
                DeckBrowserView(deckID: id)
            case .passage(let id):
                PassageView(passageID: id)
            case .lesson(let id):
                LessonView(lessonID: id)
            }
        }
    }
}

extension View {
    func routeDestinations() -> some View { modifier(RouteDestinations()) }
}

struct DashboardView: View {
    @Environment(AppModel.self) private var model
    @Binding var selection: SidebarItem?

    var body: some View {
        let all = model.stats()
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .firstTextBaseline) {
                    Text("国語道場").font(.system(size: 34, weight: .bold, design: .serif))
                    Text("高校入門 → 旧帝大・医学部").foregroundStyle(.secondary)
                    Spacer()
                    Text("目標範囲 Lv.\(model.levelRange.lowerBound)〜\(model.levelRange.upperBound)")
                        .font(.callout).foregroundStyle(.secondary)
                }

                HStack(spacing: 14) {
                    StatTile(title: "今日の復習", value: "\(all.due)", sub: "件")
                    StatTile(title: "学習済み", value: "\(all.seen)", sub: "/ \(all.total)")
                    StatTile(title: "定着", value: "\(all.mature)", sub: "間隔21日以上")
                    StatTile(title: "連続学習", value: "\(model.progress.streak())", sub: "日")
                }

                NavigationLink(value: Route.study(subject: nil, deckID: nil, mode: .flash)) {
                    Label("今日の学習を始める（全分野）", systemImage: "play.fill")
                        .font(.title3.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                ActivityChart()

                VStack(alignment: .leading, spacing: 10) {
                    Text("分野別の進み具合").font(.headline)
                    ForEach(Subject.allCases) { s in
                        SubjectProgressRow(subject: s) { selection = .subject(s) }
                    }
                }

                if !model.library.problems.isEmpty {
                    VStack(alignment: .leading) {
                        Text("読み込めなかったコンテンツ").font(.headline)
                        ForEach(model.library.problems, id: \.self) { Text($0).font(.caption).foregroundStyle(.red) }
                    }
                }
            }
            .padding(28)
        }
        .navigationTitle("ホーム")
        .routeDestinations()
    }
}

struct StatTile: View {
    var title: String
    var value: String
    var sub: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value).font(.system(size: 28, weight: .semibold, design: .rounded)).monospacedDigit()
                Text(sub).font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
    }
}

struct SubjectProgressRow: View {
    @Environment(AppModel.self) private var model
    var subject: Subject
    var open: () -> Void

    var body: some View {
        Button(action: open) {
            HStack(spacing: 12) {
                Label(subject.title, systemImage: subject.symbol).frame(width: 160, alignment: .leading)
                HStack(spacing: 4) {
                    ForEach(Level.allCases) { lv in
                        let st = model.stats(subject: subject, level: lv)
                        LevelBar(stats: st).help("\(lv.title): \(st.seen)/\(st.total)")
                    }
                }
                let st = model.stats(subject: subject)
                Text("\(st.seen)/\(st.total)").monospacedDigit().foregroundStyle(.secondary).frame(width: 80, alignment: .trailing)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct LevelBar: View {
    var stats: AppModel.Stats

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let seen = stats.total == 0 ? 0 : CGFloat(stats.seen) / CGFloat(stats.total)
            let mature = stats.total == 0 ? 0 : CGFloat(stats.mature) / CGFloat(stats.total)
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3).fill(.quaternary)
                RoundedRectangle(cornerRadius: 3).fill(Color.accentColor.opacity(0.35)).frame(width: w * seen)
                RoundedRectangle(cornerRadius: 3).fill(Color.accentColor).frame(width: w * mature)
            }
        }
        .frame(height: 10)
        .opacity(stats.total == 0 ? 0.3 : 1)
    }
}

/// 直近 14 日の回答数
struct ActivityChart: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let _ = model.revision
        let cal = Calendar.current
        let days: [(String, Int)] = (0..<14).reversed().map { back in
            let d = cal.date(byAdding: .day, value: -back, to: Date())!
            return (String(cal.component(.day, from: d)), model.progress.data.daily[ProgressStore.dayKey(d), default: 0])
        }
        let maxV = max(days.map(\.1).max() ?? 1, 1)
        VStack(alignment: .leading, spacing: 6) {
            Text("直近14日の回答数").font(.headline)
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, d in
                    VStack(spacing: 3) {
                        Text(d.1 > 0 ? "\(d.1)" : "").font(.system(size: 9)).foregroundStyle(.secondary)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.accentColor.opacity(d.1 > 0 ? 0.8 : 0.15))
                            .frame(height: max(3, 60 * CGFloat(d.1) / CGFloat(maxV)))
                        Text(d.0).font(.system(size: 9)).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 90)
        }
    }
}
