import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wael_app/l10n/app_localizations.dart';

void main() {
  const forbiddenWords = [
    'دفع',
    'سعر',
    'ج.م',
    'جنيه',
    'شراء',
    'استرداد',
    'payment',
    'price',
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
  });
}
