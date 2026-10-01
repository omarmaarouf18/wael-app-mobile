import 'package:flutter/foundation.dart' show kDebugMode, kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:wael_app/debug/component_library_screen.dart';
import 'package:wael_app/main.dart';
import 'package:wael_app/providers/locale_provider.dart';
import 'package:wael_app/widgets/app_shell.dart';

import 'widget_layer_harness.dart';

void main() {
  group('route table', () {
    test('release table has no debug routes', () {
      final routes = buildAppRoutes(includeDebugRoutes: false);
      expect(routes.containsKey('/components'), isFalse);
      expect(routes.containsKey('/debug'), isFalse);
      expect(routes.containsKey('/login'), isTrue);
    });

    test('debug table has both debug routes', () {
      final routes = buildAppRoutes(includeDebugRoutes: true);
      expect(routes.containsKey('/components'), isTrue);
      expect(routes.containsKey('/debug'), isTrue);
    });

    test('the default follows the build mode (kDebugMode)', () {
      final routes = buildAppRoutes();
      expect(routes.containsKey('/components'), kDebugMode);
      expect(routes.containsKey('/debug'), kDebugMode);
      // Run with --dart-define=dart.vm.product=true to execute this file as
      // a release build; see docs/frontend/STATUS.md.
      if (kReleaseMode) {
        expect(routes.containsKey('/components'), isFalse);
      }
    });
  });

  group('ComponentLibraryScreen', () {
    Future<void> pumpLibrary(WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => LocaleProvider(),
          child: Consumer<LocaleProvider>(
            builder: (context, locale, _) =>
                localizedApp(locale.locale, const ComponentLibraryScreen()),
          ),
        ),
      );
      // The library shows spinners, so it never settles.
      await tester.pump(const Duration(milliseconds: 100));
    }

    testWidgets('renders every widget and toggles to RTL', skip: kReleaseMode, (
      tester,
    ) async {
      await pumpLibrary(tester);
      expect(find.byType(AppShell), findsOneWidget);
      expect(find.text('COMPONENT LIBRARY'), findsNothing);
      expect(find.text('Component library'), findsOneWidget);
      expect(find.text('AR'), findsOneWidget);
      expect(
        Directionality.of(tester.element(find.byType(AppShell))),
        TextDirection.ltr,
      );

      await tester.tap(find.text('AR'));
      // One frame to rebuild with the new locale, one for the l10n delegate
      // to finish loading.
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('EN'), findsOneWidget);
      expect(
        Directionality.of(tester.element(find.byType(AppShell))),
        TextDirection.rtl,
      );
    });
  });
}
