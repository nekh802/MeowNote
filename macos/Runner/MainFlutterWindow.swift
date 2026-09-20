import Cocoa
import FlutterMacOS

/// 바탕화면에 붙여 두는 쪽지 창. 제목줄 없이 카드만 놓이고 다른 창 위에
/// 머문다. 제목줄이 없으니 창을 옮기는 일은 Flutter 쪽 손잡이가 맡는다 —
/// `malang/window` 채널의 `drag` 가 그때 이 창을 끌고 간다.
class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    // 제목줄을 감추고 카드만 남긴다. 닫기·최소화 단추도 함께 숨으므로
    // 창을 닫는 것은 ⌘W, 앱을 끝내는 것은 ⌘Q 다.
    styleMask.insert(.fullSizeContentView)
    titleVisibility = .hidden
    titlebarAppearsTransparent = true
    standardWindowButton(.closeButton)?.isHidden = true
    standardWindowButton(.miniaturizeButton)?.isHidden = true
    standardWindowButton(.zoomButton)?.isHidden = true
    isMovableByWindowBackground = true

    // 다른 창 위에 머문다. 전체 화면으로 쓰는 앱 곁에도 함께 뜬다.
    level = .floating
    collectionBehavior.insert(.fullScreenAuxiliary)

    // 쪽지만 한 크기로 연다. 너무 좁아지면 카드가 찌그러진다.
    minSize = NSSize(width: 320, height: 420)
    setContentSize(NSSize(width: 430, height: 660))

    let channel = FlutterMethodChannel(
      name: "malang/window",
      binaryMessenger: flutterViewController.engine.binaryMessenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "drag" else {
        result(FlutterMethodNotImplemented)
        return
      }
      // 지금 쥐고 있는 마우스 이벤트로 창을 끈다. 놓을 때까지 이 안에서
      // 돈다 — 손잡이를 놓으면 저절로 끝난다.
      if let event = NSApp.currentEvent {
        self?.performDrag(with: event)
      }
      result(nil)
    }

    super.awakeFromNib()
  }
}
