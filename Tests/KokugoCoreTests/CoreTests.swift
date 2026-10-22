import XCTest
@testable import KokugoCore

final class MarkupTests: XCTestCase {
    func testRuby() {
        XCTAssertEqual(Markup.inline("{漢字|かんじ}", kanbun: false), "<ruby>漢字<rt>かんじ</rt></ruby>")
    }

    func testBosenWithLabel() {
        XCTAssertEqual(Markup.inline("[[収拾|ア]]する", kanbun: false),
                       "<span class=\"bosen\">収拾</span><span class=\"bosen-label\">ア</span>する")
    }

    func testPlain() {
        XCTAssertEqual(Markup.plain("事態を[[{収拾|しゅうしゅう}]]する"), "事態を収拾する")
        XCTAssertEqual(Markup.plain("__A__に入る語"), "（A）に入る語")
    }

    func testEscape() {
        XCTAssertEqual(Markup.inline("a<b", kanbun: false), "a&lt;b")
    }

    func testKanbunMarks() {
        let html = Markup.inline("学（ビテ）時〔二〕", kanbun: true)
        XCTAssertTrue(html.contains("<span class=\"kb\">学<span class=\"okuri\">ビテ</span></span>"))
        XCTAssertTrue(html.contains("<span class=\"kb\">時<span class=\"kaeri\">二</span></span>"))
    }

    func testParenthesesOutsideKanbunAreText() {
        XCTAssertEqual(Markup.inline("時（とき）", kanbun: false), "時（とき）")
    }

    func testParagraphs() {
        XCTAssertEqual(Markup.html("一\n\n二"), "<p>一</p><p>二</p>")
    }
}

final class SchedulerTests: XCTestCase {
    func testGoodProgression() {
        let now = Date()
        var s = Scheduler.review(CardState(), grade: .good, now: now)
        XCTAssertEqual(s.interval, 1)
        s = Scheduler.review(s, grade: .good, now: now)
        XCTAssertEqual(s.interval, 3)
        s = Scheduler.review(s, grade: .good, now: now)
        XCTAssertEqual(s.interval, 7.5, accuracy: 0.01)
    }

    func testAgainResets() {
        var s = Scheduler.review(CardState(), grade: .good)
        s = Scheduler.review(s, grade: .good)
        s = Scheduler.review(s, grade: .again)
        XCTAssertEqual(s.reps, 0)
        XCTAssertEqual(s.lapses, 1)
        XCTAssertLessThan(s.ease, 2.5)
    }

    func testVersionCompare() {
        XCTAssertEqual(compareVersions("2026.10.2", "2026.10.10"), .orderedAscending)
        XCTAssertEqual(compareVersions("1.0", "1.0.0"), .orderedSame)
    }
}

final class QueueTests: XCTestCase {
    func testChoicesContainAnswer() {
        let items = (0..<10).map { StudyItem(id: "i\($0)", level: .l1, prompt: "p\($0)", answer: "a\($0)") }
        let deck = Deck(id: "d", title: "d", kind: .flash, items: items)
        let c = StudyQueue.choices(for: items[0], in: deck)
        XCTAssertEqual(c.count, 4)
        XCTAssertTrue(c.contains("a0"))
        XCTAssertEqual(Set(c).count, 4)
    }
}

final class ContentTests: XCTestCase {
    /// リポジトリ同梱のパックがすべて読み込めること
    func testBundledPacksDecode() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let lib = ContentLibrary.load(directories: [root.appendingPathComponent("content/packs")])
        XCTAssertTrue(lib.problems.isEmpty, lib.problems.joined(separator: "\n"))
        XCTAssertFalse(lib.packs.isEmpty)
        var ids = Set<String>()
        for d in lib.allDecks {
            for it in d.items {
                XCTAssertFalse(ids.contains(it.id), "duplicate id \(it.id)")
                ids.insert(it.id)
            }
        }
    }
}
