import 'package:flutter_test/flutter_test.dart';
import 'package:wael_app/core/external_links.dart';

void main() {
  group('whatsappUrl', () {
    test('builds an https wa.me URL with the encoded message', () {
      final uri = whatsappUrl(
        supportUrl: 'https://wa.me/201000000000',
        messageText: 'Hello Civil Law',
      );
      // Uri encodes query spaces as `+` (form encoding); WhatsApp reads it.
      expect(uri.toString(), 'https://wa.me/201000000000?text=Hello+Civil+Law');
      expect(uri!.scheme, 'https');
      expect(uri.host, 'wa.me');
      expect(uri.queryParameters['text'], 'Hello Civil Law');
    });

    test('encodes Arabic text', () {
      final uri = whatsappUrl(
        supportUrl: 'https://wa.me/201000000000',
        messageText: 'مرحبًا مادة',
      );
      expect(uri!.queryParameters['text'], 'مرحبًا مادة');
      expect(uri.toString(), contains('?text='));
      expect(uri.toString(), isNot(contains(' ')));
    });

    test('replaces a pre-existing text parameter', () {
      final uri = whatsappUrl(
        supportUrl: 'https://wa.me/201000000000?text=old',
        messageText: 'new',
      );
      expect(uri!.queryParameters['text'], 'new');
    });

    test('rejects non-https, non-wa.me and garbage links', () {
      for (final bad in [
        null,
        '',
        '   ',
        'http://wa.me/201000000000',
        'https://example.com/201000000000',
        'https://wa.me.evil.com/201000000000',
        'not a url',
        'https://api.whatsapp.com/send?phone=201000000000',
      ]) {
        expect(
          whatsappUrl(supportUrl: bad, messageText: 'hi'),
          isNull,
          reason: 'supportUrl: $bad',
        );
      }
    });
  });
}
