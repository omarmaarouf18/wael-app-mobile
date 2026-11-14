import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:wael_app/models/iap_package.dart';
import 'package:wael_app/providers/iap_provider.dart';
import 'package:wael_app/screens/packages_screen.dart';
import 'package:wael_app/services/iap_store.dart';

import 'iap_fakes.dart';
import 'screen_harness.dart';

/// The iOS packages screen at the App Store 6.7" screenshot size
/// (1290x2796 px: 430x932 pt rendered at 3x), with the bundled fonts and the Material
/// icons font loaded so the images are readable (the other goldens render
/// the test font). The data is the frozen contract's example package
/// (docs/contracts/iap-packages-api.md 4.1); the price is a fake StoreKit
/// display string, so these images are a layout reference: the screenshot
/// uploaded to App Store Connect must show the real StoreKit price.
Future<void> _loadIconFont() async {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root == null) return;
  final file = File(
    '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  if (!file.existsSync()) return;
  final bytes = file.readAsBytesSync();
  final loader = FontLoader('MaterialIcons')
    ..addFont(Future.value(ByteData.view(bytes.buffer)));
  await loader.load();
}

Map<String, dynamic> _contractExample() => {
  'app_account_token': kToken,
  'packages': [
    {
      'id': 'pkg_year1_2026',
      'product_id': 'com.wael.app.pkg.year1',
      'title': {'ar': 'الفرقة الأولى', 'en': 'Year 1'},
      'description': {
        'ar': 'باقة مواد الفرقة الأولى كاملة لعام 2026-2027',
        'en': 'All Year 1 subjects for the 2026-2027 academic year',
      },
      'available_until': '2027-01-20T00:00:00Z',
      'on_sale': true,
      'position': 1,
      'subjects': [
        {
          'id': 'subj_law101',
          'title': {'ar': 'مدخل العلوم القانونية', 'en': 'Introduction to Law'},
          'level_key': 'bachelor-y1',
          'term': 'first',
          'owned': false,
        },
        {
          'id': 'subj_const101',
          'title': {'ar': 'القانون الدستوري', 'en': 'Constitutional Law'},
          'level_key': 'bachelor-y1',
          'term': 'first',
          'owned': true,
        },
      ],
    },
  ],
};

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await _loadIconFont();
  });

  for (final (code, locale) in [
    ('ar', const Locale('ar')),
    ('en', const Locale('en')),
  ]) {
    testWidgets(
      'golden: iOS packages screen ($code), App Store 6.7"',
      (tester) async {
        final repo = FakeIapRepository()
          ..catalog = IapCatalog.fromJson(_contractExample());
        final store = FakeIapStore()
          ..known = {
            'com.wael.app.pkg.year1': const IapStoreProduct(
              id: 'com.wael.app.pkg.year1',
              price: 'EGP 500.00',
            ),
          };
        final iap = fakeIapProvider(repo: repo, store: store);
        await pumpScreen(
          tester,
          locale,
          const PackagesScreen(),
          extraProviders: [
            ChangeNotifierProvider<IapProvider>.value(value: iap),
          ],
          size: const Size(430, 932),
        );
        await tester.runAsync(GoogleFonts.pendingFonts);
        await tester.pumpAndSettle();

        // The route's repaint boundary covers the whole screen; render it
        // at 3x so the PNG is exactly 1290x2796.
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find
              .ancestor(
                of: find.byType(PackagesScreen),
                matching: find.byType(RepaintBoundary),
              )
              .first,
        );
        final image = await tester.runAsync(
          () => boundary.toImage(pixelRatio: 3.0),
        );
        expect(image!.width, 1290);
        expect(image.height, 2796);
        await expectLater(
          image,
          matchesGoldenFile('goldens/iap_packages_$code.png'),
        );
        await tester.pump(const Duration(seconds: 2));
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
      tags: ['store-screenshot'],
    );
  }
}
