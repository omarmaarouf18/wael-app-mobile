import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wael_app/core/api_client.dart';
import 'package:wael_app/core/error_messages.dart';
import 'package:wael_app/l10n/app_localizations.dart';

import 'packages_screen_test.dart' show iapStrings;

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
///
/// Website guard (owner decision 2026-11-04, ADR-0014, SPEC D3 amendment):
/// the app never contains the sales website's address or any link or
/// wording that leads to buying on it (Apple 3.1.3(a) reader app, Google
/// Play payments policy). The website's hosts (owner decision 2026-11-04,
/// ADR-0014 amendment) are refused: the apex domain, `www.` and Vercel
/// deployments (`*.vercel.app`). The app's own `legal.` and `api.` hosts,
/// and every other subdomain, are not the website and stay allowed.

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

// Owner decision D5 (2026-11-14, issue #58): Apple requires a clear
// purchase button and "Restore Purchases". These two l10n keys, and only
// these, may name the purchase action; they render only behind
// StorePolicy.iapEnabled (iOS), in lib/screens/packages_screen.dart. Every
// other string keeps the ban above.
const _iapPurchaseActionKeys = {'iapBuy', 'iapRestorePurchases'};

/// Every `iap*` key in AppLocalizations (issue #58); keep in sync with
/// `iapStrings` in test/packages_screen_test.dart.
const _iapKeys = {
  'iapBuy',
  'iapRestorePurchases',
  'iapPackagesTitle',
  'iapEntrySubtitle',
  'iapAvailableUntil',
  'iapSubjectsHeading',
  'iapOwned',
  'iapNoSubjects',
  'iapNoPackages',
  'iapNotOnSale',
  'iapAllOwned',
  'iapStoreUnavailable',
  'iapPending',
  'iapVerifying',
  'iapSuccess',
  'iapRestoreNothing',
  'iapSubjectNotAvailable',
  'iapLoadFailed',
  'iapErrorRetryLater',
  'iapErrorInProgress',
  'iapErrorOtherAccount',
  'iapErrorUsedByOther',
  'iapErrorCancelledByApple',
  'iapErrorNotConfirmed',
  'iapErrorSandbox',
  'iapErrorPackageMissing',
};

/// Line indexes (0-based) of lib/l10n/app_localizations.dart that belong to
/// the D5 allowlisted getters: from `String get <key>` to its closing `;`.
Set<int> iapAllowlistedLines(List<String> lines) {
  final out = <int>{};
  for (var i = 0; i < lines.length; i++) {
    final m = RegExp(r'String get (\w+)\b').firstMatch(lines[i]);
    if (m == null || !_iapPurchaseActionKeys.contains(m.group(1))) continue;
    var j = i;
    while (true) {
      out.add(j);
      if (lines[j].trimRight().endsWith(';') || j == lines.length - 1) break;
      j++;
    }
  }
  return out;
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

// The patterns are built from parts so this file never matches itself.
const _domain =
    'elmetracademy'
    r'\.app';

/// The website's hosts: the apex domain and `www.` (a `legal.` or `api.`
/// host never matches, since a dot before the domain is refused unless it
/// follows `www`), and Vercel deployments.
final _websiteHosts = [
  RegExp(
    r'(?<![a-z0-9.-])(?:www\.)?' + _domain + r'(?![a-z0-9-])',
    caseSensitive: false,
  ),
  RegExp(
    r'(?<![a-z0-9.-])(?:[a-z0-9-]+\.)+vercel'
    r'\.app(?![a-z0-9-])',
    caseSensitive: false,
  ),
];

/// Website addresses found in [text]; `legal.` and `api.` hosts are allowed.
List<String> websiteAddressesIn(String text) => [
  for (final pattern in _websiteHosts)
    ...pattern.allMatches(text).map((m) => m.group(0)!),
];

/// Directories under frontend/ that are build output or tool state, never
/// source (and may hold symlinks into the pub cache).
const _generatedDirs = {
  '.dart_tool',
  'build',
  '.gradle',
  'Pods',
  '.symlinks',
  'ephemeral',
  '.idea',
  '.git',
  'coverage',
};

const _binaryExtensions = {
  '.png', '.jpg', '.jpeg', '.gif', '.webp', '.ico', '.ttf', '.otf', //
  '.jar', '.zip', '.pdf', '.so', '.keystore', '.jks',
};

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

  group('Website address guard (ADR-0014)', () {
    test(
      'matcher: website hosts are refused, the app\'s own hosts are not',
      () {
        // Built from parts, like the patterns, so the scan below never trips
        // on this file.
        const d =
            'elmetracademy'
            '.app';
        expect(websiteAddressesIn('https://$d/subjects'), isNotEmpty);
        expect(websiteAddressesIn('https://www.$d'), isNotEmpty);
        expect(websiteAddressesIn('WWW.$d/subjects'), isNotEmpty);
        expect(
          websiteAddressesIn('visit ${d.toUpperCase()} to buy'),
          isNotEmpty,
        );
        expect(
          websiteAddressesIn(
            'https://elmetr-web.vercel'
            '.app',
          ),
          isNotEmpty,
        );
        expect(
          websiteAddressesIn(
            'https://elmetr-web-git-develop-team.vercel'
            '.app/en',
          ),
          isNotEmpty,
        );
        expect(websiteAddressesIn('https://legal.$d/terms#en'), isEmpty);
        expect(websiteAddressesIn('https://api.$d'), isEmpty);
        expect(websiteAddressesIn('app.elmetracademy.student'), isEmpty);
        expect(websiteAddressesIn('https://shop.$d'), isEmpty);
        expect(
          websiteAddressesIn(
            'https://vercel'
            '.com/docs',
          ),
          isEmpty,
        );
      },
    );

    test('no file under frontend/ names the website or links to it', () {
      final root = Directory('.');
      expect(File('pubspec.yaml').existsSync(), isTrue);

      final violations = <String>[];
      final pending = <Directory>[root];
      while (pending.isNotEmpty) {
        final dir = pending.removeLast();
        for (final entity in dir.listSync(followLinks: false)) {
          final name = entity.uri.pathSegments.lastWhere((s) => s.isNotEmpty);
          if (entity is Directory) {
            if (!_generatedDirs.contains(name)) pending.add(entity);
            continue;
          }
          if (entity is! File) continue;
          final dot = name.lastIndexOf('.');
          final ext = dot == -1 ? '' : name.substring(dot).toLowerCase();
          if (_binaryExtensions.contains(ext)) continue;
          final bytes = entity.readAsBytesSync();
          if (bytes.contains(0)) continue; // other binary files
          final lines = utf8.decode(bytes, allowMalformed: true).split('\n');
          for (var i = 0; i < lines.length; i++) {
            for (final hit in websiteAddressesIn(lines[i])) {
              violations.add('${entity.path}:${i + 1}: "$hit"');
            }
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason:
            'Store safety rule violated! The app must never contain the '
            'website\'s address or a link to it (ADR-0014).',
      );
    });
  });

  group('Store-safety l10n scan', () {
    test(
      'no payment-action words appear in app_localizations string literals',
      () {
        final file = File('lib/l10n/app_localizations.dart');
        expect(file.existsSync(), isTrue);

        final lines = file.readAsLinesSync();
        final violations = <String>[];
        final allowed = iapAllowlistedLines(lines);
        expect(allowed, isNotEmpty);

        for (var i = 0; i < lines.length; i++) {
          if (allowed.contains(i)) continue;
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
          final allowed = relPath.endsWith('lib/l10n/app_localizations.dart')
              ? iapAllowlistedLines(lines)
              : const <int>{};
          for (var i = 0; i < lines.length; i++) {
            if (allowed.contains(i)) continue;
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

    test(
      'iOS locked and pending panel strings contain no activation, WhatsApp or price words',
      () {
        for (final locale in [const Locale('ar'), const Locale('en')]) {
          final l10n = AppLocalizations(locale);
          final isArabic = locale.languageCode == 'ar';
          final strings = [
            l10n.enrolledStudentsOnly,
            ErrorMessages.courseLocked(isArabic, TargetPlatform.iOS),
            ErrorMessages.forAccessRequest(
              ApiException(statusCode: 500, message: 'fail'),
              isArabic: isArabic,
              contentOnly: true,
            ),
            ErrorMessages.forAccessRequest(
              ApiException(statusCode: 404, message: 'not found'),
              isArabic: isArabic,
              contentOnly: true,
            ),
            ErrorMessages.forAccessRequest(
              ApiException(statusCode: 409, message: 'conflict'),
              isArabic: isArabic,
              contentOnly: true,
            ),
            ErrorMessages.forAccessRequest(
              ApiException(statusCode: 503, message: 'unavailable'),
              isArabic: isArabic,
              contentOnly: true,
            ),
          ];

          const forbidden = [
            'تفعيل',
            'تتفعّل',
            'activate',
            'whatsapp',
            'واتساب',
            'سعر',
            'price',
            'egp',
            'ج.م',
            'شراء',
            'buy',
            'اشترك',
            'اشتراك',
          ];

          for (final str in strings) {
            final lower = str.toLowerCase();
            for (final word in forbidden) {
              expect(
                lower.contains(word),
                isFalse,
                reason: 'iOS string "$str" contains forbidden word "$word"',
              );
            }
          }
        }
      },
    );

    test('D5: exactly iapBuy and iapRestorePurchases are allowlisted', () {
      final lines = File('lib/l10n/app_localizations.dart').readAsLinesSync();
      final allowed = iapAllowlistedLines(lines);
      final keys = {
        for (final i in allowed)
          ?RegExp(r'String get (\w+)\b').firstMatch(lines[i])?.group(1),
      };
      expect(keys, _iapPurchaseActionKeys);
      // Each allowlisted getter is two lines at most (no hidden extra text).
      expect(allowed.length, lessThanOrEqualTo(4));
      for (final locale in [const Locale('ar'), const Locale('en')]) {
        final l10n = AppLocalizations(locale);
        final isArabic = locale.languageCode == 'ar';
        expect(l10n.iapBuy, isArabic ? 'شراء' : 'Buy');
        expect(
          l10n.iapRestorePurchases,
          isArabic ? 'استعادة المشتريات' : 'Restore Purchases',
        );
      }
    });

    test('D5: the allowlisted keys are used only by the packages screen', () {
      final uses = <String>[];
      for (final f in Directory('lib').listSync(recursive: true)) {
        if (f is! File || !f.path.endsWith('.dart')) continue;
        final rel = f.path.replaceAll(r'\', '/');
        if (rel.endsWith('lib/l10n/app_localizations.dart')) continue;
        final text = f.readAsStringSync();
        for (final key in _iapPurchaseActionKeys) {
          if (text.contains('.$key')) uses.add('$rel:$key');
        }
      }
      expect(uses.toSet(), {
        'lib/screens/packages_screen.dart:iapBuy',
        'lib/screens/packages_screen.dart:iapRestorePurchases',
      });
    });

    test('every iap key is listed (and nothing else starts with iap)', () {
      final text = File('lib/l10n/app_localizations.dart').readAsStringSync();
      final declared = {
        for (final m in RegExp(r'String (?:get )?(iap\w+)\b').allMatches(text))
          m.group(1)!,
      }..remove('iapError');
      expect(declared, _iapKeys);
      for (final locale in [const Locale('ar'), const Locale('en')]) {
        expect(
          iapStrings(AppLocalizations(locale)),
          hasLength(_iapKeys.length),
        );
      }
    });

    test('D5: every other iOS packages string names no payment action, price, '
        'activation, WhatsApp or website', () {
      const forbidden = [
        'تفعيل',
        'تتفعّل',
        'activate',
        'whatsapp',
        'واتساب',
        'website',
        'الموقع',
        'سعر',
        'price',
        'egp',
        'ج.م',
        'اشترك',
        'اشتراك',
        'contact',
        'تواصل',
      ];
      for (final locale in [const Locale('ar'), const Locale('en')]) {
        final l10n = AppLocalizations(locale);
        final strings = [
          for (final s in iapStrings(l10n))
            if (s != l10n.iapBuy && s != l10n.iapRestorePurchases) s,
          for (final code in [
            null,
            'store_unavailable',
            'storekit_duplicate_product_object',
            'accountMismatch',
            'transactionOwnedByOtherUser',
            'revokedTransaction',
            'invalidTransaction',
            'sandboxNotAllowed',
            'unknownProduct',
            'network',
          ])
            l10n.iapError(code),
        ];
        for (final str in strings) {
          expect(hasPaymentWord(str), isFalse, reason: 'payment: "$str"');
          expect(hasPriceWord(str), isFalse, reason: 'price: "$str"');
          expect(websiteAddressesIn(str), isEmpty, reason: 'site: "$str"');
          final lower = str.toLowerCase();
          for (final word in forbidden) {
            expect(
              lower.contains(word),
              isFalse,
              reason: 'iOS string "$str" contains "$word"',
            );
          }
        }
      }
    });
  });
}
