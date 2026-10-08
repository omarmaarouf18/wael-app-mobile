import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wael_app/core/error_messages.dart';
import 'package:wael_app/l10n/app_localizations.dart';

/// Store-safety rules (owner decision 2026-10-08, SPEC D3 amendment).
///
/// The app may show a subject's price (the server-sent `price` + `currency`,
/// rendered only by the allowlisted label and format helper), but it never
/// shows a payment ACTION: no pay/buy/purchase/refund wording, no payment
/// methods, no payment links. Activation stays with the center/support over
/// WhatsApp. Google Play "consumption-only" reason: content may be bought
/// outside the app, but the app must not lead users to an outside payment
/// method.
///
/// The backend Go notification store-safety test is the counterpart for the
/// server (notifications still never mention price); it is untouched.

// Arabic payment-action words: plain substring match (Arabic has no case,
// and \b word boundaries do not cross Arabic letters).
const _paymentArabic = [
  'دفع',
  'ادفع',
  'شراء',
  'اشتري',
  'استرداد',
  'اشتراك مدفوع',
  'فودافون كاش',
  'محفظة',
];

// Latin payment words with no innocent carrier in this codebase:
// case-insensitive substring match.
const _paymentLatinLoose = [
  'payment',
  'purchase',
  'refund',
  'instapay',
  'wallet',
];

// Short Latin words: word boundaries, so 'display' never counts as 'pay'.
final _paymentLatinBounded = [
  RegExp(r'\bpay\b', caseSensitive: false),
  RegExp(r'\bbuy\b', caseSensitive: false),
];

bool hasPaymentWord(String text) {
  for (final word in _paymentArabic) {
    if (text.contains(word)) return true;
  }
  final lower = text.toLowerCase();
  for (final word in _paymentLatinLoose) {
    if (lower.contains(word)) return true;
  }
  for (final pattern in _paymentLatinBounded) {
    if (pattern.hasMatch(text)) return true;
  }
  return false;
}

// Price words (owner decision 2026-10-08): allowed only where
// [_priceLiteralAllowlist] says, never anywhere else.

/// Files whose string literals may name a price word, and which words each
/// may use: the l10n price label, the format helper, and the API wire keys
/// the models parse (not user-facing).
const _priceLiteralAllowlist = {
  'lib/l10n/app_localizations.dart': {'سعر', 'price'},
  'lib/core/price_format.dart': {'ج.م', 'EGP'},
  'lib/models/academy_catalog.dart': {'price'},
  'lib/models/app_config.dart': {'price'},
};

/// Lines that are never user-facing (imports, exports, parts): file names
/// such as `subject_price.dart` must not trip the scan.
final _nonUiLine = RegExp(r'^\s*(import|export|part)\b');

/// Price words found in [literal] (`price`/`EGP` match case-insensitively).
List<String> priceWordsIn(String literal) {
  final hits = <String>[];
  for (final word in ['سعر', 'ج.م', 'جنيه']) {
    if (literal.contains(word)) hits.add(word);
  }
  final lower = literal.toLowerCase();
  for (final word in ['price', 'egp']) {
    if (lower.contains(word)) hits.add(word == 'egp' ? 'EGP' : word);
  }
  return hits;
}

bool hasPriceWord(String text) => priceWordsIn(text).isNotEmpty;

void main() {
  test('word-boundary guard: pay matches standalone pay, not display', () {
    expect(hasPaymentWord('Pay now'), isTrue);
    expect(hasPaymentWord('display the price'), isFalse);
    expect(hasPaymentWord('replay the video'), isFalse);
    expect(hasPaymentWord('payload too large'), isFalse);
    expect(hasPaymentWord('ادفع الآن'), isTrue);
    expect(hasPaymentWord('اشتري المادة'), isTrue);
    expect(hasPaymentWord('اشتراك مدفوع'), isTrue);
    expect(hasPaymentWord('فودافون كاش'), isTrue);
    expect(hasPaymentWord('المحفظة'), isTrue);
    expect(hasPaymentWord('InstaPay'), isTrue);
  });

  group('Store-safety l10n scan', () {
    test(
      'no payment-action words appear in app_localizations string literals',
      () {
        final file = File('lib/l10n/app_localizations.dart');
        expect(file.existsSync(), isTrue);

        final lines = file.readAsLinesSync();
        final violations = <String>[];

        for (var i = 0; i < lines.length; i++) {
          final line = lines[i].trim();
          // Ignore comments
          if (line.startsWith('//') ||
              line.startsWith('///') ||
              line.startsWith('*')) {
            continue;
          }

          if (hasPaymentWord(line)) {
            violations.add('Line ${i + 1}: payment wording -> "$line"');
          }
        }

        expect(
          violations,
          isEmpty,
          reason:
              'Store safety rule violated! Strings must never mention a payment action.',
        );
      },
    );

    test(
      'no payment-action words appear in string literals across all lib/ dart files',
      () {
        final libDir = Directory('lib');
        expect(libDir.existsSync(), isTrue);

        final dartFiles = libDir
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'));

        final violations = <String>[];
        final stringLiteralRegex = RegExp(
          r"'([^'\\]*(?:\\.[^'\\]*)*)'|"
          r'"([^"\\]*(?:\\.[^"\\]*)*)"',
        );

        // Backend wire protocol / DTO mapping fields that are not user-facing
        const wireAllowlist = {
          'lib/screens/notifications_screen.dart': {'payment'},
        };

        for (final file in dartFiles) {
          final relPath = file.path.replaceAll(r'\', '/');
          final allowedForFile = wireAllowlist.entries
              .firstWhere(
                (e) => relPath.endsWith(e.key),
                orElse: () => const MapEntry('', <String>{}),
              )
              .value;

          final lines = file.readAsLinesSync();
          for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim();
            if (line.startsWith('*') || line.startsWith('/*')) {
              continue;
            }
            final commentIdx = line.indexOf('//');
            if (commentIdx != -1) {
              line = line.substring(0, commentIdx).trim();
            }
            if (line.isEmpty || _nonUiLine.hasMatch(line)) {
              continue;
            }

            for (final match in stringLiteralRegex.allMatches(line)) {
              final literal = (match.group(1) ?? match.group(2) ?? '').trim();
              if (allowedForFile.contains(literal.toLowerCase())) {
                continue;
              }
              if (hasPaymentWord(literal)) {
                violations.add(
                  '$relPath:${i + 1}: literal "$literal" names a payment action',
                );
              }
            }

            // Arabic payment words must not appear anywhere in code lines
            for (final arWord in _paymentArabic) {
              if (line.contains(arWord)) {
                violations.add(
                  '$relPath:${i + 1}: Arabic text contains "$arWord" -> "$line"',
                );
              }
            }
          }
        }

        expect(
          violations,
          isEmpty,
          reason:
              'Store safety rule violated! Strings must never mention a payment action.',
        );
      },
    );

    test(
      'price words appear only in the allowlisted label, helper and wire keys',
      () {
        final libDir = Directory('lib');
        expect(libDir.existsSync(), isTrue);

        final dartFiles = libDir
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'));

        final violations = <String>[];
        final stringLiteralRegex = RegExp(
          r"'([^'\\]*(?:\\.[^'\\]*)*)'|"
          r'"([^"\\]*(?:\\.[^"\\]*)*)"',
        );

        for (final file in dartFiles) {
          final relPath = file.path.replaceAll(r'\', '/');
          final allowedEntry = _priceLiteralAllowlist.entries.firstWhere(
            (e) => relPath.endsWith(e.key),
            orElse: () => const MapEntry('', <String>{}),
          );
          final allowed = allowedEntry.value;
          final isAllowlistedFile = allowed.isNotEmpty;

          final lines = file.readAsLinesSync();
          for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim();
            if (line.startsWith('*') || line.startsWith('/*')) {
              continue;
            }
            final commentIdx = line.indexOf('//');
            if (commentIdx != -1) {
              line = line.substring(0, commentIdx).trim();
            }
            if (line.isEmpty || _nonUiLine.hasMatch(line)) {
              continue;
            }

            for (final match in stringLiteralRegex.allMatches(line)) {
              final literal = (match.group(1) ?? match.group(2) ?? '').trim();
              final hits = priceWordsIn(
                literal,
              ).where((w) => !allowed.contains(w));
              for (final word in hits) {
                violations.add(
                  '$relPath:${i + 1}: literal "$literal" names "$word" '
                  'outside the price allowlist',
                );
              }
            }

            // Arabic price words must not appear anywhere in code lines,
            // except on lines that use the file's allowlisted words.
            for (final arWord in ['سعر', 'ج.م', 'جنيه']) {
              if (!line.contains(arWord)) continue;
              final onAllowlistedLine =
                  isAllowlistedFile && allowed.any((w) => line.contains(w));
              if (!onAllowlistedLine) {
                violations.add(
                  '$relPath:${i + 1}: Arabic text contains "$arWord" -> "$line"',
                );
              }
            }
          }
        }

        expect(
          violations,
          isEmpty,
          reason:
              'Store safety rule violated! Price words belong only to the allowlisted label, helper and wire keys.',
        );
      },
    );

    test(
      'the WhatsApp prefilled message and support button strings name no price and no payment',
      () {
        for (final locale in [const Locale('ar'), const Locale('en')]) {
          final l10n = AppLocalizations(locale);
          final strings = {
            'whatsappRequestText': l10n.whatsappRequestText(
              'Civil Law',
              'student@example.com',
            ),
            'openWhatsApp': l10n.openWhatsApp,
            'contactSupportToActivate': l10n.contactSupportToActivate,
            'contactWhatsApp': l10n.contactWhatsApp,
            'whatsappHelpText': l10n.whatsappHelpText,
            'copySupportLink': l10n.copySupportLink,
            'supportLinkCopied': l10n.supportLinkCopied,
          };

          for (final entry in strings.entries) {
            expect(
              hasPaymentWord(entry.value),
              isFalse,
              reason:
                  '${entry.key} [${locale.languageCode}] names a payment action: "${entry.value}"',
            );
            expect(
              hasPriceWord(entry.value),
              isFalse,
              reason:
                  '${entry.key} [${locale.languageCode}] names a price: "${entry.value}"',
            );
          }

          // The prefilled message still asks for activation (subject + email).
          final message = strings['whatsappRequestText']!;
          expect(message, contains('Civil Law'));
          expect(message, contains('student@example.com'));
        }
      },
    );

    test(
      'all settings and account localizations in both ar and en are store-safe',
      () {
        for (final locale in [const Locale('ar'), const Locale('en')]) {
          final l10n = AppLocalizations(locale);
          final strings = [
            l10n.helpTitle,
            l10n.contactWhatsApp,
            l10n.whatsappHelpText,
            l10n.supportOpenFailed,
            l10n.aboutApp,
            l10n.termsTitle,
            l10n.privacyTitle,
            l10n.appVersion,
            l10n.myAccount,
            l10n.myDevices,
            l10n.changePasswordTitle,
            l10n.deleteAccount,
            l10n.deleteAccountWarning,
            l10n.deleteConfirmHint,
            l10n.deletionScheduled('2026-11-05'),
            l10n.deletionCancelledNotice,
            l10n.emailCodeSent,
            l10n.emailChangedMessage,
            l10n.accessActive,
            l10n.openMap,
            l10n.brandLine,
            l10n.appCreditLine,
          ];

          for (final str in strings) {
            expect(
              hasPaymentWord(str),
              isFalse,
              reason: 'String "$str" names a payment action',
            );
            expect(
              hasPriceWord(str),
              isFalse,
              reason: 'String "$str" names a price',
            );
          }
        }
      },
    );

    test('legal summary and consent strings name no price and no payment', () {
      for (final locale in [const Locale('ar'), const Locale('en')]) {
        final l10n = AppLocalizations(locale);
        final strings = [
          l10n.agreeToTermsPrefix,
          l10n.agreeToTermsJoiner,
          l10n.termsLinkLabel,
          l10n.privacyLinkLabel,
          l10n.legalSheetTitle,
          l10n.termsSummaryTitle,
          l10n.privacySummaryTitle,
          ...l10n.termsSummaryBullets,
          ...l10n.privacySummaryBullets,
          l10n.readTermsFull,
          l10n.readPrivacyFull,
          l10n.legalAgree,
          l10n.deleteAccountWebHelp,
        ];

        for (final str in strings) {
          expect(
            hasPaymentWord(str),
            isFalse,
            reason: 'String "$str" names a payment action',
          );
          expect(
            hasPriceWord(str),
            isFalse,
            reason: 'String "$str" names a price',
          );
        }

        // The summaries stay short: six terms bullets, four privacy bullets.
        expect(l10n.termsSummaryBullets, hasLength(6));
        expect(l10n.privacySummaryBullets, hasLength(4));
      }
    });

    test('accessActive and courseLocked use access-based wording', () {
      final l10nAr = AppLocalizations(const Locale('ar'));
      final l10nEn = AppLocalizations(const Locale('en'));

      expect(l10nAr.accessActive, 'الوصول مفعّل');
      expect(l10nEn.accessActive, 'Access active');

      expect(ErrorMessages.courseLocked(true), contains('لتفعيل الوصول'));
      expect(ErrorMessages.courseLocked(true), isNot(contains('اشتراك')));
      expect(ErrorMessages.courseLocked(true), isNot(contains('الاشتراك')));
      expect(ErrorMessages.courseLocked(false), contains('gain access'));
    });
  });
}
