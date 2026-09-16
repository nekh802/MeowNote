import SwiftUI
import WidgetKit

// 앱과 위젯이 같이 들여다보는 서랍. 앱이 메모를 저장할 때마다 여기에
// 간추린 내용을 적어 두고, 위젯은 그것만 읽는다.
let appGroup = "group.com.mallang.mallangMemo"
let feedKey = "malang_widget_feed"

// MARK: - 앱이 넘겨주는 내용

struct Line: Decodable, Hashable {
  let text: String
  let checked: Bool
}

struct Note: Decodable, Hashable {
  let title: String
  let bg: String
  let ink: String
  let tint: String
  let line: String
  let cat: String
  let kind: String
  let lines: [Line]
  let done: Int
  let total: Int

  var isCheck: Bool { kind == "checklist" }
  var isHeart: Bool { kind == "hearts" }
}

struct Feed: Decodable {
  let notes: [Note]

  static let empty = Feed(notes: [])

  static func load() -> Feed {
    guard let store = UserDefaults(suiteName: appGroup),
      let raw = store.string(forKey: feedKey),
      let data = raw.data(using: .utf8),
      let feed = try? JSONDecoder().decode(Feed.self, from: data)
    else { return .empty }
    return feed
  }
}

extension Color {
  /// 앱에서 넘어온 #RRGGBB 를 그대로 쓴다. 두 곳의 색이 어긋나지 않는다.
  init(hex: String, fallback: Color = .gray) {
    var value: UInt64 = 0
    let digits = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
    guard digits.count == 6, Scanner(string: digits).scanHexInt64(&value) else {
      self = fallback
      return
    }
    self.init(
      .sRGB,
      red: Double((value >> 16) & 0xFF) / 255,
      green: Double((value >> 8) & 0xFF) / 255,
      blue: Double(value & 0xFF) / 255)
  }
}

/// 고양이 그림. 앱과 같은 PNG 를 위젯에도 넣어 두고 이름으로 찾는다.
func catImage(_ name: String) -> Image? {
  guard
    let url = Bundle.main.url(forResource: name, withExtension: "png"),
    let image = UIImage(contentsOfFile: url.path)
  else { return nil }
  return Image(uiImage: image)
}

// MARK: - 언제 다시 그릴지

struct Entry: TimelineEntry {
  let date: Date
  let feed: Feed
}

struct Provider: TimelineProvider {
  func placeholder(in context: Context) -> Entry {
    Entry(date: Date(), feed: .sample)
  }

  func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
    let feed = Feed.load()
    completion(Entry(date: Date(), feed: feed.notes.isEmpty ? .sample : feed))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
    // 앱이 저장할 때마다 새로 그리라고 알려 주므로, 시간표는 하나면 된다.
    completion(Timeline(entries: [Entry(date: Date(), feed: Feed.load())], policy: .never))
  }
}

extension Feed {
  /// 위젯 고르는 화면에서 보여 줄 견본.
  static let sample = Feed(notes: [
    Note(
      title: "오늘의 메모", bg: "FBDCE5", ink: "6E4F55", tint: "E88BA4",
      line: "EFC2D0", cat: "mochi", kind: "note",
      lines: [
        Line(text: "작은 생각을 적어두기", checked: false),
        Line(text: "고양이 간식 사기", checked: false),
      ], done: 0, total: 2)
  ])
}

// MARK: - 그리기

/// 카드 한 장. 크기에 따라 줄 수와 고양이 크기만 달라진다.
struct NoteCard: View {
  let note: Note
  let lineLimit: Int
  let titleSize: CGFloat
  let bodySize: CGFloat
  let catWidth: CGFloat

  private var ink: Color { Color(hex: note.ink) }

  var body: some View {
    ZStack(alignment: .bottomTrailing) {
      Color(hex: note.bg)

      if let cat = catImage(note.cat) {
        cat
          .resizable()
          .scaledToFit()
          .frame(width: catWidth)
          .padding(.trailing, 6)
          .padding(.bottom, 2)
      }

      VStack(alignment: .leading, spacing: 5) {
        HStack(spacing: 5) {
          Text(note.title)
            .font(.system(size: titleSize, weight: .bold))
            .foregroundColor(ink)
            .lineLimit(1)
          if note.isCheck && note.total > 0 {
            Text("\(note.done)/\(note.total)")
              .font(.system(size: bodySize - 2, weight: .semibold))
              .foregroundColor(Color(hex: note.tint))
          }
        }

        ForEach(Array(note.lines.prefix(lineLimit)), id: \.self) { line in
          HStack(alignment: .firstTextBaseline, spacing: 5) {
            if note.isCheck {
              Image(systemName: line.checked ? "checkmark.square.fill" : "square")
                .font(.system(size: bodySize - 2))
                .foregroundColor(Color(hex: note.tint))
            } else if note.isHeart {
              Image(systemName: "heart.fill")
                .font(.system(size: bodySize - 4))
                .foregroundColor(Color(hex: note.tint))
            }
            Text(line.text)
              .font(.system(size: bodySize))
              .foregroundColor(ink.opacity(line.checked ? 0.45 : 0.9))
              .strikethrough(line.checked, color: ink.opacity(0.45))
              .lineLimit(1)
          }
        }

        if note.lines.isEmpty {
          Text("아직 비어 있어요")
            .font(.system(size: bodySize))
            .foregroundColor(ink.opacity(0.35))
        }

        Spacer(minLength: 0)
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 11)
    }
  }
}

/// 작은 것 하나 — 2×2.
struct SmallView: View {
  let note: Note

  var body: some View {
    NoteCard(note: note, lineLimit: 3, titleSize: 15, bodySize: 12, catWidth: 62)
  }
}

/// 옆으로 긴 것 — 4×2. 오른쪽에 다른 카드 이름을 곁들인다.
struct MediumView: View {
  let feed: Feed

  var body: some View {
    let note = feed.notes[0]
    HStack(spacing: 0) {
      NoteCard(note: note, lineLimit: 4, titleSize: 17, bodySize: 13, catWidth: 74)
      if feed.notes.count > 1 {
        VStack(alignment: .leading, spacing: 7) {
          ForEach(Array(feed.notes.dropFirst().prefix(3)), id: \.self) { other in
            HStack(spacing: 6) {
              Circle().fill(Color(hex: other.tint)).frame(width: 7, height: 7)
              Text(other.title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color(hex: other.ink))
                .lineLimit(1)
            }
          }
          Spacer(minLength: 0)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 13)
        .frame(width: 118, alignment: .leading)
        .background(Color(hex: note.bg).opacity(0.45))
      }
    }
  }
}

/// 큰 것 — 4×4. 카드 두 장을 위아래로 둔다.
struct LargeView: View {
  let feed: Feed

  var body: some View {
    VStack(spacing: 0) {
      NoteCard(
        note: feed.notes[0], lineLimit: 6, titleSize: 19, bodySize: 14, catWidth: 92)
      if feed.notes.count > 1 {
        NoteCard(
          note: feed.notes[1], lineLimit: 5, titleSize: 17, bodySize: 13, catWidth: 78)
      }
    }
  }
}

struct MalangWidgetView: View {
  @Environment(\.widgetFamily) var family
  let entry: Entry

  var body: some View {
    let feed = entry.feed.notes.isEmpty ? Feed.sample : entry.feed
    Group {
      switch family {
      case .systemLarge: LargeView(feed: feed)
      case .systemMedium: MediumView(feed: feed)
      default: SmallView(note: feed.notes[0])
      }
    }
    .widgetBackground(Color(hex: feed.notes[0].bg))
  }
}

extension View {
  /// iOS 17 부터는 위젯 바탕을 이 상자로 알려 줘야 한다.
  @ViewBuilder func widgetBackground(_ color: Color) -> some View {
    if #available(iOS 17.0, *) {
      containerBackground(color, for: .widget)
    } else {
      background(color)
    }
  }
}

// MARK: - 등록

struct MalangWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "MalangWidget", provider: Provider()) { entry in
      MalangWidgetView(entry: entry)
    }
    .configurationDisplayName("말랑 고양이 메모")
    .description("적어 둔 메모를 홈 화면에서 바로 봅니다.")
    .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
  }
}

@main
struct MalangWidgetBundle: WidgetBundle {
  var body: some Widget {
    MalangWidget()
  }
}
