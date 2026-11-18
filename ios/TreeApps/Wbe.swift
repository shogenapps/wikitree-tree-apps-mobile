import Foundation
import WebKit

/// The WikiTree Browser Extension (WBE) on wikitree.com pages in the app's page sheet.
///
/// WBE's "webview" build (fetched at build time into the app's `wbe` folder, see docs/wbe.md)
/// carries its own stand-in for the chrome.* extension APIs. The stand-in talks to
/// `window.__wbeHost`, which this class provides:
///
/// - WBE's files are served from the app on the `wbe-app:` scheme (`wbe-app://app/...`). iOS can't
///   answer https://www.wikitree.com/__wbe/ the way Android does, so this is WBE's `base` here.
/// - Document-start scripts define `__wbeHost` and run wbe-early.js (all frames) and
///   wbe-webview.js (top frame), on https://www.wikitree.com pages only.
/// - Host calls arrive over a script message handler with replies: settings storage (one store for
///   every web view, kept in Application Support), openOptions and openUrl.
/// - When a page changes a setting, every other open WBE page gets a storageChanged event. The page
///   that wrote it fires its own onChanged, so it is not sent the event again.
final class Wbe: NSObject, WKScriptMessageHandlerWithReply, WKURLSchemeHandler {
    static let shared = Wbe()
    static let scheme = "wbe-app"
    static let base = "wbe-app://app/"
    static let optionsURL = URL(string: base + "options.html")!
    private static let handlerName = "wbeNative"

    /// The tools WBE's right-click menu offers on a computer, and the feature each belongs to.
    struct Tool: Hashable {
        let title: String
        let action: String
        let feature: String
    }

    static let tools = [
        Tool(title: "Notes", action: "showNotes", feature: "clipboardAndNotes"),
        Tool(title: "Clipboard", action: "showClipboard", feature: "clipboardAndNotes"),
        Tool(title: "Wikitable Wizard", action: "launchWikitableWizard", feature: "wikitableWizard"),
        Tool(title: "Color Blind Simulator", action: "showColorBlindSimulator", feature: "colorBlindSupport"),
    ]

    private let folder = Bundle.main.url(forResource: "wbe", withExtension: nil)

    /// True when this build of the app includes WBE.
    var isAvailable: Bool {
        guard let folder else { return false }
        return FileManager.default.fileExists(atPath: folder.appendingPathComponent("webview.json").path)
    }

    /// On unless the member turned it off in the WBE menu.
    var isEnabled: Bool {
        get { isAvailable && !UserDefaults.standard.bool(forKey: "wbe.off") }
        set { UserDefaults.standard.set(!newValue, forKey: "wbe.off") }
    }

    static func isWbePage(_ url: URL?) -> Bool { url?.scheme == scheme }

    private lazy var info: [String: Any] = {
        guard let folder, let data = try? Data(contentsOf: folder.appendingPathComponent("webview.json")),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [:] }
        return json
    }()

    /// WBE's version, for the menu.
    var version: String { info["version"] as? String ?? "" }

    /// Counts changes to WBE's settings (the sync area), so a page can tell whether the settings
    /// screen changed anything while it was open, and reload if so.
    private(set) var settingsChanges = 0

    // MARK: Setting up a web view

    /// Call on a configuration before its web view is made. The file server is always added, so
    /// WBE's settings page can load; the scripts only while WBE is on.
    func configure(_ config: WKWebViewConfiguration) {
        guard isAvailable else { return }
        config.setURLSchemeHandler(self, forURLScheme: Wbe.scheme)
        if isEnabled { attach(config.userContentController) }
    }

    /// Adds WBE's scripts and host; they take effect from the next page load.
    func attach(_ controller: WKUserContentController) {
        guard isAvailable else { return }
        detach(controller)
        controller.addScriptMessageHandler(self, contentWorld: .page, name: Wbe.handlerName)
        controller.addUserScript(WKUserScript(source: hostAndEarlyScript, injectionTime: .atDocumentStart,
                                              forMainFrameOnly: false, in: .page))
        controller.addUserScript(WKUserScript(source: mainScript, injectionTime: .atDocumentStart,
                                              forMainFrameOnly: true, in: .page))
    }

    /// Takes WBE off; the page sheet's web views have no other user scripts.
    func detach(_ controller: WKUserContentController) {
        controller.removeScriptMessageHandler(forName: Wbe.handlerName, contentWorld: .page)
        controller.removeAllUserScripts()
    }

    /// What a page's web view does when WBE asks to open its settings or a link.
    struct Actions {
        var openOptions: () -> Void
        var openUrl: (URL) -> Void
    }

    private let actions = NSMapTable<WKWebView, ActionsBox>.weakToStrongObjects()
    private let pages = NSHashTable<WKWebView>.weakObjects()

    private final class ActionsBox {
        let actions: Actions
        init(_ actions: Actions) { self.actions = actions }
    }

    func register(_ webView: WKWebView, actions: Actions) {
        self.actions.setObject(ActionsBox(actions), forKey: webView)
    }

    /// Sends a message to the WBE listeners on the page (chrome.runtime.onMessage), as the
    /// extension's right-click menu would.
    func sendToPage(_ webView: WKWebView, message: [String: Any]) {
        post(["type": "message", "message": message], to: webView)
    }

    /// Which of [ids] WBE has started on the page: it marks each feature it starts with a
    /// data-wbe-<feature id> attribute on <html>.
    func runningFeatures(_ webView: WKWebView, ids: [String], result: @escaping (Set<String>) -> Void) {
        let list = (try? JSONSerialization.data(withJSONObject: ids)).flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
        let js = "(function(ids){var h=document.documentElement;return ids.filter(function(i){return h.hasAttribute('data-wbe-'+i);}).join(',');})(\(list))"
        webView.evaluateJavaScript(js, in: nil, in: .page) { outcome in
            if case .success(let value) = outcome, let text = value as? String {
                result(Set(text.split(separator: ",").map(String.init)))
            } else {
                result([])
            }
        }
    }

    // MARK: Page scripts

    private func asset(_ name: String) -> String {
        guard let folder, let text = try? String(contentsOf: folder.appendingPathComponent(name), encoding: .utf8)
        else { return "" }
        return text
    }

    private lazy var hostAndEarlyScript: String = {
        let early = asset(info["early"] as? String ?? "wbe-early.js")
        return Wbe.hostJS + "\nif (window.__wbeHost && !window.__wbeSkipBundles) { try {\n" + early +
            "\n} catch (e) { console.error('WBE early', e); } }\n"
    }()

    private lazy var mainScript: String = {
        let main = asset(info["entry"] as? String ?? "wbe-webview.js")
        return "if (window.__wbeHost && !window.__wbeSkipBundles) { try {\n" + main +
            "\n} catch (e) { console.error('WBE', e); } }\n"
    }()

    /// `__wbeHost` as the WBE stand-in expects it (see the WBE webview brief). The stand-in sets
    /// reply() and event() on it. Only wikitree.com pages and WBE's own pages get it.
    private static let hostJS = """
    (function () {
      var site = location.protocol === "https:" && location.hostname === "www.wikitree.com";
      var wbePage = location.protocol === "wbe-app:";
      if (window.__wbeHost || !(site || wbePage)) return;
      var native = window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.wbeNative;
      if (!native) return;
      window.__wbeSkipBundles = wbePage;
      var host = window.__wbeHost = {
        platform: "ios",
        base: "wbe-app://app/",
        send: function (json) {
          var id;
          try { id = JSON.parse(json).id; } catch (e) {}
          native.postMessage(json).then(
            function (result) { if (host.reply) host.reply(id, null, result); },
            function (error) { if (host.reply) host.reply(id, String((error && error.message) || error), null); }
          );
        }
      };
      if (wbePage) {
        // The settings page is laid out for a 780 px popup; fit it to a phone: the options button
        // sits on the feature's own line and the creator line goes under the name.
        var fit = function () {
          var s = document.createElement("style");
          s.textContent = [
            "html { min-width: 0 !important; }",
            "body { max-width: 100vw; overflow-x: hidden; }",
            ".section-header { display: flex; flex-wrap: wrap; align-items: center; column-gap: 8px; }",
            ".feature-options-button { left: auto; top: auto; margin-left: auto; min-width: 0; padding: 5px 12px; font-size: 13px; }",
            ".feature-author { position: static; text-align: left; padding: 0; margin: 0 0 2px 22px; }",
            ".feature-author > div { display: inline; margin-right: 8px; }"
          ].join("\\n");
          (document.head || document.documentElement).appendChild(s);
        };
        if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", fit); else fit();
      }
    })();
    """

    // MARK: Host calls

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage,
                               replyHandler: @escaping (Any?, String?) -> Void) {
        let origin = message.frameInfo.securityOrigin
        let allowed = origin.protocol == Wbe.scheme ||
            origin.protocol == "https" && origin.host == "www.wikitree.com"
        guard allowed, let body = message.body as? String, let data = body.data(using: .utf8),
              let call = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return replyHandler(nil, "Not allowed")
        }
        if let webView = message.webView, message.frameInfo.isMainFrame { pages.add(webView) }
        let method = call["method"] as? String ?? ""
        let args = call["args"] as? [String: Any] ?? [:]
        do {
            switch method {
            case "storage.get":
                replyHandler(Wbe.json(try store(args).get(args["keys"])), nil)
            case "storage.set":
                let area = try store(args)
                changed(area, area.set(args["items"] as? [String: Any] ?? [:]), from: message.webView)
                replyHandler("null", nil)
            case "storage.remove":
                let area = try store(args)
                changed(area, area.remove(args["keys"]), from: message.webView)
                replyHandler("null", nil)
            case "storage.clear":
                let area = try store(args)
                changed(area, area.clear(), from: message.webView)
                replyHandler("null", nil)
            case "openOptions":
                if let webView = message.webView { actions.object(forKey: webView)?.actions.openOptions() }
                replyHandler("null", nil)
            case "openUrl":
                if let webView = message.webView, let text = args["url"] as? String, let url = URL(string: text) {
                    actions.object(forKey: webView)?.actions.openUrl(url)
                }
                replyHandler("null", nil)
            default:
                replyHandler(nil, "Unknown host method \(method)")
            }
        } catch {
            replyHandler(nil, "\(error)")
        }
    }

    private func store(_ args: [String: Any]) throws -> Store {
        switch args["area"] as? String {
        case "sync": return sync
        case "local": return local
        default: throw WbeError.unknownArea
        }
    }

    private enum WbeError: Error { case unknownArea }

    /// Tells every other open WBE page about a settings change.
    private func changed(_ area: Store, _ changes: [String: Any], from: WKWebView?) {
        if changes.isEmpty { return }
        if area === sync { settingsChanges += 1 }
        let event: [String: Any] = ["type": "storageChanged", "area": area.name, "changes": changes]
        for webView in pages.allObjects where webView !== from {
            post(event, to: webView)
        }
    }

    private func post(_ event: [String: Any], to webView: WKWebView) {
        // event() takes the event as a JSON string; pass that string as a JS string literal.
        guard let eventJSON = Wbe.json(event),
              let literal = Wbe.json([eventJSON]).map({ String($0.dropFirst().dropLast()) }) else { return }
        webView.evaluateJavaScript("window.__wbeHost && window.__wbeHost.event && window.__wbeHost.event(\(literal))",
                                   in: nil, in: .page) { _ in }
    }

    private static func json(_ value: Any) -> String? {
        guard let data = try? JSONSerialization.data(withJSONObject: value, options: [.fragmentsAllowed]) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    // MARK: Storage

    private lazy var sync = Store(name: "sync")
    private lazy var local = Store(name: "local")

    /// One storage area, kept as a JSON file in Application Support.
    private final class Store {
        let name: String
        private var items: [String: Any]
        private let file: URL

        init(name: String) {
            self.name = name
            let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("wbe", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            file = dir.appendingPathComponent("\(name).json")
            if let data = try? Data(contentsOf: file),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                items = json
            } else {
                items = [:]
            }
        }

        private func save() {
            if let data = try? JSONSerialization.data(withJSONObject: items) {
                try? data.write(to: file, options: .atomic)
            }
        }

        private func keyList(_ keys: Any?) -> [String]? {
            switch keys {
            case nil, is NSNull: return nil
            case let key as String: return [key]
            case let list as [Any]: return list.map { "\($0)" }
            case let defaults as [String: Any]: return Array(defaults.keys)
            default: return nil
            }
        }

        func get(_ keys: Any?) -> [String: Any] {
            guard let names = keyList(keys) else { return items }
            let defaults = keys as? [String: Any] ?? [:]
            var out: [String: Any] = [:]
            for key in names {
                if let value = items[key] { out[key] = value } else if let value = defaults[key] { out[key] = value }
            }
            return out
        }

        func set(_ values: [String: Any]) -> [String: Any] {
            var changes: [String: Any] = [:]
            for (key, value) in values {
                var change: [String: Any] = ["newValue": value]
                if let old = items[key] { change["oldValue"] = old }
                changes[key] = change
                items[key] = value
            }
            save()
            return changes
        }

        func remove(_ keys: Any?) -> [String: Any] {
            var changes: [String: Any] = [:]
            for key in keyList(keys) ?? [] {
                if let old = items.removeValue(forKey: key) { changes[key] = ["oldValue": old] }
            }
            save()
            return changes
        }

        func clear() -> [String: Any] { remove(Array(items.keys)) }
    }

    // MARK: Files (wbe-app://app/...)

    func webView(_ webView: WKWebView, start task: WKURLSchemeTask) {
        guard let url = task.request.url, let folder else { return task.didFailWithError(URLError(.fileDoesNotExist)) }
        let path = url.path.hasPrefix("/") ? String(url.path.dropFirst()) : url.path
        let file = folder.appendingPathComponent(path).standardizedFileURL
        guard !path.isEmpty, file.path.hasPrefix(folder.standardizedFileURL.path + "/"),
              let data = try? Data(contentsOf: file) else {
            let response = HTTPURLResponse(url: url, statusCode: 404, httpVersion: "HTTP/1.1", headerFields: [:])!
            task.didReceive(response)
            task.didReceive(Data())
            return task.didFinish()
        }
        let types = [
            "js": "text/javascript; charset=utf-8", "mjs": "text/javascript; charset=utf-8",
            "json": "application/json; charset=utf-8", "css": "text/css; charset=utf-8",
            "html": "text/html; charset=utf-8", "svg": "image/svg+xml", "png": "image/png",
            "jpg": "image/jpeg", "jpeg": "image/jpeg", "gif": "image/gif", "webp": "image/webp",
            "woff2": "font/woff2", "woff": "font/woff", "ttf": "font/ttf",
        ]
        let type = types[file.pathExtension.lowercased()] ?? "application/octet-stream"
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: [
            "Content-Type": type,
            "Content-Length": "\(data.count)",
            "Access-Control-Allow-Origin": "*",
            "Cache-Control": "no-cache",
        ])!
        task.didReceive(response)
        task.didReceive(data)
        task.didFinish()
    }

    func webView(_ webView: WKWebView, stop task: WKURLSchemeTask) {}
}
