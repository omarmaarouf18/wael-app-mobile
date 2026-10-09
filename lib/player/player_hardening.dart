import 'package:youtube_player_iframe/webview.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

/// Everything that limits what the embedded YouTube player can do or show.
/// Kept apart from the engine so each rule can be unit tested without a
/// WebView.
///
/// What this CAN do (verified by tests of the values below, then by hand on a
/// device):
/// - hide the player's own controls, fullscreen button, keyboard shortcuts,
///   annotations and (best effort) caption overlays, and restrict "related
///   videos" to the same channel;
/// - make the whole embed ignore touches (`pointer-events: none`), so the
///   title link, YouTube logo, share, watch-later, "watch on YouTube" and the
///   end-screen cards cannot be tapped, long-pressed or selected;
/// - refuse every navigation the page attempts other than loading the player
///   page and YouTube's own frames, so nothing leaves the embed and no other
///   video can be loaded from inside it;
/// - turn off WebView debugging (done by the package) and context menus.
///
/// What it CANNOT do:
/// - remove YouTube's own passive overlays (the title bar when paused or at
///   the start, the logo in a corner, end-screen suggestions): they are drawn
///   inside YouTube's cross-origin iframe, which we cannot style. They are
///   made inert, and the app masks the title area (see
///   `ProtectedVideoSurface`; the logo is left visible);
/// - stop a determined person with a rooted device, a second camera, or the
///   unlisted URL: protection target is ordinary students (owner decision).
YoutubePlayerParams protectedPlayerParams() => const YoutubePlayerParams(
  showControls: false,
  showFullscreenButton: false,
  enableKeyboard: false,
  showVideoAnnotations: false,
  enableCaption: false,
  strictRelatedVideos: true,
  pointerEvents: PointerEvents.none,
  loop: false,
  playsInline: true,
  privacyEnhancedMode: true,
);

/// The WebView must never leave the embed. Allowed, and nothing else:
/// - the main frame loading the player page itself (the package loads it
///   from a string with `baseUrl` = the embed host, or as `about:blank`);
/// - sub-frames (YouTube's own cross-origin iframe and what it nests) over
///   https or `about:`. iOS (WKWebView) asks the navigation delegate for
///   every frame load, so refusing sub-frames there means the video never
///   loads (TestFlight 2026-10-09). Android only asks for main-frame
///   navigations, so this changes nothing there. Sub-frames cannot take the
///   app anywhere: the page ignores touches (`pointer-events: none`).
/// Every other main-frame request is a link the user (or YouTube's UI)
/// triggered and is refused; so is any non-https scheme (intent:, market:,
/// javascript:, data:) in any frame. The package's own policy would open
/// some links in the browser or load another video id; this replaces it.
NavigationDecision decidePlayerNavigation(NavigationRequest request) {
  final uri = Uri.tryParse(request.url);
  if (uri == null) return NavigationDecision.prevent;
  if (uri.scheme == 'about') return NavigationDecision.navigate;
  if (uri.scheme != 'https') return NavigationDecision.prevent;
  if (!request.isMainFrame) return NavigationDecision.navigate;
  return _isPlayerPage(uri)
      ? NavigationDecision.navigate
      : NavigationDecision.prevent;
}

/// The page the package loads with `loadHtmlString(baseUrl: host)`: the
/// embed host's root, with no path, query or fragment.
bool _isPlayerPage(Uri uri) {
  final host = Uri.parse(protectedPlayerParams().host);
  return uri.host == host.host &&
      (uri.path.isEmpty || uri.path == '/') &&
      !uri.hasQuery &&
      !uri.hasFragment;
}

/// Run after the page loads: no text selection, callouts, context menu, drag,
/// copy or cut anywhere in the page, and no pointer events (defence in depth
/// on top of the `pointer-events` parameter).
const playerHardeningScript = r'''
(function () {
  var style = document.createElement('style');
  style.textContent =
    '*{-webkit-user-select:none!important;user-select:none!important;' +
    '-webkit-touch-callout:none!important;-webkit-tap-highlight-color:transparent!important}' +
    'html,body,iframe{pointer-events:none!important}';
  document.head.appendChild(style);
  ['contextmenu', 'selectstart', 'dragstart', 'copy', 'cut'].forEach(function (name) {
    document.addEventListener(name, function (e) { e.preventDefault(); }, true);
  });
})();
''';
