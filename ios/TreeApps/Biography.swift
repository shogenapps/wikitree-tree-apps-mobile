import AVFoundation
import SwiftUI
import WebKit

/// A WikiTree biography, read aloud: the biography is fetched from the API, its wiki text turned
/// into plain sentences (no markup, no sources), and spoken with the phone's own voice.
enum Biography {
    struct Text {
        let id: String
        let name: String
        let paragraphs: [String]
    }

    enum Failure: Error { case isPrivate, empty, network }

    /// "Beacall-6" from a profile's address on wikitree.com, or nil for any other page.
    static func profileId(_ url: URL?) -> String? {
        guard let url, let host = url.host, host == "wikitree.com" || host.hasSuffix(".wikitree.com"),
              let parts = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        var id = ""
        if parts.path.hasPrefix("/wiki/") {
            id = String(parts.path.dropFirst("/wiki/".count))
        } else if parts.path == "/index.php" {
            id = parts.queryItems?.first { $0.name == "title" }?.value ?? ""
        }
        id = id.replacingOccurrences(of: " ", with: "_")
        return id.range(of: #"^[^:/#?]+-\d+$"#, options: .regularExpression) != nil ? id : nil
    }

    /// Fetch and clean the biography of `id`, with the member's WikiTree login so private
    /// profiles they may see are read too.
    static func fetch(_ id: String) async throws -> Text {
        let cookies = await WKWebsiteDataStore.default().httpCookieStore.allCookies()
            .filter { "api.wikitree.com".hasSuffix($0.domain.trimmingCharacters(in: CharacterSet(charactersIn: "."))) }
        var parts = URLComponents(string: "https://api.wikitree.com/api.php")!
        parts.queryItems = [
            .init(name: "action", value: "getProfile"),
            .init(name: "appId", value: "TreeAppsMobile"),
            .init(name: "bioFormat", value: "wiki"),
            .init(name: "fields", value: "Name,FirstName,RealName,LastNameAtBirth,LastNameCurrent,Bio"),
            .init(name: "key", value: id),
        ]
        var request = URLRequest(url: parts.url!, timeoutInterval: 15)
        if let header = HTTPCookie.requestHeaderFields(with: cookies)["Cookie"] {
            request.setValue(header, forHTTPHeaderField: "Cookie")
        }
        let data: Data
        do {
            let (body, response) = try await URLSession(configuration: .ephemeral).data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw Failure.network }
            data = body
        } catch {
            throw Failure.network
        }
        guard let list = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { throw Failure.network }
        guard let p = list.first?["profile"] as? [String: Any],
              let wiki = (p["bio"] ?? p["Bio"]) as? String else { throw Failure.isPrivate }
        let paragraphs = clean(wiki)
        if paragraphs.isEmpty { throw Failure.empty }
        return Text(id: id, name: name(p) ?? id, paragraphs: paragraphs)
    }

    private static func name(_ p: [String: Any]) -> String? {
        func s(_ k: String) -> String { (p[k] as? String) ?? "" }
        let first = s("RealName").isEmpty ? s("FirstName") : s("RealName")
        let birth = s("LastNameAtBirth"), current = s("LastNameCurrent")
        let last = !current.isEmpty && current != birth && !birth.isEmpty ? "(\(birth)) \(current)" : (birth.isEmpty ? current : birth)
        let name = "\(first) \(last)".trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? nil : name
    }

    // MARK: Wiki text to plain sentences

    private static func re(_ pattern: String, _ options: NSRegularExpression.Options = []) -> NSRegularExpression {
        try! NSRegularExpression(pattern: pattern, options: options)
    }

    private static func replace(_ s: String, _ r: NSRegularExpression, _ with: String) -> String {
        r.stringByReplacingMatches(in: s, range: NSRange(s.startIndex..., in: s), withTemplate: with)
    }

    private static func cut(_ s: String, at r: NSRegularExpression) -> String {
        guard let m = r.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)), let at = Range(m.range, in: s) else { return s }
        return String(s[..<at.lowerBound])
    }

    /// Headings where the biography proper ends: what follows is sources and notes about them.
    private static let endHeading = re(
        #"^\s*=+\s*(sources?|references?|research notes?|acknowledge?ments?|footnotes?|citations?|bibliography)\s*:?\s*=+\s*$"#,
        [.caseInsensitive, .anchorsMatchLines])

    /// Wiki text to paragraphs of plain sentences: everything from the Sources heading (or the
    /// references tag) on is dropped, and so are footnotes, templates, tables, pictures,
    /// categories and tags; links keep only their words.
    static func clean(_ wiki: String) -> [String] {
        var t = wiki.replacingOccurrences(of: "\r\n", with: "\n")
        t = replace(t, re("<!--.*?-->", .dotMatchesLineSeparators), "")
        t = cut(t, at: endHeading)
        t = cut(t, at: re(#"<references\s*/?>"#, .caseInsensitive))
        t = replace(t, re(#"<ref\b[^>]*/>"#, .caseInsensitive), "")
        t = replace(t, re(#"<ref\b[^>]*>.*?</ref\s*>"#, [.caseInsensitive, .dotMatchesLineSeparators]), "")
        // Templates (stickers, research boxes), innermost first so nested ones go too.
        for r in [re(#"\{\{[^{}]*\}\}"#), re(#"\{\|[^{}]*?\|\}"#, .dotMatchesLineSeparators)] {
            while r.firstMatch(in: t, range: NSRange(t.startIndex..., in: t)) != nil { t = replace(t, r, "") }
        }
        // Pictures and categories, whose captions can themselves hold links.
        t = replace(t, re(#"\[\[\s*:?\s*(file|image|category|media)\s*:([^\[\]]|\[\[[^\[\]]*\]\])*\]\]"#, .caseInsensitive), "")
        t = replace(t, re(#"\[\[[^\[\]|]*\|([^\[\]]*)\]\]"#), "$1")
        // A plain link reads as its page name, without a "Space:" style prefix or underscores.
        let link = re(#"\[\[\s*:?([^\[\]]*)\]\]"#)
        while let m = link.firstMatch(in: t, range: NSRange(t.startIndex..., in: t)),
              let whole = Range(m.range, in: t), let inner = Range(m.range(at: 1), in: t) {
            var words = String(t[inner])
            if let colon = words.firstIndex(of: ":") { words = String(words[words.index(after: colon)...]) }
            words = words.replacingOccurrences(of: "_", with: " ").trimmingCharacters(in: CharacterSet(charactersIn: "# "))
            t.replaceSubrange(whole, with: words)
        }
        t = replace(t, re(#"\[(https?:)?//[^\s\]]+\s+([^\]]*)\]"#), "$2")
        t = replace(t, re(#"\[(https?:)?//[^\]]*\]"#), "")
        // Bare addresses, with the brackets around them; an address ends before closing punctuation.
        t = replace(t, re(#"\(\s*https?://[^\s()]*(\([^\s()]*\)[^\s()]*)*\s*\)"#), "")
        t = replace(t, re(#"https?://[^\s\]]*[^\s\]).,;:!?'"]"#), "")
        t = replace(t, re(#"\(\s*[.,;:]?\s*\)"#), "")
        // The note a GEDCOM import leaves, and hand-made footnote marks like [1].
        t = replace(t, re(#"^\s*This person was created (through|by) the import of .*$"#, [.caseInsensitive, .anchorsMatchLines]), "")
        t = replace(t, re(#"\[\d+\]"#), "")
        t = replace(t, re(#"<br\s*/?>"#, .caseInsensitive), "\n")
        t = replace(t, re(#"</?(p|div|li|ul|ol|blockquote|h\d)\b[^>]*>"#, .caseInsensitive), "\n\n")
        t = replace(t, re("<[^>]+>"), "")
        t = replace(t, re("'{2,}"), "")
        t = replace(t, re("__[A-Z]+__"), "")
        t = replace(t, re(#"^-{4,}\s*$"#, .anchorsMatchLines), "")
        t = decodeEntities(t)

        let heading = re(#"^=+\s*(.*?)\s*=+$"#)
        let listMark = re(#"^[*#:;]+\s*"#)
        var paragraphs: [String] = []
        var current = ""
        func flush() {
            var p = replace(current, re(#"\s+"#), " ")
            p = replace(p, re(#"\s+([,.;:!?])"#), "$1").trimmingCharacters(in: .whitespaces)
            if p.contains(where: { $0.isLetter || $0.isNumber }) { paragraphs.append(p) }
            current = ""
        }
        for raw in t.components(separatedBy: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            let range = NSRange(line.startIndex..., in: line)
            if line.isEmpty {
                flush()
            } else if let m = heading.firstMatch(in: line, range: range), let r = Range(m.range(at: 1), in: line) {
                flush()
                let words = line[r].trimmingCharacters(in: .whitespaces)
                // "Biography" itself says nothing; other headings are read as a short line.
                if !words.isEmpty && words.lowercased() != "biography" {
                    current = ".!?:".contains(words.last!) ? words : words + "."
                    flush()
                }
            } else if listMark.firstMatch(in: line, range: range) != nil {
                // List items are read one by one.
                flush()
                current = replace(line, listMark, "")
                flush()
            } else {
                current += " " + line
            }
        }
        flush()
        return paragraphs
    }

    private static func decodeEntities(_ s: String) -> String {
        var t = s
        for (a, b) in [("&nbsp;", " "), ("&ndash;", "–"), ("&mdash;", "—"), ("&quot;", "\""), ("&apos;", "'"), ("&#39;", "'"),
                       ("&lsquo;", "‘"), ("&rsquo;", "’"), ("&ldquo;", "“"), ("&rdquo;", "”"), ("&hellip;", "…"),
                       ("&pound;", "£"), ("&euro;", "€"), ("&cent;", "¢"), ("&copy;", "©"), ("&deg;", "°"),
                       ("&frac12;", "½"), ("&frac14;", "¼"), ("&frac34;", "¾"),
                       ("&lt;", "<"), ("&gt;", ">"), ("&amp;", "&")] {
            t = t.replacingOccurrences(of: a, with: b, options: .caseInsensitive)
        }
        let numeric = re(#"&#([xX]?)([0-9a-fA-F]+);"#)
        while let m = numeric.firstMatch(in: t, range: NSRange(t.startIndex..., in: t)),
              let whole = Range(m.range, in: t), let hex = Range(m.range(at: 1), in: t), let digits = Range(m.range(at: 2), in: t) {
            let char = UInt32(t[digits], radix: t[hex].isEmpty ? 10 : 16).flatMap(UnicodeScalar.init).map(String.init) ?? ""
            t.replaceSubrange(whole, with: char)
        }
        // Any other named entity says nothing; a no-break space is an ordinary space.
        return replace(t, re("&[a-zA-Z]+;"), "").replacingOccurrences(of: "\u{00A0}", with: " ")
    }
}

/// Reads a biography with the phone's own voice, and says what it is doing for the player bar.
@MainActor
final class BioReader: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    enum Phase: Equatable {
        case idle, fetching, reading, paused
        case message(String)
    }

    @Published private(set) var phase = Phase.idle
    @Published private(set) var name = ""

    private let synth = AVSpeechSynthesizer()
    private var last: AVSpeechUtterance?
    private var task: Task<Void, Never>?

    override init() {
        super.init()
        synth.delegate = self
    }

    /// Fetch the biography of `id` and read it, name first.
    func start(_ id: String) {
        stop()
        phase = .fetching
        task = Task {
            do {
                let bio = try await Biography.fetch(id)
                guard !Task.isCancelled else { return }
                read(bio)
            } catch {
                guard !Task.isCancelled else { return }
                switch error as? Biography.Failure {
                case .isPrivate?:
                    phase = .message(String(localized: "This biography is private. Log in to WikiTree to hear it if you are on its Trusted List."))
                case .empty?:
                    phase = .message(String(localized: "This profile has no biography to read yet."))
                default:
                    phase = .message(String(localized: "The biography could not be loaded. Check the connection and try again."))
                }
            }
        }
    }

    private func read(_ bio: Biography.Text) {
        name = bio.name
        // Spoken audio: heard even with the ring switch on silent, and other audio ducks.
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        let voice = AVSpeechSynthesisVoice(language: AVSpeechSynthesisVoice.currentLanguageCode())
        for text in ["\(bio.name)."] + bio.paragraphs {
            let u = AVSpeechUtterance(string: text)
            u.voice = voice
            u.postUtteranceDelay = 0.45
            synth.speak(u)
            last = u
        }
        phase = .reading
    }

    func togglePause() {
        if phase == .paused {
            synth.continueSpeaking()
            phase = .reading
        } else if phase == .reading {
            synth.pauseSpeaking(at: .word)
            phase = .paused
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        last = nil
        if synth.isSpeaking { synth.stopSpeaking(at: .immediate) }
        phase = .idle
        release()
    }

    private func release() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            guard utterance === self.last else { return }
            self.last = nil
            self.phase = .idle
            self.release()
        }
    }
}

/// The bar at the bottom of a profile while its biography is read: who, Pause or Play, Stop.
struct BioPlayerBar: View {
    @ObservedObject var reader: BioReader

    var body: some View {
        if reader.phase != .idle {
            HStack(spacing: 4) {
                Image(systemName: "speaker.wave.2.fill")
                    .foregroundColor(wtAccent)
                    .accessibilityHidden(true)
                Text(status)
                    .font(.subheadline)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if reader.phase == .reading || reader.phase == .paused {
                    Button { reader.togglePause() } label: {
                        Image(systemName: reader.phase == .paused ? "play.fill" : "pause.fill")
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel(reader.phase == .paused ? String(localized: "Play") : String(localized: "Pause"))
                }
                if reader.phase == .fetching {
                    ProgressView().frame(width: 44, height: 44)
                }
                Button { reader.stop() } label: {
                    if case .message = reader.phase {
                        Text("Close").bold().frame(minWidth: 44, minHeight: 44)
                    } else {
                        Image(systemName: "stop.fill").frame(width: 44, height: 44)
                    }
                }
                .accessibilityLabel("Stop reading")
            }
            .tint(wtAccent)
            .padding(.leading, 16)
            .padding(.trailing, 8)
            .padding(.vertical, 4)
            .background(.bar)
            .overlay(alignment: .top) { Divider() }
        }
    }

    private var status: String {
        switch reader.phase {
        case .fetching: return String(localized: "Getting the biography…")
        case .reading: return String(localized: "Reading the biography of \(reader.name)")
        case .paused: return String(localized: "Paused: \(reader.name)")
        case .message(let text): return text
        case .idle: return ""
        }
    }
}
