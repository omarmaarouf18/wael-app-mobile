import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wael_app/core/error_messages.dart';
import 'package:wael_app/l10n/app_localizations.dart';

void main() {
  // Price words (سعر، ج.م، جنيه، price) are NOT forbidden: the owner
  // decision 2026-10-08 allows showing the server-sent subject price. The
  // dedicated allowlist rule for where they may appear lands separately.
  const forbiddenWords = [
    'دفع',
    'شراء',
    'استرداد',
    'payment',
    'refund',
    'purchase',
  ];

  group('Store-safety l10n scan', () {
    test(
      'no forbidden store-safety words appear in app_localizations string literals',
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

          for (final word in forbiddenWords) {
            // Case-insensitive match for English words, exact for Arabic
            final pattern = RegExp(RegExp.escape(word), caseSensitive: false);
            if (pattern.hasMatch(line)) {
              violations.add('Line ${i + 1}: contains "$word" -> "$line"');
            }
          }
        }

        expect(
          violations,
          isEmpty,
          reason:
              'Store safety rule violated! Strings must never mention payment/price/refund.',
        );
      },
    );

    test(
      'no forbidden store-safety words appear in string literals across all lib/ dart files',
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
          'lib/models/academy_catalog.dart': {'price'},
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
            if (line.isEmpty) {
              continue;
            }

            for (final match in stringLiteralRegex.allMatches(line)) {
              final literal = (match.group(1) ?? match.group(2) ?? '').trim();
              if (allowedForFile.contains(literal)) {
                continue;
              }
              for (final word in forbiddenWords) {
                final pattern = RegExp(
                  RegExp.escape(word),
                  caseSensitive: false,
                );
                if (pattern.hasMatch(literal)) {
                  violations.add(
                    '$relPath:${i + 1}: literal "$literal" contains "$word"',
                  );
                }
              }
            }

            // Arabic forbidden words must not appear anywhere in code lines
            for (final arWord in ['دفع', 'شراء', 'استرداد']) {
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
              'Store safety rule violated! Strings must never mention payment/price/refund.',
        );
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
          ];

          for (final str in strings) {
            for (final word in forbiddenWords) {
              final pattern = RegExp(RegExp.escape(word), caseSensitive: false);
              expect(
                pattern.hasMatch(str),
                isFalse,
                reason: 'String "$str" contains forbidden word "$word"',
              );
            }
          }
        }
      },
    );

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
