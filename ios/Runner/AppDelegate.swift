import Flutter
import QuickLook
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var filesChannel: FlutterMethodChannel?
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
