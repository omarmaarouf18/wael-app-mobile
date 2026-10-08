import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:wael_app/core/price_format.dart';
import 'package:wael_app/core/theme.dart';
import 'package:wael_app/l10n/app_localizations.dart';
import 'package:wael_app/models/academy_catalog.dart';
import 'package:wael_app/models/app_config.dart';
import 'package:wael_app/providers/academy_catalog_provider.dart';
import 'package:wael_app/providers/app_config_provider.dart';
import 'package:wael_app/providers/home_provider.dart';
import 'package:wael_app/providers/locale_provider.dart';
import 'package:wael_app/providers/notifications_provider.dart';
import 'package:wael_app/screens/course_detail_screen.dart';
import 'package:wael_app/widgets/catalog_subject_card.dart';

import 'academy_fakes.dart';
import 'director_fixture.dart';
import 'screen_harness.dart';
import 'widget_layer_harness.dart';

AcademySubject cardSubject({
  bool owned = false,
  int? price = 350,
  String? currency = 'EGP',
}) => AcademySubject(
  id: 's1',
  levelKey: 'bachelor-y1',
  term: 'first',
  title: const LocalizedText(ar: 'القانون المدني', en: 'Civil Law'),
  description: const LocalizedText(en: 'About the subject'),
  owned: owned,
  counts: const SubjectCounts(videos: 2, books: 1),
  price: price,
  currency: currency,
);

/// Pumps [screen] at 2.0x text scaling with the app's providers backed by
/// fakes. Any clipping fails via [tester.takeException].
Future<void> pumpScaled(
  WidgetTester tester,
  Locale locale,
  Widget screen, {
  AcademyCatalogProvider? catalog,
  AppConfigProvider? appConfig,
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MultiProvider(
      providers: <SingleChildWidget>[
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
        ChangeNotifierProvider.value(value: makeAuth()),
        ChangeNotifierProvider.value(value: NotificationsProvider()),
        ChangeNotifierProvider.value(value: appConfig ?? AppConfigProvider()),
        if (catalog != null)
          ChangeNotifierProvider<AcademyCatalogProvider>.value(value: catalog),
        ChangeNotifierProvider.value(
          value: HomeProvider(director: testDirector),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        locale: locale,
        supportedLocales: const [Locale('en', ''), Locale('ar', '')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2.0)),
          child: child!,
        ),
        home: screen,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// A catalog whose `d1` detail is loaded (and whose access request was sent,
// like a real open of a locked subject).
Future<AcademyCatalogProvider> pricedCatalog({
  bool owned = false,
  Object? price = 25000,
}) async {
  final repo = fake();
  repo.detailJson['d1'] = detailBody(owned: owned, price: price);
  final catalog = AcademyCatalogProvider(repo);
  await catalog.openSubject('d1');
  return catalog;
}

void main() {
  group('formatSubjectPrice', () {
    test('EGP renders ج.م in Arabic, EGP in English', () {
      expect(
        formatSubjectPrice(amount: 350, currency: 'EGP', isArabic: true),
        '350 ج.م',
      );
      expect(
        formatSubjectPrice(amount: 350, currency: 'EGP', isArabic: false),
        'EGP 350',
      );
    });

    test('an unknown code is shown raw with the number', () {
      expect(
        formatSubjectPrice(amount: 350, currency: 'USD', isArabic: true),
        '350 USD',
      );
      expect(
        formatSubjectPrice(amount: 350, currency: 'USD', isArabic: false),
        'USD 350',
      );
    });

    test('a missing currency renders the bare number', () {
      expect(
        formatSubjectPrice(amount: 350, currency: null, isArabic: true),
        '350',
      );
      expect(
        formatSubjectPrice(amount: 350, currency: '  ', isArabic: false),
        '350',
      );
    });

    test('five-digit prices keep ASCII digits', () {
      expect(
        formatSubjectPrice(amount: 25000, currency: 'EGP', isArabic: true),
        '25000 ج.م',
      );
      expect(
        formatSubjectPrice(amount: 25000, currency: 'EGP', isArabic: false),
        'EGP 25000',
      );
    });

    test('shouldShowSubjectPrice needs unlocked, priced and flag on', () {
      expect(
        shouldShowSubjectPrice(owned: false, price: 350, showPrices: true),
        isTrue,
      );
      expect(
        shouldShowSubjectPrice(owned: true, price: 350, showPrices: true),
        isFalse,
      );
      expect(
        shouldShowSubjectPrice(owned: false, price: null, showPrices: true),
        isFalse,
      );
      expect(
        shouldShowSubjectPrice(owned: false, price: 350, showPrices: false),
        isFalse,
      );
    });
  });

  for (final (name, locale, _) in kLocales) {
    final l10n = l10nFor(locale);
    final isArabic = locale.languageCode == 'ar';
    String priced(int amount) => isArabic ? '$amount ج.م' : 'EGP $amount';

    Future<void> pumpDetail(
      WidgetTester tester,
      Map<String, dynamic> detail, {
      bool showPrices = false,
    }) async {
      final repository = fake();
      repository.detailJson['d1'] = detail;
      final catalog = AcademyCatalogProvider(repository);
      final appConfig = AppConfigProvider()
        ..setForTesting(AppConfigData(showPrices: showPrices));
      await pumpScreen(
        tester,
        locale,
        const CourseDetailScreen(courseId: 'd1'),
        appConfig: appConfig,
        extraProviders: [
          ChangeNotifierProvider<AcademyCatalogProvider>.value(value: catalog),
          ChangeNotifierProvider(
            create: (_) => HomeProvider(director: testDirector),
          ),
        ],
        size: const Size(390, 2400),
      );
    }

    AppConfigProvider pricesOn() =>
        AppConfigProvider()
          ..setForTesting(const AppConfigData(showPrices: true));

    group('subject price [$name]', () {
      testWidgets('locked subject with price shows label and value', (
        tester,
      ) async {
        await pumpDetail(tester, detailBody(price: 350), showPrices: true);
        expect(find.text(l10n.priceLabel), findsOneWidget);
        expect(find.text(priced(350)), findsOneWidget);
      });

      testWidgets('flag off hides the price even when sent', (tester) async {
        await pumpDetail(tester, detailBody(price: 350), showPrices: false);
        expect(find.text(l10n.priceLabel), findsNothing);
        expect(find.text(priced(350)), findsNothing);
      });

      testWidgets('missing flag (offline default) hides the price', (
        tester,
      ) async {
        await pumpDetail(tester, detailBody(price: 350));
        expect(find.text(l10n.priceLabel), findsNothing);
        expect(find.text(priced(350)), findsNothing);
      });

      testWidgets('locked subject without price shows nothing, no gap', (
        tester,
      ) async {
        await pumpDetail(tester, detailBody(), showPrices: true);
        expect(find.text(l10n.priceLabel), findsNothing);
        expect(find.textContaining('EGP'), findsNothing);
        expect(find.textContaining('ج.م'), findsNothing);
      });

      testWidgets('owned subject shows no price even when sent', (
        tester,
      ) async {
        await pumpDetail(
          tester,
          detailBody(owned: true, price: 350),
          showPrices: true,
        );
        expect(find.text(l10n.accessActive), findsOneWidget);
        expect(find.text(l10n.priceLabel), findsNothing);
        expect(find.text(priced(350)), findsNothing);
      });

      testWidgets('list card shows a compact price for locked subjects', (
        tester,
      ) async {
        await pumpLocalized(
          tester,
          locale,
          CatalogSubjectCard(
            subject: cardSubject(),
            showPrice: true,
            onTap: () {},
          ),
        );
        expect(find.text(l10n.priceLabel), findsOneWidget);
        expect(find.text(priced(350)), findsOneWidget);
      });

      testWidgets('list card hides the price when the flag is off', (
        tester,
      ) async {
        await pumpLocalized(
          tester,
          locale,
          CatalogSubjectCard(
            subject: cardSubject(),
            showPrice: false,
            onTap: () {},
          ),
        );
        expect(find.text(l10n.priceLabel), findsNothing);
        expect(find.text(priced(350)), findsNothing);
      });

      testWidgets('list card hides the price when the flag is missing', (
        tester,
      ) async {
        await pumpLocalized(
          tester,
          locale,
          CatalogSubjectCard(subject: cardSubject(), onTap: () {}),
        );
        expect(find.text(l10n.priceLabel), findsNothing);
        expect(find.text(priced(350)), findsNothing);
      });

      testWidgets('list card hides the price when owned or absent', (
        tester,
      ) async {
        await pumpLocalized(
          tester,
          locale,
          CatalogSubjectCard(subject: cardSubject(owned: true), onTap: () {}),
        );
        expect(find.text(l10n.priceLabel), findsNothing);

        await pumpLocalized(
          tester,
          locale,
          CatalogSubjectCard(
            subject: cardSubject(price: null, currency: null),
            onTap: () {},
          ),
        );
        expect(find.text(l10n.priceLabel), findsNothing);
        expect(find.textContaining('EGP'), findsNothing);
      });

      testWidgets('unknown currency on a card shows the raw code', (
        tester,
      ) async {
        await pumpLocalized(
          tester,
          locale,
          CatalogSubjectCard(
            subject: cardSubject(price: 400, currency: 'USD'),
            showPrice: true,
            onTap: () {},
          ),
        );
        expect(find.text(isArabic ? '400 USD' : 'USD 400'), findsOneWidget);
      });
    });

    group('subject price 2.0x scaling [$name]', () {
      testWidgets('subject detail with a 5-digit price has no overflow', (
        tester,
      ) async {
        await pumpScaled(
          tester,
          locale,
          const CourseDetailScreen(courseId: 'd1'),
          catalog: await pricedCatalog(),
          appConfig: pricesOn(),
        );
        expect(tester.takeException(), isNull);
        expect(find.text(priced(25000)), findsOneWidget);
      });

      testWidgets('course card with a 5-digit price has no overflow', (
        tester,
      ) async {
        await pumpScaled(
          tester,
          locale,
          CatalogSubjectCard(
            subject: cardSubject(price: 25000),
            showPrice: true,
            onTap: () {},
          ),
        );
        expect(tester.takeException(), isNull);
        expect(find.text(priced(25000)), findsOneWidget);
      });
    });
  }
}
