import Flutter
import QuickLook
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var filesChannel: FlutterMethodChannel?
  private var secureScreenChannels: (FlutterMethodChannel, FlutterEventChannel, CaptureStreamHandler)?
  private let pdfPreview = PdfPreviewSource()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "WaelFilesChannel") {
      let channel = FlutterMethodChannel(
        name: "com.wael.app/files", binaryMessenger: registrar.messenger())
      channel.setMethodCallHandler { [weak self] call, result in
        guard let self = self else {
          result("failed")
          return
        }
        self.handleFiles(call, result: result)
      }
      filesChannel = channel
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "WaelSecureScreen") {
      secureScreenChannels = SecureScreenCapture.register(with: registrar.messenger())
    }
  }

  // Same contract as MainActivity.kt: "open" / "share" a cached PDF and
  // answer "opened", "no_app" or "failed". Open uses the system Quick Look
  // viewer (it has its own share button); share uses the system share sheet.
  // Only files under <Caches>/pdfs (getApplicationCacheDirectory) are exposed.
  private func handleFiles(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any]
    guard let path = args?["path"] as? String, let file = pdfUnderCache(path),
      let presenter = topViewController()
    else {
      result("failed")
      return
    }
    switch call.method {
    case "open":
      pdfPreview.item = PdfPreviewItem(url: file, title: args?["title"] as? String)
      let preview = QLPreviewController()
      preview.dataSource = pdfPreview
      presenter.present(preview, animated: true)
      result("opened")
    case "share":
      let sheet = UIActivityViewController(activityItems: [file], applicationActivities: nil)
      if let popover = sheet.popoverPresentationController {
        popover.sourceView = presenter.view
        popover.sourceRect = CGRect(
          x: presenter.view.bounds.midX, y: presenter.view.bounds.midY, width: 0, height: 0)
        popover.permittedArrowDirections = []
      }
      presenter.present(sheet, animated: true)
      result("opened")
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  /// The file, if it exists inside <Caches>/pdfs (symlinks resolved, so `..`
  /// and links cannot escape).
  private func pdfUnderCache(_ path: String) -> URL? {
    guard
      let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
    else { return nil }
    let root = caches.appendingPathComponent("pdfs").resolvingSymlinksInPath().standardizedFileURL
    let file = URL(fileURLWithPath: path).resolvingSymlinksInPath().standardizedFileURL
    guard file.path.hasPrefix(root.path + "/") else { return nil }
    var isDir: ObjCBool = false
    guard FileManager.default.fileExists(atPath: file.path, isDirectory: &isDir), !isDir.boolValue
    else { return nil }
    return file
  }

  private func topViewController() -> UIViewController? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
    let window = scene?.windows.first { $0.isKeyWindow } ?? scene?.windows.first
    var top = window?.rootViewController
    while let presented = top?.presentedViewController { top = presented }
    return top
  }
}

private final class PdfPreviewItem: NSObject, QLPreviewItem {
  let previewItemURL: URL?
  let previewItemTitle: String?
  init(url: URL, title: String?) {
    previewItemURL = url
    previewItemTitle = title
  }
}

private final class PdfPreviewSource: NSObject, QLPreviewControllerDataSource {
  var item: PdfPreviewItem?
  func numberOfPreviewItems(in controller: QLPreviewController) -> Int { item == nil ? 0 : 1 }
  func previewController(_ controller: QLPreviewController, previewItemAt index: Int)
    -> QLPreviewItem
  {
    item!
  }
}

/// Screen-capture state for the protected video player (owner decision
/// 2026-10-12: recording protection covers iOS too). iOS cannot block
/// recording the way Android's FLAG_SECURE does, so the app detects it and
/// the Dart player covers and pauses the video while the screen is captured
/// (screen recording, AirPlay / external-display mirroring, QuickTime
/// capture). Screenshots cannot be prevented or blanked on iOS; that is a
/// documented limit (docs/frontend/VIDEO_PLAYER.md).
///
/// Channels (same names as the Dart side, lib/services/secure_screen.dart):
/// - method `com.wael.app/secure_screen`: `enable` / `disable` answer nil
///   (they prove the channel exists; there is no window flag to set on iOS),
///   `isCaptured` answers a Bool;
/// - event `com.wael.app/secure_screen/capture`: a Bool now and on every
///   change.
enum SecureScreenCapture {
  static let methodChannelName = "com.wael.app/secure_screen"
  static let eventChannelName = "com.wael.app/secure_screen/capture"

  static func register(with messenger: FlutterBinaryMessenger) -> (
    FlutterMethodChannel, FlutterEventChannel, CaptureStreamHandler
  ) {
    let method = FlutterMethodChannel(name: methodChannelName, binaryMessenger: messenger)
    method.setMethodCallHandler { call, result in
      switch call.method {
      case "enable", "disable":
        result(nil)
      case "isCaptured":
        result(isCaptured())
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    let events = FlutterEventChannel(name: eventChannelName, binaryMessenger: messenger)
    let handler = CaptureStreamHandler()
    events.setStreamHandler(handler)
    return (method, events, handler)
  }

  /// The foreground window scene, else any connected one.
  static func activeScene() -> UIWindowScene? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    return scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
  }

  /// True while the screen is recorded, mirrored or captured. iOS 17+ reads
  /// the scene's `sceneCaptureState` (`isCaptured` is deprecated there);
  /// older systems read the scene screen's `isCaptured`. No scene at all
  /// answers true: fail closed, the player then shows its cover.
  static func isCaptured() -> Bool {
    guard let scene = activeScene() else { return true }
    if #available(iOS 17.0, *) {
      return scene.traitCollection.sceneCaptureState == .active
    }
    return scene.screen.isCaptured
  }
}

/// Sends the capture state when Dart listens and on every change:
/// `UIScreen.capturedDidChangeNotification` on every iOS version, plus the
/// scene's `sceneCaptureState` trait on iOS 17+.
final class CaptureStreamHandler: NSObject, FlutterStreamHandler {
  private var sink: FlutterEventSink?
  private var observer: NSObjectProtocol?
  private weak var observedScene: UIWindowScene?
  private var traitRegistration: Any?

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
    -> FlutterError?
  {
    sink = events
    observer = NotificationCenter.default.addObserver(
      forName: UIScreen.capturedDidChangeNotification, object: nil, queue: .main
    ) { [weak self] _ in
      self?.emit()
    }
    if #available(iOS 17.0, *), let scene = SecureScreenCapture.activeScene() {
      observedScene = scene
      traitRegistration = scene.registerForTraitChanges([UITraitSceneCaptureState.self]) {
        [weak self] (_: UIWindowScene, _: UITraitCollection) in
        self?.emit()
      }
    }
    emit()
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    if let observer = observer {
      NotificationCenter.default.removeObserver(observer)
    }
    observer = nil
    if #available(iOS 17.0, *),
      let registration = traitRegistration as? UITraitChangeRegistration
    {
      observedScene?.unregisterForTraitChanges(registration)
    }
    traitRegistration = nil
    observedScene = nil
    sink = nil
    return nil
  }

  private func emit() {
    sink?(SecureScreenCapture.isCaptured())
  }
}
