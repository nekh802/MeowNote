import Flutter
import UIKit
import WidgetKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  /// 앱과 위젯이 같이 들여다보는 서랍.
  private let appGroup = "group.com.mallang.mallangMemo"
  private let feedKey = "malang_widget_feed"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    registerWidgetChannel(engineBridge.pluginRegistry)
  }

  /// 홈 화면 위젯에 보여 줄 내용을 넘겨받는 통로. 플러그인을 하나 더
  /// 들이지 않고, 공유 서랍에 적고 다시 그리라고 알리기만 한다.
  private func registerWidgetChannel(_ registry: FlutterPluginRegistry) {
    guard let messenger = registry.registrar(forPlugin: "MalangWidgetBridge")?.messenger()
    else { return }
    let channel = FlutterMethodChannel(name: "malang/widget", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self, call.method == "publish", let json = call.arguments as? String else {
        result(FlutterMethodNotImplemented)
        return
      }
      UserDefaults(suiteName: self.appGroup)?.set(json, forKey: self.feedKey)
      if #available(iOS 14.0, *) {
        WidgetCenter.shared.reloadAllTimelines()
      }
      result(nil)
    }
  }
}
