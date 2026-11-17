import SwiftUI
import WidgetKit

/// The Anniversaries home-screen widget: people on the member's watchlist who were born or died
/// on this day. It reads the list the app stored (see Shared/Birthdays.swift) and never goes online.
/// (Its kind stays "BirthdayWidget" so widgets already placed keep working.)
struct BirthdayEntry: TimelineEntry {
    let date: Date
    let list: [Anniversary]
    let loaded: Bool
}

struct BirthdayProvider: TimelineProvider {
    func placeholder(in context: Context) -> BirthdayEntry {
        BirthdayEntry(date: Date(), list: Self.sample, loaded: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (BirthdayEntry) -> Void) {
        // The widget gallery shows made-up people rather than an empty widget.
        let entry = entries(days: 1)[0]
        completion(context.isPreview && entry.list.isEmpty ? placeholder(in: context) : entry)
    }

    /// One entry per day for the week ahead, each starting at midnight, so the widget changes
    /// with the date without the app being opened.
    func getTimeline(in context: Context, completion: @escaping (Timeline<BirthdayEntry>) -> Void) {
        completion(Timeline(entries: entries(days: 7), policy: .atEnd))
    }

    private func entries(days: Int) -> [BirthdayEntry] {
        let people = WatchlistFile.read()
        let loaded = WatchlistFile.fetchedAt != nil
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<days).compactMap { ahead in
            guard let day = calendar.date(byAdding: .day, value: ahead, to: today) else { return nil }
            return BirthdayEntry(date: ahead == 0 ? Date() : day,
                                 list: WatchlistFile.anniversaries(on: day, among: people), loaded: loaded)
        }
    }

    private static let sample: [Anniversary] = {
        let year = Calendar.current.component(.year, from: Date())
        func a(_ name: String, _ kind: Anniversary.Kind, _ ago: Int) -> Anniversary {
            Anniversary(person: Relative(id: name, name: name, birth: "", dates: ""), kind: kind, year: year - ago)
        }
        return [a("Mary Ashworth", .birth, 212), a("John Ashworth", .death, 175), a("Ellen Pike", .birth, 150),
                a("William Pike", .death, 98)]
    }()
}

/// WikiTree's colours, as in the app.
private enum Palette {
    static let green = Color(red: 0x25 / 255, green: 0x42 / 255, blue: 0x2D / 255)
    static let gold = Color(red: 0xF2 / 255, green: 0xC1 / 255, blue: 0x4E / 255)
    static let tan = Color(red: 0xF7 / 255, green: 0xF6 / 255, blue: 0xF0 / 255)
    static let ink = Color(red: 0x1F / 255, green: 0x1F / 255, blue: 0x1F / 255)
    static let muted = Color(red: 0x6B / 255, green: 0x6B / 255, blue: 0x6B / 255)
    static let deathFill = Color(red: 0xDD / 255, green: 0xDB / 255, blue: 0xD3 / 255)
    static let deathInk = Color(red: 0x4A / 255, green: 0x4A / 255, blue: 0x4A / 255)
}

/// A small page off a calendar: the month on a gold band over the day.
private struct DayTile: View {
    let date: Date
    let size: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            Text(date.formatted(.dateTime.month(.abbreviated)).uppercased())
                .font(.system(size: size * 0.22, weight: .bold))
                .foregroundColor(Palette.green)
                .frame(maxWidth: .infinity)
                .frame(height: size * 0.32)
                .background(Palette.gold)
            Text(date.formatted(.dateTime.day()))
                .font(.system(size: size * 0.42, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: size, height: size)
        .background(Palette.green)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
    }
}

/// "b." on green for a birth, "d." on grey for a death.
private struct KindBadge: View {
    let kind: Anniversary.Kind

    var body: some View {
        Text(kind == .birth ? "b." : "d.")
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundColor(kind == .birth ? Palette.gold : Palette.deathInk)
            .frame(width: 20, height: 20)
            .background(Circle().fill(kind == .birth ? Palette.green : Palette.deathFill))
            .accessibilityLabel(kind == .birth ? "Born" : "Died")
    }
}

/// "185 yrs", on gold for every 25th.
private struct YearsChip: View {
    let item: Anniversary
    let date: Date

    var body: some View {
        let years = item.years(on: date)
        let milestone = item.isMilestone(on: date)
        Text("\(years) yrs")
            .font(.system(size: 10, weight: milestone ? .bold : .medium))
            .foregroundColor(milestone ? Palette.green : Palette.muted)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(milestone ? Palette.gold : Palette.deathFill.opacity(0.5)))
            .fixedSize()
    }
}

struct BirthdayWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: BirthdayEntry

    private var rows: Int {
        switch family {
        case .systemLarge: return 8
        case .systemMedium: return 4
        default: return 3
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: family == .systemSmall ? 6 : 8) {
            header
            if !entry.loaded {
                Text("Open WikiTree Tree Apps and load your watchlist.").font(.caption).foregroundColor(Palette.muted)
            } else if entry.list.isEmpty {
                Text("No births or deaths on your watchlist today.").font(.caption).foregroundColor(Palette.muted)
            } else {
                // The last row makes way for "and N more" when the list is longer than the widget.
                let shown = entry.list.count > rows ? rows - 1 : entry.list.count
                VStack(alignment: .leading, spacing: family == .systemLarge ? 8 : 5) {
                    ForEach(WatchlistFile.pick(entry.list, shown)) { row($0) }
                    if shown < entry.list.count {
                        Text("and \(entry.list.count - shown) more")
                            .font(.caption2.weight(.medium)).foregroundColor(Palette.muted)
                            .padding(.leading, family == .systemSmall ? 0 : 28)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .foregroundColor(Palette.ink)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .modifier(WidgetBackground(color: Palette.tan))
    }

    private var header: some View {
        HStack(spacing: 8) {
            DayTile(date: entry.date, size: family == .systemSmall ? 34 : 38)
            VStack(alignment: .leading, spacing: 1) {
                Text("Anniversaries").font(.subheadline.weight(.bold)).foregroundColor(Palette.green)
                    .lineLimit(1).minimumScaleFactor(0.8)
                Text(!entry.loaded || entry.list.isEmpty ? WatchlistFile.dayLabel(entry.date)
                     : family == .systemSmall ? WatchlistFile.shortSummary(entry.list) : WatchlistFile.summary(entry.list))
                    .font(.caption2).foregroundColor(Palette.muted).lineLimit(1)
            }
        }
    }

    @ViewBuilder private func row(_ item: Anniversary) -> some View {
        switch family {
        case .systemSmall:
            HStack(spacing: 6) {
                KindBadge(kind: item.kind)
                Text(item.person.name).font(.caption).lineLimit(1).minimumScaleFactor(0.8)
            }
        case .systemLarge:
            HStack(spacing: 8) {
                KindBadge(kind: item.kind)
                VStack(alignment: .leading, spacing: 0) {
                    Text(item.person.name).font(.subheadline.weight(.medium)).lineLimit(1)
                    Text(item.kind == .birth ? "Born \(String(item.year))" : "Died \(String(item.year))")
                        .font(.caption).foregroundColor(Palette.muted)
                }
                Spacer(minLength: 4)
                YearsChip(item: item, date: entry.date)
            }
        default:
            HStack(spacing: 8) {
                KindBadge(kind: item.kind)
                Text(item.person.name).font(.caption.weight(.medium)).lineLimit(1).minimumScaleFactor(0.85)
                Spacer(minLength: 4)
                Text(String(item.year)).font(.caption).foregroundColor(Palette.muted)
                YearsChip(item: item, date: entry.date)
            }
        }
    }
}

/// iOS 17 draws the widget's background itself; earlier versions take it from the view.
private struct WidgetBackground: ViewModifier {
    let color: Color

    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content.containerBackground(color, for: .widget)
        } else {
            content.padding().background(color)
        }
    }
}

@main
struct BirthdayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "BirthdayWidget", provider: BirthdayProvider()) { entry in
            BirthdayWidgetView(entry: entry)
        }
        .configurationDisplayName("Anniversaries")
        .description("People on your WikiTree watchlist who were born or died on this day.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
