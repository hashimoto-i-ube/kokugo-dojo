import SwiftUI
import KokugoCore

enum SidebarItem: Hashable {
    case home
    case subject(Subject)
}

struct RootView: View {
    @Environment(AppModel.self) private var model
    @State private var selection: SidebarItem? = .home
    @State private var path = NavigationPath()

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Label("ホーム", systemImage: "house").tag(SidebarItem.home)
                Section("分野") {
                    ForEach(Subject.allCases) { s in
                        let st = model.stats(subject: s)
                        Label(s.title, systemImage: s.symbol)
                            .badge(st.due)
                            .tag(SidebarItem.subject(s))
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 190, ideal: 210)
            .safeAreaInset(edge: .bottom) { updateFooter }
        } detail: {
            NavigationStack(path: $path) {
                switch selection ?? .home {
                case .home: DashboardView(selection: $selection)
                case .subject(let s): SubjectView(subject: s).id(s)
                }
            }
        }
        .onChange(of: selection) { path = NavigationPath() }
        .onAppear(perform: openDebugRoute)
    }

    /// 動作確認用: `open 国語道場.app --args -debugRoute study:kanji-read` などで画面を直接開く
    private func openDebugRoute() {
        guard let raw = UserDefaults.standard.string(forKey: "debugRoute") else { return }
        let parts = raw.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return }
        let arg = parts[1]
        switch parts[0] {
        case "subject": selection = Subject(rawValue: arg).map { .subject($0) } ?? .home
        case "study": path.append(Route.study(subject: nil, deckID: arg, mode: .flash))
        case "quiz": path.append(Route.study(subject: nil, deckID: arg, mode: .quiz))
        case "browse": path.append(Route.browse(deckID: arg))
        case "passage": path.append(Route.passage(id: arg))
        case "lesson": path.append(Route.lesson(id: arg))
        default: break
        }
    }

    @ViewBuilder private var updateFooter: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let r = model.availableRelease {
                Link("新バージョン \(r.version) があります", destination: r.url)
                    .font(.caption)
            }
            if let s = model.updateStatus {
                Text(s).font(.caption2).foregroundStyle(.secondary).lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
    }
}
