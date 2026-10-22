import SwiftUI
import WebKit
import KokugoCore

/// WKWebView による和文表示。縦書き（vertical-rl）・ルビ・傍線・訓点に対応する。
struct JapaneseTextView: NSViewRepresentable {
    var html: String
    var vertical: Bool
    var fontSize: Double
    /// 短い文（カード）なら中央寄せ
    var centered = false
    var kanbun = false

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.suppressesIncrementalRendering = true
        let view = WKWebView(frame: .zero, configuration: config)
        view.setValue(false, forKey: "drawsBackground")
        view.allowsMagnification = true
        return view
    }

    func updateNSView(_ view: WKWebView, context: Context) {
        let doc = Self.document(body: html, vertical: vertical || kanbun, fontSize: fontSize,
                                centered: centered, kanbun: kanbun)
        if context.coordinator.lastDocument != doc {
            context.coordinator.lastDocument = doc
            view.loadHTMLString(doc, baseURL: nil)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var lastDocument = ""
    }

    static func document(body: String, vertical: Bool, fontSize: Double, centered: Bool, kanbun: Bool) -> String {
        let classes = [vertical ? "vertical" : "horizontal", centered ? "centered" : "", kanbun ? "kanbun" : ""]
            .filter { !$0.isEmpty }.joined(separator: " ")
        return """
        <!doctype html><html lang="ja"><head><meta charset="utf-8"><style>\(css)</style>
        <style>:root{--fs:\(fontSize)px}</style></head>
        <body class="\(classes)"><main>\(body)</main></body></html>
        """
    }

    static let css = """
    :root { color-scheme: light dark; --ink:#1d1d1f; --sub:#6e6e73; --accent:#b4232a; --line:#c8c8cc; --hl: rgba(180,35,42,.08); }
    @media (prefers-color-scheme: dark) { :root { --ink:#f2f2f2; --sub:#a0a0a6; --accent:#ff6b6b; --line:#555; --hl: rgba(255,107,107,.12);} }
    html, body { margin:0; padding:0; background:transparent; color:var(--ink); }
    body { font-family: "Hiragino Mincho ProN", "YuMincho", "Hiragino Mincho Pro", serif; font-size:var(--fs);
           line-height:1.9; -webkit-font-smoothing:antialiased; font-feature-settings:"palt" 0; }
    main { padding: 1.2em 1.4em; box-sizing:border-box; }
    body.vertical { writing-mode: vertical-rl; -webkit-writing-mode: vertical-rl; height:100vh; overflow-x:auto; overflow-y:hidden; }
    body.vertical main { height:100vh; }
    body.horizontal { overflow-y:auto; }
    body.centered { display:flex; align-items:center; justify-content:center; min-height:100vh; }
    body.centered.vertical { height:100vh; width:100vw; }
    body.centered main { text-align:start; }
    p { margin:0; text-indent:1em; }
    body.vertical p + p { margin-right:0; }
    rt { font-size:.5em; }
    .bosen { padding: 0 .08em; }
    body.vertical .bosen { border-right: 1.5px solid var(--accent); }
    body.horizontal .bosen { border-bottom: 1.5px solid var(--accent); }
    .bosen-label { font-size:.6em; color:var(--accent); font-family:-apple-system, sans-serif; margin:0 .15em; }
    body.vertical .bosen-label { text-combine-upright: all; -webkit-text-combine: horizontal; }
    em.boten { font-style:normal; -webkit-text-emphasis: filled sesame; text-emphasis: filled sesame; }
    .blank { display:inline-block; min-inline-size:2.2em; min-block-size:1.3em; border:1px solid var(--line);
             text-align:center; font-size:.7em; color:var(--sub); font-family:-apple-system,sans-serif; margin:0 .2em; }
    body.vertical .blank { text-combine-upright: all; }
    body.kanbun { line-height:2.8; letter-spacing:.15em; }
    .kb { position:relative; display:inline-block; }
    .kb .okuri { position:absolute; top:.55em; left:100%; font-size:.48em; line-height:1.05; white-space:nowrap; letter-spacing:0;
                 font-family:"Hiragino Kaku Gothic ProN", sans-serif; }
    .kb .kaeri { position:absolute; top:.6em; right:100%; font-size:.45em; line-height:1; white-space:nowrap; letter-spacing:0;
                 font-family:"Hiragino Kaku Gothic ProN", sans-serif; }
    table { border-collapse:collapse; margin:.6em 0; font-size:.85em; }
    th, td { border:1px solid var(--line); padding:.25em .55em; vertical-align:top; }
    th { background:var(--hl); font-weight:600; }
    h2 { font-size:1.15em; margin:.9em 0 .3em; color:var(--accent); }
    h3 { font-size:1.0em; margin:.8em 0 .2em; }
    ul { margin:.3em 0; padding-inline-start:1.4em; }
    .note { color:var(--sub); font-size:.85em; }
    body.horizontal.lesson { font-family:"Hiragino Sans", -apple-system, sans-serif; line-height:1.7; }
    body.horizontal.lesson p { text-indent:0; margin:.4em 0; }
    """
}

extension JapaneseTextView {
    /// 解説ページ（横書き・表を含む HTML）
    static func lessonDocument(body: String, fontSize: Double) -> String {
        document(body: body, vertical: false, fontSize: fontSize, centered: false, kanbun: false)
            .replacingOccurrences(of: "<body class=\"horizontal\">", with: "<body class=\"horizontal lesson\">")
    }
}

/// 生成済みの HTML 文書をそのまま表示する
struct HTMLDocumentView: NSViewRepresentable {
    var document: String

    func makeNSView(context: Context) -> WKWebView {
        let view = WKWebView()
        view.setValue(false, forKey: "drawsBackground")
        return view
    }

    func updateNSView(_ view: WKWebView, context: Context) {
        if context.coordinator.last != document {
            context.coordinator.last = document
            view.loadHTMLString(document, baseURL: nil)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }
    final class Coordinator { var last = "" }
}
