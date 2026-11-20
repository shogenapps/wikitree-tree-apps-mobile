import Foundation
import UIKit
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
///   every web view, kept in Application Support), openOptions, openUrl, and net.fetch for WBE's
///   AI requests (see "AI requests" below).
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
      if (site) {
        // iOS treats wbe-app: as insecure on an https page: WebKit loads WBE's images from it but
        // blocks its scripts and fetches (mixed content). So WBE's script and data files (Genie's
        // wbe-genie.js, the edit-page helpers, WikiTree+ templates) come over the host instead:
        // a <script> gets the file as its text, and fetch() gets a Response made from it.
        var base = host.base;
        var file = function (url) {
          return native.postMessage(JSON.stringify({ method: "file", args: { path: url.slice(base.length) } }))
            .then(function (text) { return JSON.parse(text); });
        };
        var srcProp = Object.getOwnPropertyDescriptor(HTMLScriptElement.prototype, "src");
        Object.defineProperty(HTMLScriptElement.prototype, "src", {
          configurable: true, enumerable: srcProp.enumerable,
          get: function () { return this.__wbeSrc || srcProp.get.call(this); },
          set: function (value) {
            var url = String(value);
            if (url.indexOf(base) !== 0) return srcProp.set.call(this, value);
            var el = this;
            el.__wbeSrc = url;
            var fire = function (type) { el.dispatchEvent(new Event(type)); };
            file(url).then(function (text) {
              // An empty script runs when it gets its text, with document.currentScript set to it,
              // as WBE's page helpers expect. The load event follows once it has run.
              el.text = text + "\\n//# sourceURL=" + url;
              var tries = 0;
              (function done() {
                if (el.isConnected || ++tries > 100) return setTimeout(function () { fire("load"); }, 0);
                setTimeout(done, 50);
              })();
            }, function (error) {
              console.error("WBE couldn't load " + url, error);
              setTimeout(function () { fire("error"); }, 0);
            });
          }
        });
        var pageFetch = window.fetch;
        window.fetch = function (input, init) {
          var url = typeof input === "string" ? input : input && input.url;
          if (typeof url !== "string" || url.indexOf(base) !== 0) return pageFetch.apply(this, arguments);
          return file(url).then(function (text) {
            var type = /[.]json$/.test(url.split("?")[0]) ? "application/json" : "text/plain";
            return new Response(text, { status: 200, headers: { "Content-Type": type } });
          }, function (error) { throw new TypeError("WBE couldn't load " + url + ": " + error); });
        };
      }
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
            case "net.fetch":
                // (answered later: it may ask the member first, and the request takes a while)
                aiFetch(args, from: message.webView, reply: replyHandler)
            case "file":
                // A WBE script or data file for the page (see hostJS: iOS won't load them from wbe-app:).
                replyHandler(Wbe.json(try textFile(args["path"] as? String ?? "")), nil)
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

    // MARK: AI requests (net.fetch)

    // WBE's AI requests (Genie, Auto Bio's Improve with AI and the other AI features), which the
    // extension makes from its background script. Here WBE sends them as the net.fetch host call and
    // the app makes the request itself, so no CORS rules get in the way.
    // - Only the AI providers' API hosts are allowed; anything else is refused.
    // - The member brings their own API key (WBE's AI Settings); it goes only to that provider.
    // - The first time a provider is used, the member is asked whether WBE may send to it (app store
    //   rules ask for that before personal data goes to a third-party AI). Allow is remembered for
    //   that provider; Don't Allow refuses this request only, so the next one asks again.

    /// Host to the name the member knows the provider by. Matches ai_requests.js in WBE.
    private static let aiProviders = [
        "api.openai.com": "OpenAI",
        "generativelanguage.googleapis.com": "Google Gemini",
        "api.anthropic.com": "Anthropic (Claude)",
        "api.perplexity.ai": "Perplexity",
        "api.x.ai": "xAI (Grok)",
        "ollama.com": "Ollama Cloud",
    ]

    /// WBE gives up after 4½ minutes and says so; this is a little longer, so its message is the one shown.
    private static let aiTimeout: TimeInterval = 280

    private lazy var aiSession: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = Wbe.aiTimeout
        config.timeoutIntervalForResource = Wbe.aiTimeout + 10
        return URLSession(configuration: config, delegate: NoRedirects(), delegateQueue: nil)
    }()

    /// The API key must only ever go to the provider, so redirects aren't followed.
    private final class NoRedirects: NSObject, URLSessionTaskDelegate {
        func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                        newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
            completionHandler(nil)
        }
    }

    /// One net.fetch call: { url, method, headers, body } -> { status, statusText, body }.
    private func aiFetch(_ args: [String: Any], from webView: WKWebView?, reply: @escaping (Any?, String?) -> Void) {
        guard let text = args["url"] as? String, let url = URL(string: text), url.scheme == "https",
              let host = url.host, let provider = Wbe.aiProviders[host] else {
            return reply(nil, "The WikiTree app only sends WBE's requests to the AI providers")
        }
        let method = (args["method"] as? String ?? "GET").uppercased()
        guard method == "GET" || method == "POST" else { return reply(nil, "Method \(method) isn't allowed") }
        askToSend(to: provider, host: host, from: webView) { allowed in
            guard allowed else {
                return reply(nil, String(localized: "You didn't allow WBE to send this to \(provider)."))
            }
            var request = URLRequest(url: url)
            request.httpMethod = method
            for (name, value) in args["headers"] as? [String: Any] ?? [:] {
                request.setValue("\(value)", forHTTPHeaderField: name)
            }
            if method == "POST", let body = args["body"] as? String { request.httpBody = Data(body.utf8) }
            self.aiSession.dataTask(with: request) { data, response, error in
                DispatchQueue.main.async {
                    if let error { return reply(nil, error.localizedDescription) }
                    let status = (response as? HTTPURLResponse)?.statusCode ?? 500
                    let result: [String: Any] = [
                        "status": status,
                        "statusText": HTTPURLResponse.localizedString(forStatusCode: status),
                        "body": String(decoding: data ?? Data(), as: UTF8.self),
                    ]
                    reply(Wbe.json(result), nil)
                }
            }.resume()
        }
    }

    private func askToSend(to provider: String, host: String, from webView: WKWebView?,
                           answer: @escaping (Bool) -> Void) {
        let key = "wbe.ai.allowed.\(host)"
        if UserDefaults.standard.bool(forKey: key) { return answer(true) }
        guard var top = webView?.window?.rootViewController else { return answer(false) }
        while let next = top.presentedViewController, !next.isBeingDismissed { top = next }
        let alert = UIAlertController(
            title: String(localized: "Send to \(provider)?"),
            message: String(localized: "WBE's AI features (Genie, Improve with AI and others) send your question, and details from the WikiTree pages they use, such as names, dates and places of the people on them, to \(provider) with your own API key. \(provider)'s own terms and privacy policy apply.\n\nThe app asks once for each AI provider. To stop, remove your key in WBE's AI Settings."),
            preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: String(localized: "Don't Allow"), style: .cancel) { _ in answer(false) })
        alert.addAction(UIAlertAction(title: String(localized: "Allow"), style: .default) { _ in
            UserDefaults.standard.set(true, forKey: key)
            answer(true)
        })
        top.present(alert, animated: true)
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

    private struct FileError: Error, CustomStringConvertible {
        let description: String
    }

    /// A text file from WBE's folder, for the "file" host call: scripts and data only, never
    /// anything outside the folder.
    private func textFile(_ name: String) throws -> String {
        let path = String(name.split(separator: "?").first ?? "").removingPercentEncoding ?? ""
        guard let folder, !path.isEmpty, ["js", "json", "css"].contains((path as NSString).pathExtension.lowercased())
        else { throw FileError(description: "Not a WBE script or data file: \(name)") }
        let file = folder.appendingPathComponent(path).standardizedFileURL
        guard file.path.hasPrefix(folder.standardizedFileURL.path + "/"),
              let text = try? String(contentsOf: file, encoding: .utf8)
        else { throw FileError(description: "WBE has no file \(path)") }
        return text
    }

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

/// "Ask Genie" on the start screen. Genie is WBE's assistant: it searches WikiTree, answers
/// questions and, with an AI key in WBE's settings, more. It lives on wikitree.com pages, so asking
/// opens a page sheet (see [PageSheet]) and shared/genie.js opens Genie there with the question
/// already sent.
enum Genie {
    /// The profile of the person Genie is to be about, or WikiTree's home page with nobody.
    static func page(for personId: String) -> URL {
        let id = personId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? ""
        return URL(string: id.isEmpty ? "https://www.wikitree.com/" : "https://www.wikitree.com/wiki/" + id)!
    }

    private static let js: String = {
        guard let url = Bundle.main.url(forResource: "genie", withExtension: "js"),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return "" }
        return text
    }()

    /// Called by the page sheet when a page has loaded; "" just opens Genie. `done` gets true once
    /// Genie has opened on the page, false if the page went away first or Genie failed to open.
    /// How it went is logged (it shows in the Simulator's log as "Genie: ...").
    static func ask(_ webView: WKWebView, question: String, done: @escaping (Bool) -> Void = { _ in }) {
        guard !js.isEmpty else { NSLog("Genie: genie.js is missing from the app"); return done(true) }
        webView.evaluateJavaScript(js + "\n;void 0;") { _, error in
            if let error { NSLog("Genie: genie.js failed: \(error)"); return done(false) }
            webView.callAsyncJavaScript("return await window.__wtAskGenie(question);",
                                        arguments: ["question": question], in: nil, in: .page) { result in
                switch result {
                case .success(let note):
                    NSLog("Genie: \(note)")
                    done(!String(describing: note).hasPrefix("failed"))
                case .failure(let error):
                    NSLog("Genie: \(error)")
                    done(false)
                }
            }
        }
    }
}
