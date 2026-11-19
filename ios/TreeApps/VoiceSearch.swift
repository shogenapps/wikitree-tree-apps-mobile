import AVFoundation
import Speech
import SwiftUI

// Voice search for the name search: the phone's own speech recognition turns speech into text, a
// few plain rules split the text into name, years and place, and names that sound like someone
// on the member's watchlist (or Saved and Recent) are spelled the way the tree spells them.
// No AI or language model is involved. Mirrors VoiceSearch.kt on Android.

// MARK: What a search asks for

/// A name search, read from what was typed or said: "John Smith, born 1850 in Yorkshire",
/// "Mary Jones 1820-1890", "Jan van der Berg died 1901 in Amsterdam". A first year is the birth,
/// a second the death, unless "born" or "died" says otherwise; "in" (or "at", "from") starts a
/// place. Everything else is the name: its last word is the last name, with "van", "de" and the
/// like before it. A few words in other languages work too ("geboren", "urodzona w").
struct NameSearch: Equatable {
    var names: [String] = []
    var born = ""
    var died = ""
    var bornPlace = ""
    var diedPlace = ""
    /// "about 1850": the years are searched with a wider spread.
    var about = false

    private static let bornWords: Set<String> = [
        "born", "b", "b.", "birth", "geboren", "geb.", "né", "née", "nacido", "nacida", "nato", "nata",
        "urodzony", "urodzona", "urodził", "urodziła", "född", "født", "syntynyt",
    ]
    private static let diedWords: Set<String> = [
        "died", "d", "d.", "death", "dead", "gestorben", "gest.", "overleden", "mort", "morte", "décédé",
        "décédée", "murió", "fallecido", "fallecida", "morto", "morta", "zmarł", "zmarła", "död", "døde", "kuollut",
    ]
    private static let placeWords: Set<String> = ["in", "at", "from", "à", "en", "w", "we", "i"]
    private static let aboutWords: Set<String> = [
        "about", "around", "circa", "ca", "ca.", "c", "c.", "abt", "abt.", "approximately", "um", "ungefähr",
        "environ", "około",
    ]
    private static let joinWords: Set<String> = ["and", "to", "until", "till", "-"]
    private static let particles: Set<String> = [
        "van", "von", "de", "der", "den", "du", "la", "le", "di", "da", "del", "della", "dos", "das", "ten",
        "ter", "op", "st", "st.", "zu",
    ]

    var first: String { names.dropLast(lastCount).joined(separator: " ") }
    var last: String { names.suffix(lastCount).joined(separator: " ") }
    var isEmpty: Bool { names.isEmpty }
    /// A year or place was given as well as the name.
    var hasMore: Bool { !born.isEmpty || !died.isEmpty || !bornPlace.isEmpty || !diedPlace.isEmpty }
    /// The name alone, for the watchlist suggestions while typing.
    var name: String { names.joined(separator: " ") }

    /// How many words the last name takes: the last word and any "van der" before it.
    private var lastCount: Int {
        guard !names.isEmpty else { return 0 }
        var i = names.count - 1
        while i > 0, Self.particles.contains(names[i - 1].lowercased()) { i -= 1 }
        return names.count - i
    }

    private static func trimmed(_ token: Substring) -> String {
        token.trimmingCharacters(in: CharacterSet(charactersIn: ",;:!?\"“”()"))
    }

    private static func year(_ token: String) -> String? {
        var t = trimmed(Substring(token))
        if t.hasSuffix(".") { t.removeLast() }
        if t.hasSuffix("s") { t.removeLast() }
        guard t.count == 4, t.allSatisfy(\.isASCII), let y = Int(t), (1000...2099).contains(y) else { return nil }
        return t
    }

    init() {}

    init(_ text: String) {
        // "1820-1890" is a birth and a death.
        var tokens: [String] = []
        for raw in text.replacingOccurrences(of: "–", with: "-").replacingOccurrences(of: "—", with: "-")
            .split(whereSeparator: \.isWhitespace) {
            let parts = raw.split(separator: "-", omittingEmptySubsequences: false)
            if parts.count == 2, let a = Self.year(String(parts[0])), let b = Self.year(String(parts[1])) {
                tokens += [a, "-", b]
            } else {
                tokens.append(String(raw))
            }
        }
        enum Event { case born, died }
        var pending: Event?
        var place: Event?
        // Words after "born" or "died" that are not a year are a place ("born Leeds").
        var afterEvent = false
        func addPlace(_ word: String, to event: Event) {
            if event == .born {
                bornPlace += bornPlace.isEmpty || bornPlace.hasSuffix(", ") ? word : " " + word
            } else {
                diedPlace += diedPlace.isEmpty || diedPlace.hasSuffix(", ") ? word : " " + word
            }
        }
        for (i, raw) in tokens.enumerated() {
            let word = Self.trimmed(Substring(raw)).lowercased()
            let bare = word.hasSuffix(".") ? String(word.dropLast()) : word
            if let y = Self.year(raw) {
                let event = pending ?? (born.isEmpty ? .born : .died)
                if event == .born, born.isEmpty { born = y } else if died.isEmpty { died = y }
                place = nil
                afterEvent = false
                continue
            }
            // A bare "b" or "d" (or "B.") is "born" or "died" only before a year ("b 1850");
            // otherwise it is more likely part of a name the phone heard in pieces ("Thomas B Cole").
            if bare == "b" || bare == "d" {
                let next = i + 1 < tokens.count ? tokens[i + 1] : nil
                if next.map({ Self.year($0) == nil && !Self.aboutWords.contains(Self.trimmed(Substring($0)).lowercased()) }) ?? true {
                    var initial = Self.trimmed(Substring(raw))
                    if initial.hasSuffix(".") { initial.removeLast() }
                    names.append(initial)
                    continue
                }
            }
            if Self.bornWords.contains(word) || Self.bornWords.contains(bare) {
                pending = .born; place = nil; afterEvent = true; continue
            }
            if Self.diedWords.contains(word) || Self.diedWords.contains(bare) {
                pending = .died; place = nil; afterEvent = true; continue
            }
            if Self.aboutWords.contains(word) { about = true; continue }
            if place == nil, Self.joinWords.contains(word) { continue }
            if Self.placeWords.contains(word), i + 1 < tokens.count {
                if Self.year(tokens[i + 1]) != nil { continue } // "born in 1850"
                let event = pending ?? .born
                if place == nil, event == .born, !bornPlace.isEmpty { bornPlace += ", " }
                if place == nil, event == .died, !diedPlace.isEmpty { diedPlace += ", " }
                place = event
                continue
            }
            if place == nil, afterEvent, !names.isEmpty, let pending { place = pending }
            if let place {
                addPlace(raw, to: place)
                continue
            }
            var name = Self.trimmed(Substring(raw))
            if name.hasSuffix(".") { name.removeLast() }
            if !name.isEmpty { names.append(name) }
        }
        let edge = CharacterSet(charactersIn: " ,.;")
        bornPlace = bornPlace.trimmingCharacters(in: edge)
        diedPlace = diedPlace.trimmingCharacters(in: edge)
    }

    /// The words that join a written-out search, in the app's language. Each is one the parser
    /// above reads back.
    static let joiners: [String: (born: String, died: String, in: String, about: String)] = [
        "en": ("born", "died", "in", "about"),
        "de": ("geboren", "gestorben", "in", "um"),
        "nl": ("geboren", "overleden", "in", "circa"),
        "fr": ("né", "mort", "à", "environ"),
        "es": ("nacido", "fallecido", "en", "circa"),
        "it": ("nato", "morto", "in", "circa"),
        "sv": ("född", "död", "i", "ca."),
    ]

    /// The search written out, to put in the search box: "John Smith, born 1850 in Yorkshire",
    /// with the joining words in the app's language ("geboren 1850 in Bayern").
    var text: String { text(language: Bundle.main.preferredLocalizations.first ?? "en") }

    func text(language: String) -> String {
        let w = Self.joiners[String(language.prefix(2))] ?? Self.joiners["en"]!
        var s = names.joined(separator: " ")
        func part(_ word: String, _ year: String, _ place: String, isBirth: Bool) {
            guard !year.isEmpty || !place.isEmpty else { return }
            s += ", \(word)"
            if !year.isEmpty { s += about && isBirth ? " \(w.about) \(year)" : " \(year)" }
            if !place.isEmpty { s += " \(w.in) \(place)" }
        }
        part(w.born, born, bornPlace, isBirth: true)
        part(w.died, died, diedPlace, isBirth: false)
        return s
    }

    /// The searchPerson parameters beyond the name.
    var queryItems: [URLQueryItem] {
        var items: [URLQueryItem] = []
        if !born.isEmpty { items.append(URLQueryItem(name: "BirthDate", value: "\(born)-01-01")) }
        if !died.isEmpty { items.append(URLQueryItem(name: "DeathDate", value: "\(died)-01-01")) }
        if !born.isEmpty || !died.isEmpty {
            // A year said aloud is rarely exact in the records.
            items.append(URLQueryItem(name: "dateSpread", value: about ? "5" : "2"))
        }
        // WikiTree matches any one word of the place, so "Leeds, Yorkshire" finds everyone in
        // Yorkshire. Only the first part (the town) is sent.
        func town(_ place: String) -> String {
            place.split(separator: ",").first.map { $0.trimmingCharacters(in: .whitespaces) } ?? place
        }
        if !bornPlace.isEmpty { items.append(URLQueryItem(name: "BirthLocation", value: town(bornPlace))) }
        if !diedPlace.isEmpty { items.append(URLQueryItem(name: "DeathLocation", value: town(diedPlace))) }
        return items
    }
}

// MARK: Names that sound alike

/// The names in the member's own tree (watchlist, Saved, Recent), for putting right a name the
/// phone heard a little wrong: "Beecall" sounds like "Beacall", so it becomes "Beacall".
struct NameSounds {
    private var count: [String: Int] = [:]
    /// Folded spelling → the spelling used most in the tree.
    private var spelling: [String: String] = [:]
    private var byKey: [String: [String]] = [:]

    /// For places: accept a spelling further off when it sounds the same ("Wynn" → "Wem").
    private var loose = false

    init(names: [String], loose: Bool = false) {
        self.loose = loose
        var seen: [String: [String: Int]] = [:]
        for name in names {
            for word in name.split(whereSeparator: { $0.isWhitespace || "(),".contains($0) }) {
                let w = String(word)
                let f = Self.fold(w)
                guard f.count >= 2 else { continue }
                seen[f, default: [:]][w, default: 0] += 1
            }
        }
        for (f, spellings) in seen {
            count[f] = spellings.values.reduce(0, +)
            spelling[f] = spellings.max { a, b in a.value != b.value ? a.value < b.value : a.key > b.key }!.key
            byKey[Self.key(f), default: []].append(f)
        }
    }

    var isEmpty: Bool { count.isEmpty }

    /// The most common names, as hints for the recognizer (Apple suggests no more than 100).
    func hints(_ limit: Int = 100) -> [String] {
        count.sorted { a, b in a.value != b.value ? a.value > b.value : a.key < b.key }
            .prefix(limit).compactMap { spelling[$0.key] }
    }

    func knows(_ word: String) -> Bool { count[Self.fold(word)] != nil }

    /// The tree's spelling of a name that sounds like `word`, or nil if none is close.
    func match(_ word: String, joined: Bool = false) -> String? {
        let f = Self.fold(word)
        guard f.count >= 2 else { return nil }
        let key = Self.key(f)
        if let known = spelling[f] {
            // The phone can't hear spelling: a rare spelling in the tree ("Beacoll") gives way to
            // a far more common one that sounds the same ("Beacall").
            guard f.count >= 5 else { return known }
            let mine = count[f] ?? 0
            let common = (byKey[key] ?? [])
                .filter { $0 != f && (count[$0] ?? 0) >= 5 * mine && Self.distance($0, f) <= 2 }
                .max { (count[$0] ?? 0) < (count[$1] ?? 0) }
            return common.flatMap { spelling[$0] } ?? known
        }
        var candidates = byKey[key] ?? []
        // Nothing sounds just the same: try names one sound off ("Bee cold" for "Beacall").
        if candidates.isEmpty, key.count >= 3 {
            candidates = byKey.filter { $0.key.first == key.first && Self.distance($0.key, key) == 1 }.flatMap(\.value)
        }
        let limit = joined || loose ? max(joined ? 4 : 3, f.count * 2 / 3) : max(2, f.count / 3)
        let best = candidates.map { ($0, Self.distance($0, f)) }
            .filter { $0.1 <= limit }
            .min { a, b in a.1 != b.1 ? a.1 < b.1 : (count[a.0] ?? 0) > (count[b.0] ?? 0) }
        return best.flatMap { spelling[$0.0] }
    }

    /// Put the names in a search right. Two or three heard words that together sound like one
    /// name ("B Cole", "Bee Call") are joined first, as long as the first of them is not a name already.
    func correct(_ search: NameSearch) -> NameSearch {
        guard !isEmpty else { return search }
        var out = search
        var words = search.names
        var i = 0
        while i + 1 < words.count {
            if !knows(words[i]) {
                for n in [3, 2] where i + n <= words.count {
                    if let joined = match(words[i..<(i + n)].joined(), joined: true), Self.fold(joined).count >= 4 {
                        words[i] = joined
                        words.removeSubrange((i + 1)..<(i + n))
                        break
                    }
                }
            }
            i += 1
        }
        out.names = words.map { match($0) ?? $0 }
        return out
    }

    /// Put each word of a place right ("Wham" → "Wem"), keeping its commas.
    func correctPlace(_ place: String) -> String {
        guard !isEmpty, !place.isEmpty else { return place }
        var out = ""
        var word = ""
        func flush() {
            if !word.isEmpty { out += match(word) ?? word }
            word = ""
        }
        for c in place {
            if c.isLetter { word.append(c) } else { flush(); out.append(c) }
        }
        flush()
        return out
    }

    /// How many words of a heard search are names from the tree, to choose among alternatives.
    func score(_ search: NameSearch) -> Int { search.names.filter(knows).count }

    /// Lower case, accents taken off, letters only.
    static func fold(_ s: String) -> String {
        var t = s.lowercased()
        for (a, b) in [("ß", "ss"), ("æ", "ae"), ("ø", "o"), ("ł", "l"), ("đ", "d")] {
            t = t.replacingOccurrences(of: a, with: b)
        }
        t = t.folding(options: .diacriticInsensitive, locale: Locale(identifier: "en"))
        return String(t.unicodeScalars.filter { ("a"..."z").contains($0) }.map(Character.init))
    }

    /// A rough key for how a name sounds, in the spirit of Metaphone: letters that sound alike
    /// become one letter and vowels drop out, so "Beacall", "Beecall" and "Bickel" all give "bkl".
    static func key(_ folded: String) -> String {
        var s = folded
        for (a, b) in [("kn", "n"), ("gn", "n"), ("pn", "n"), ("wr", "r"), ("ps", "s"), ("wh", "w"), ("x", "s")]
        where s.hasPrefix(a) {
            s = b + s.dropFirst(a.count)
            break
        }
        for (a, b) in [("sch", "sk"), ("tch", "ch"), ("ph", "f"), ("gh", "g"), ("ck", "k"), ("th", "t"),
                       ("sh", "x"), ("ch", "x"), ("cz", "x"), ("sz", "x"), ("ce", "se"), ("ci", "si"),
                       ("cy", "sy"), ("c", "k"), ("q", "k"), ("x", "ks"), ("z", "s"), ("v", "f"),
                       ("dg", "j"), ("j", "y"),
                       // "m" and "n" are easily misheard for each other.
                       ("n", "m")] {
            s = s.replacingOccurrences(of: a, with: b)
        }
        let chars = Array(s)
        var out = ""
        for (i, c) in chars.enumerated() {
            if c == "w" {
                // A "w" before a vowel sounds like "v"; elsewhere ("Lowe") it is silent.
                if i + 1 < chars.count, "aeiouy".contains(chars[i + 1]) {
                    if out.last != "f" { out.append("f") }
                }
                continue
            }
            if "aeiouyh".contains(c) {
                if i == 0 { out.append("a") }
                continue
            }
            if out.last != c { out.append(c) }
        }
        return out
    }

    static func distance(_ a: String, _ b: String) -> Int {
        let a = Array(a), b = Array(b)
        var d = Array(0...b.count)
        for i in 1...max(a.count, 1) where !a.isEmpty {
            var previous = d[0]
            d[0] = i
            for j in stride(from: 1, through: b.count, by: 1) {
                let t = d[j]
                d[j] = min(d[j] + 1, d[j - 1] + 1, previous + (a[i - 1] == b[j - 1] ? 0 : 1))
                previous = t
            }
        }
        return d[b.count]
    }
}

// MARK: Recognition languages

enum VoiceLanguage {
    /// Languages offered for voice search, besides the phone's own; only those the phone can
    /// recognize are listed.
    static let offered = [
        "en-GB", "en-US", "en-AU", "en-CA", "en-IE", "en-NZ", "en-ZA", "de-DE", "de-AT", "de-CH", "nl-NL",
        "nl-BE", "fr-FR", "fr-CA", "it-IT", "es-ES", "es-MX", "pt-PT", "pt-BR", "sv-SE", "nb-NO", "da-DK",
        "fi-FI", "pl-PL", "cs-CZ", "sk-SK", "hu-HU", "ro-RO", "hr-HR", "uk-UA", "ru-RU", "el-GR", "he-IL",
        "tr-TR", "ja-JP", "zh-CN", "ko-KR",
    ]

    static var chosen: String? {
        get { UserDefaults.standard.string(forKey: "voiceLanguage") }
        set { UserDefaults.standard.set(newValue, forKey: "voiceLanguage") }
    }

    static func available() -> [String] {
        let supported = Set(SFSpeechRecognizer.supportedLocales().map { $0.identifier.replacingOccurrences(of: "_", with: "-") })
        // The phone's own language is already the first choice.
        // Language and region only: the identifier can carry extras such as "@rg=…".
        let phone = [Locale.current.language.languageCode?.identifier, Locale.current.region?.identifier]
            .compactMap { $0 }.joined(separator: "-")
        return offered.filter { supported.contains($0) && $0 != phone }
            .sorted { title($0).localizedCaseInsensitiveCompare(title($1)) == .orderedAscending }
    }

    /// "Polski (Polska)": each language in its own words, so it can be found by its speakers.
    static func title(_ id: String) -> String {
        let locale = Locale(identifier: id)
        return (locale.localizedString(forIdentifier: id) ?? id).capitalized(with: locale)
    }

    static var currentTitle: String { chosen.map(title) ?? String(localized: "Phone's language") }
}

// MARK: Listening

/// Listens through the microphone with the phone's speech recognition until the speaker pauses,
/// then hands over what was heard (every alternative the recognizer offers, best first).
@MainActor
final class VoiceListener: ObservableObject {
    @Published private(set) var listening = false
    /// What has been heard so far, shown while listening.
    @Published private(set) var heard = ""
    /// Why listening did not work, if it did not.
    @Published var note: String?

    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var silence: Timer?
    private var cap: Timer?
    private var done: (([String]) -> Void)?

    func start(hints: [String], done: @escaping ([String]) -> Void) {
        stop()
        note = nil
        heard = ""
        self.done = done
        SFSpeechRecognizer.requestAuthorization { status in
            Task { @MainActor in
                guard status == .authorized else {
                    self.note = String(localized: "Speech recognition is switched off for Tree Apps in the Settings app.")
                    return
                }
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    Task { @MainActor in
                        guard granted else {
                            self.note = String(localized: "The microphone is switched off for Tree Apps in the Settings app.")
                            return
                        }
                        self.begin(hints: hints)
                    }
                }
            }
        }
    }

    private func begin(hints: [String]) {
        let locale = VoiceLanguage.chosen.map(Locale.init(identifier:)) ?? Locale.current
        guard let recognizer = SFSpeechRecognizer(locale: locale) ?? SFSpeechRecognizer(), recognizer.isAvailable else {
            note = String(localized: "Speech recognition is not available just now. Check the connection and try again.")
            return
        }
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.taskHint = .search
        request.contextualStrings = hints
        // Recognized on the phone where it can be; otherwise Apple's speech service does it.
        if recognizer.supportsOnDeviceRecognition { request.requiresOnDeviceRecognition = true }
        if #available(iOS 16, *) { request.addsPunctuation = false }
        self.request = request

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.record, mode: .measurement, options: [.duckOthers])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            guard format.sampleRate > 0 else { throw CocoaError(.featureUnsupported) }
            input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
                request.append(buffer)
            }
            engine.prepare()
            try engine.start()
        } catch {
            finishAudio()
            note = String(localized: "The microphone could not be used just now.")
            return
        }
        listening = true
        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            let texts = result?.transcriptions.map(\.formattedString) ?? []
            let isFinal = result?.isFinal ?? false
            let failed = error != nil
            Task { @MainActor in self?.update(texts, final: isFinal, failed: failed) }
        }
        // Stop by itself after a long while, in case nobody speaks.
        cap = Timer.scheduledTimer(withTimeInterval: 15, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.request?.endAudio() }
        }
    }

    private func update(_ texts: [String], final: Bool, failed: Bool) {
        guard listening else { return }
        if let best = texts.first { heard = best }
        if final || failed {
            let result = texts.isEmpty && !heard.isEmpty ? [heard] : texts
            let callback = done
            stop()
            if result.isEmpty {
                note = failed && heard.isEmpty ? String(localized: "Nothing was heard. Tap the microphone and say a name.") : nil
            } else {
                callback?(result)
            }
            return
        }
        // A pause after something was said ends it.
        silence?.invalidate()
        silence = Timer.scheduledTimer(withTimeInterval: 1.6, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.request?.endAudio() }
        }
    }

    /// Stop listening now and keep what was heard (it is handed over as usual).
    func finish() {
        guard listening else { return }
        finishAudio()
        request?.endAudio()
    }

    /// Stop listening and drop what was heard.
    func stop() {
        task?.cancel()
        task = nil
        request = nil
        done = nil
        listening = false
        finishAudio()
    }

    private func finishAudio() {
        silence?.invalidate()
        cap?.invalidate()
        if engine.isRunning { engine.stop() }
        engine.inputNode.removeTap(onBus: 0)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

/// The microphone button beside the search box. A tap listens; a long press (or the menu while
/// listening) chooses the language.
struct VoiceButton: View {
    @ObservedObject var listener: VoiceListener
    let start: () -> Void
    @State private var language = VoiceLanguage.chosen

    var body: some View {
        Menu {
            Section("Voice search language") {
                pick(nil, String(localized: "\(VoiceLanguage.title(Locale.current.identifier)) (phone)"))
                ForEach(VoiceLanguage.available(), id: \.self) { pick($0, VoiceLanguage.title($0)) }
            }
        } label: {
            Image(systemName: listener.listening ? "mic.fill" : "mic")
                .font(.system(size: 20))
                .foregroundStyle(listener.listening ? Color.red : wtAccent)
                .frame(width: 34, height: 34)
                .contentShape(Rectangle())
                .accessibilityLabel(listener.listening ? Text("Stop listening") : Text("Search by voice"))
                .accessibilityHint("Touch and hold to choose the language")
        } primaryAction: {
            if listener.listening { listener.finish() } else { start() }
        }
    }

    private func pick(_ id: String?, _ title: String) -> some View {
        Button {
            VoiceLanguage.chosen = id
            language = id
            if listener.listening { start() }
        } label: {
            if language == id { Label(title, systemImage: "checkmark") } else { Text(title) }
        }
    }
}
