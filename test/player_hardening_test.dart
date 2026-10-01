import 'package:flutter_test/flutter_test.dart';
import 'package:youtube_player_iframe/webview.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import 'package:wael_app/player/player_hardening.dart';
import 'package:wael_app/widgets/player_controls.dart';

void main() {
  group('protectedPlayerParams', () {
    final params = protectedPlayerParams();
    final map = params.toMap();

    test('hides the embed\'s own controls, fullscreen button and keys', () {
      expect(params.showControls, isFalse);
      expect(map['controls'], 0);
      expect(params.showFullscreenButton, isFalse);
      expect(map['fs'], 0);
      expect(params.enableKeyboard, isFalse);
      expect(map['disablekb'], 1);
    });

    test('no annotations or caption overlays, related videos limited', () {
      expect(map['iv_load_policy'], 3);
      expect(map['cc_load_policy'], 0);
      // rel=0: related videos only from the same channel (YouTube offers no
      // way to remove them entirely; the end screen is covered by the app).
      expect(map['rel'], 0);
    });

    test('the embed ignores every pointer event', () {
      expect(params.pointerEvents, PointerEvents.none);
    });

    test('plays inline, does not loop, uses the privacy-enhanced host', () {
      expect(map['playsinline'], 1);
      expect(map['loop'], 0);
      expect(params.host, 'https://www.youtube-nocookie.com');
      expect(params.privacyEnhancedMode, isTrue);
    });

    test('autoplays (the app starts the video after the play check)', () {
      expect(map['autoplay'], 1);
    });
  });

  group('decidePlayerNavigation', () {
    NavigationRequest request(String url, {bool main = true}) =>
        NavigationRequest(url: url, isMainFrame: main);

    test('prevents every navigation, whatever the URL', () {
      for (final url in [
        'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
        'https://www.youtube.com/watch?v=dQw4w9WgXcQ&feature=emb_rel_end',
        'https://youtu.be/dQw4w9WgXcQ',
        'https://www.youtube-nocookie.com/embed/dQw4w9WgXcQ',
        'https://www.youtube.com/channel/UC123?feature=emb_title',
        'https://www.youtube.com/watch?v=x&feature=emb_logo',
        'https://www.facebook.com/sharer.php?u=x',
        'https://twitter.com/intent/tweet',
        'https://example.com/',
        'intent://youtube.com/#Intent;scheme=https;end',
        'market://details?id=com.google.android.youtube',
        'javascript:alert(1)',
        'data:text/html,<h1>x</h1>',
        'about:blank',
        '',
      ]) {
        expect(
          decidePlayerNavigation(request(url)),
          NavigationDecision.prevent,
          reason: url,
        );
      }
    });

    test('sub-frame navigations are prevented too', () {
      expect(
        decidePlayerNavigation(
          request('https://www.youtube.com/', main: false),
        ),
        NavigationDecision.prevent,
      );
    });
  });

  group('playerHardeningScript', () {
    test('blocks selection, callouts, context menu, drag, copy and cut', () {
      expect(playerHardeningScript, contains('user-select:none'));
      expect(playerHardeningScript, contains('-webkit-touch-callout:none'));
      for (final event in [
        'contextmenu',
        'selectstart',
        'dragstart',
        'copy',
        'cut',
      ]) {
        expect(playerHardeningScript, contains("'$event'"));
      }
      expect(playerHardeningScript, contains('preventDefault'));
    });

    test('also disables pointer events on the page and the iframe', () {
      expect(playerHardeningScript, contains('pointer-events:none'));
      expect(playerHardeningScript, contains('iframe'));
    });
  });

  test('formatPlayerTime', () {
    expect(formatPlayerTime(Duration.zero), '00:00');
    expect(formatPlayerTime(const Duration(seconds: 65)), '01:05');
    expect(
      formatPlayerTime(const Duration(hours: 1, minutes: 2, seconds: 3)),
      '1:02:03',
    );
  });
}
