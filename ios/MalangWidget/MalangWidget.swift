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
  // 예전 판이 적어 둔 내용에는 없을 수 있어 기본값을 둔다.
  var badge: String = ""
  var badgeColor: String = ""

  var isCheck: Bool { kind == "checklist" }
  var isHeart: Bool { kind == "hearts" }

  /// 적어 둔 글이 있는 줄만.
  var written: [Line] { lines.filter { !$0.text.trimmed.isEmpty } }
}

extension String {
  var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}

struct Feed: Decodable {
  let notes: [Note]

  static let empty = Feed(notes: [])

  static func load() -> Feed {
    guard let store = UserDefaults(suiteName: appGroup),
      let raw = store.string(forKey: feedKey),
      let data = raw.data(using: .utf8),
      let feed = try? JSONDecoder().decode(Feed.self, from: data)
    else { return .sample }
    return feed.notes.isEmpty ? .sample : feed
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
    completion(Entry(date: Date(), feed: Feed.load()))
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
        Line(text: "작은 생각 적기", checked: false),
        Line(text: "고양이 간식 사기", checked: false),
      ], done: 0, total: 2, badge: "heart.fill", badgeColor: "EE8F9F"),
    Note(
      title: "하나씩 해볼까", bg: "FCE4C0", ink: "7B6141", tint: "E0A855",
      line: "F1D2A3", cat: "dalgi", kind: "checklist",
      lines: [
        Line(text: "책 읽기", checked: true),
        Line(text: "산책하기", checked: false),
        Line(text: "메모 정리", checked: false),
      ], done: 1, total: 3, badge: "leaf.fill", badgeColor: "86C08A"),
  ])
}

// MARK: - 카드 그리기

/// 위젯 크기마다 달라지는 셈. 한 군데 모아 두면 크기별로 어긋나지 않는다.
struct CardSize {
  let title: CGFloat
  let body: CGFloat
  let row: CGFloat
  let rows: Int
  /// 고양이가 앉는 띠의 높이. 너비가 아니라 높이로 셈해야 어떤 아이를
  /// 앉혀도 띠가 일정하고, 괘선과 겹치지 않는다.
  let cat: CGFloat
  /// 세 마리는 옆으로 길어 같은 자리에 더 낮게 앉는다.
  let trio: CGFloat
  let pad: CGFloat
  /// 고양이가 앉는 쪽.
  let catTrailing: Bool

  static let small = CardSize(
    title: 15, body: 11.5, row: 19, rows: 3, cat: 38, trio: 26, pad: 3,
    catTrailing: true)
  static let medium = CardSize(
    title: 17, body: 13, row: 22, rows: 3, cat: 46, trio: 30, pad: 3,
    catTrailing: true)
  static let large = CardSize(
    title: 19, body: 14, row: 25, rows: 7, cat: 62, trio: 38, pad: 4,
    catTrailing: false)
}

/// 카드 안쪽의 옅은 모눈. 앱 카드와 같은 질감을 준다.
struct GridTexture: View {
  var body: some View {
    Canvas { ctx, size in
      let step: CGFloat = 22
      let ink = GraphicsContext.Shading.color(.white.opacity(0.22))
      var x: CGFloat = step
      while x < size.width {
        ctx.stroke(
          Path { $0.move(to: CGPoint(x: x, y: 0)); $0.addLine(to: CGPoint(x: x, y: size.height)) },
          with: ink, lineWidth: 1)
        x += step
      }
      var y: CGFloat = step
      while y < size.height {
        ctx.stroke(
          Path { $0.move(to: CGPoint(x: 0, y: y)); $0.addLine(to: CGPoint(x: size.width, y: y)) },
          with: ink, lineWidth: 1)
        y += step
      }
    }
  }
}

/// 체크리스트 줄 앞의 네모.
struct CheckBox: View {
  let checked: Bool
  let tint: Color
  let ink: Color
  let side: CGFloat

  var body: some View {
    RoundedRectangle(cornerRadius: side * 0.28)
      .fill(checked ? tint : Color.clear)
      .overlay(
        RoundedRectangle(cornerRadius: side * 0.28)
          .strokeBorder(checked ? tint : ink.opacity(0.55), lineWidth: 1.8)
      )
      .overlay(
        Group {
          if checked {
            Image(systemName: "checkmark")
              .font(.system(size: side * 0.6, weight: .bold))
              .foregroundColor(.white)
          }
        }
      )
      .frame(width: side, height: side)
  }
}

/// 괘선 한 줄. 적은 글이 없으면 줄만 남는다.
struct RuledRow: View {
  let note: Note
  let line: Line?
  let size: CardSize

  private var ink: Color { Color(hex: note.ink) }

  var body: some View {
    VStack(spacing: 0) {
      HStack(alignment: .center, spacing: 6) {
        if let line, !line.text.trimmed.isEmpty {
          if note.isCheck {
            CheckBox(
              checked: line.checked, tint: Color(hex: note.tint), ink: ink,
              side: size.body + 3)
          } else if note.isHeart {
            Image(systemName: "heart.fill")
              .font(.system(size: size.body - 2))
              .foregroundColor(Color(hex: note.tint))
          }
          Text(line.text)
            .font(.system(size: size.body, weight: .medium))
            .foregroundColor(ink.opacity(line.checked ? 0.45 : 0.92))
            .strikethrough(line.checked, color: ink.opacity(0.45))
            .lineLimit(1)
        }
        Spacer(minLength: 0)
      }
      .frame(height: size.row)
      Rectangle()
        .fill(Color(hex: note.line))
        .frame(height: 1.4)
    }
  }
}

/// 카드 한 장. 위젯 한 칸을 그대로 채운다.
struct NoteCard: View {
  let note: Note
  let size: CardSize

  private var ink: Color { Color(hex: note.ink) }
  /// 세 마리는 옆으로 긴 그림이라 한쪽 구석이 아니라 아래 한가운데에 앉는다.
  private var isTrio: Bool { note.cat == "trio" }

  var body: some View {
    ZStack {
      Color(hex: note.bg)
      GridTexture()

      VStack(alignment: .leading, spacing: 0) {
        HStack(spacing: 5) {
          Text(note.title)
            .font(.system(size: size.title, weight: .bold))
            .foregroundColor(ink)
            .lineLimit(1)
          if !note.badge.isEmpty {
            Image(systemName: note.badge)
              .font(.system(size: size.title * 0.62))
              .foregroundColor(Color(hex: note.badgeColor, fallback: Color(hex: note.tint)))
          }
          Spacer(minLength: 0)
          if note.isCheck && note.total > 0 {
            Text("\(note.done)/\(note.total)")
              .font(.system(size: size.body, weight: .semibold))
              .foregroundColor(Color(hex: note.tint))
          }
        }
        .padding(.bottom, 5)

        // 적은 줄을 먼저 놓고, 남는 자리는 빈 괘선으로 채운다.
        let written = note.written
        ForEach(0..<size.rows, id: \.self) { i in
          RuledRow(note: note, line: i < written.count ? written[i] : nil, size: size)
        }

        Spacer(minLength: 0)

        // 고양이는 괘선 아래 제 띠에 앉는다. 겹치지 않으니 글씨를 가리지 않는다.
        if let cat = catImage(note.cat) {
          HStack(spacing: 0) {
            if isTrio || size.catTrailing { Spacer(minLength: 0) }
            cat
              .resizable()
              .scaledToFit()
              .opacity(0.5)
              .frame(height: isTrio ? size.trio : size.cat)
            if isTrio || !size.catTrailing { Spacer(minLength: 0) }
          }
          .frame(height: isTrio ? size.trio : size.cat)
        }
      }
      .padding(size.pad)
    }
  }
}

// MARK: - 홈 화면

struct SmallView: View {
  let note: Note
  var body: some View { NoteCard(note: note, size: .small) }
}

struct MediumView: View {
  let note: Note
  var body: some View { NoteCard(note: note, size: .medium) }
}

struct LargeView: View {
  let note: Note
  var body: some View { NoteCard(note: note, size: .large) }
}

// MARK: - 잠금 화면

/// 잠금 화면은 한 가지 색으로만 그려진다. 사진 대신 선으로 그린 고양이를 쓴다.
struct CatGlyph: View {
  var body: some View {
    GeometryReader { geo in
      let w = geo.size.width
      let h = geo.size.height
      ZStack {
        Path { p in
          p.move(to: CGPoint(x: w * 0.16, y: h * 0.44))
          p.addLine(to: CGPoint(x: w * 0.24, y: h * 0.06))
          p.addLine(to: CGPoint(x: w * 0.48, y: h * 0.26))
          p.move(to: CGPoint(x: w * 0.84, y: h * 0.44))
          p.addLine(to: CGPoint(x: w * 0.76, y: h * 0.06))
          p.addLine(to: CGPoint(x: w * 0.52, y: h * 0.26))
        }
        .stroke(style: StrokeStyle(lineWidth: w * 0.08, lineCap: .round, lineJoin: .round))

        Ellipse()
          .strokeBorder(style: StrokeStyle(lineWidth: w * 0.08))
          .frame(width: w * 0.84, height: h * 0.62)
          .offset(y: h * 0.16)

        HStack(spacing: w * 0.24) {
          Circle().frame(width: w * 0.08, height: w * 0.08)
          Circle().frame(width: w * 0.08, height: w * 0.08)
        }
        .offset(y: h * 0.08)
      }
    }
  }
}

/// 동그라미 — 오늘 해낸 만큼 테두리가 찬다.
struct CircularView: View {
  let note: Note

  var body: some View {
    let ratio = note.total == 0 ? 0 : Double(note.done) / Double(note.total)
    ZStack {
      AccessoryWidgetBackground()
      Circle().stroke(lineWidth: 4).opacity(0.25)
      Circle()
        .trim(from: 0, to: max(0.02, ratio))
        .stroke(style: StrokeStyle(lineWidth: 4, lineCap: .round))
        .rotationEffect(.degrees(-90))
      VStack(spacing: 0) {
        CatGlyph().frame(width: 20, height: 17)
        if note.total > 0 {
          Text("\(note.done)/\(note.total)")
            .font(.system(size: 10, weight: .semibold))
        }
      }
    }
  }
}

/// 직사각형 — 제목과 남은 할 일.
struct RectangularView: View {
  let note: Note

  var body: some View {
    HStack(spacing: 8) {
      CatGlyph().frame(width: 26, height: 23)
      VStack(alignment: .leading, spacing: 2) {
        Text(note.title)
          .font(.system(size: 14, weight: .bold))
          .lineLimit(1)
        Text(summary)
          .font(.system(size: 12))
          .opacity(0.8)
          .lineLimit(1)
      }
      Spacer(minLength: 0)
    }
  }

  private var summary: String {
    let left = note.written.filter { !$0.checked }.map(\.text)
    if left.isEmpty { return note.written.isEmpty ? "오늘도 말랑하게" : "오늘 할 일 다 했어요" }
    return left.prefix(2).joined(separator: " · ")
  }
}

/// 한 줄 — 시계 옆에 작게.
struct InlineView: View {
  let note: Note

  var body: some View {
    let left = note.written.filter { !$0.checked }.count
    Label(
      left > 0 ? "말랑캣 · 오늘 할 일 \(left)개" : "말랑캣 · \(note.title)",
      systemImage: "pawprint.fill")
  }
}

// MARK: - 고르기

struct MalangWidgetView: View {
  @Environment(\.widgetFamily) var family
  let entry: Entry

  var body: some View {
    let notes = entry.feed.notes
    let note = notes[0]
    // 잠금 화면은 할 일이 있는 카드를 먼저 고른다.
    let chore = notes.first(where: { $0.isCheck && $0.total > 0 }) ?? note

    switch family {
    case .accessoryCircular:
      CircularView(note: chore)
    case .accessoryRectangular:
      RectangularView(note: chore)
    case .accessoryInline:
      InlineView(note: chore)
    case .systemLarge:
      LargeView(note: note).widgetBackground(Color(hex: note.bg))
    case .systemMedium:
      MediumView(note: note).widgetBackground(Color(hex: note.bg))
    default:
      SmallView(note: note).widgetBackground(Color(hex: note.bg))
    }
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
    .description("적어 둔 메모를 홈 화면과 잠금 화면에서 바로 봅니다.")
    .supportedFamilies([
      .systemSmall, .systemMedium, .systemLarge,
      .accessoryCircular, .accessoryRectangular, .accessoryInline,
    ])
  }
}

@main
struct MalangWidgetBundle: WidgetBundle {
  var body: some Widget {
    MalangWidget()
  }
}
