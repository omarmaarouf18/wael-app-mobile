import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:wael_app/l10n/app_localizations.dart';
import 'package:wael_app/models/iap_package.dart';
import 'package:wael_app/providers/academy_catalog_provider.dart';
import 'package:wael_app/providers/home_provider.dart';
import 'package:wael_app/providers/iap_provider.dart';
import 'package:wael_app/repositories/iap_repository.dart';
import 'package:wael_app/screens/course_detail_screen.dart';
import 'package:wael_app/screens/courses_screen.dart';
import 'package:wael_app/screens/home_screen.dart';
import 'package:wael_app/screens/packages_screen.dart';
import 'package:wael_app/services/iap_store.dart';
import 'package:wael_app/widgets/packages_entry_tile.dart';
import 'package:wael_app/widgets/primary_button.dart';

import 'academy_fakes.dart';
import 'director_fixture.dart';
import 'iap_fakes.dart';
import 'screen_harness.dart';
import 'widget_layer_harness.dart';

/// Every `iap*` string a screen can render, for the "never on Android"
/// checks (owner decision D5). `test/store_safety_l10n_test.dart` checks
/// that this list covers every `iap` key.
List<String> iapStrings(AppLocalizations l10n) => [
  l10n.iapBuy,
  l10n.iapRestorePurchases,
  l10n.iapPackagesTitle,
  l10n.iapEntrySubtitle,
  l10n.iapAvailableUntil('2027-01-20'),
  l10n.iapSubjectsHeading,
  l10n.iapOwned,
  l10n.iapNoSubjects,
  l10n.iapNoPackages,
  l10n.iapNotOnSale,
  l10n.iapAllOwned,
  l10n.iapStoreUnavailable,
  l10n.iapPending,
  l10n.iapVerifying,
  l10n.iapSuccess,
  l10n.iapRestoreNothing,
  l10n.iapSubjectInPackage('Year 1'),
  l10n.iapSubjectInPackage('الفرقة الأولى'),
  l10n.iapViewPackage,
  l10n.iapSubjectNotAvailable,
  l10n.iapLoadFailed,
  l10n.iapErrorRetryLater,
  l10n.iapErrorInProgress,
  l10n.iapErrorOtherAccount,
  l10n.iapErrorUsedByOther,
  l10n.iapErrorCancelledByApple,
  l10n.iapErrorNotConfirmed,
  l10n.iapErrorSandbox,
  l10n.iapErrorPackageMissing,
];

void expectNoIapText(AppLocalizations l10n) {
  for (final text in iapStrings(l10n)) {
    expect(find.text(text), findsNothing, reason: 'rendered "$text"');
  }
}

void main() {
  for (final (name, locale, _) in kLocales) {
    final l10n = l10nFor(locale);

    Future<IapProvider> pumpPackages(
      WidgetTester tester, {
      FakeIapRepository? repo,
      FakeIapStore? store,
      String? focus,
    }) async {
      final iap = fakeIapProvider(repo: repo, store: store);
      await pumpScreen(
        tester,
        locale,
        PackagesScreen(focusPackageId: focus),
        extraProviders: [ChangeNotifierProvider<IapProvider>.value(value: iap)],
        size: const Size(390, 1400),
      );
      return iap;
    }

    group('PackagesScreen iOS [$name]', () {
      testWidgets(
        'lists packages with the StoreKit price, subjects and Buy',
        (tester) async {
          final store = FakeIapStore();
          await pumpPackages(tester, store: store);
          expect(find.text(l10n.iapPackagesTitle), findsWidgets);
          expect(
            find.text(l10n.isArabic ? 'الفرقة الأولى' : 'Year 1'),
            findsOneWidget,
          );
          // The price is StoreKit's, as returned.
          expect(find.text('EGP 500.00'), findsOneWidget);
          expect(
            find.text(l10n.iapAvailableUntil('2027-01-20')),
            findsOneWidget,
          );
          expect(find.text(l10n.iapSubjectsHeading), findsOneWidget);
          expect(find.text(l10n.isArabic ? 'مادة' : 'Subject'), findsOneWidget);
          expect(find.text(l10n.iapRestorePurchases), findsOneWidget);

          final buy = tester.widget<PrimaryButton>(
            find.widgetWithText(PrimaryButton, l10n.iapBuy),
          );
          expect(buy.onPressed, isNotNull);
          await tester.tap(find.text(l10n.iapBuy));
          await tester.pump();
          expect(store.buys.single, ('com.wael.app.pkg.year1', kToken));
          await tester.pump(const Duration(seconds: 2));
        },
        variant: TargetPlatformVariant.only(TargetPlatform.iOS),
      );

      testWidgets(
        'no end date: the "available until" line is hidden',
        (tester) async {
          final repo = FakeIapRepository()
            ..catalog = IapCatalog.fromJson(packagesJson(availableUntil: null));
          await pumpPackages(tester, repo: repo);
          expect(find.textContaining(l10n.iapAvailableUntil('')), findsNothing);
          await tester.pump(const Duration(seconds: 2));
        },
        variant: TargetPlatformVariant.only(TargetPlatform.iOS),
      );

      testWidgets(
        'Buy is disabled with a reason when the package is not on sale',
        (tester) async {
          final repo = FakeIapRepository()
            ..catalog = IapCatalog.fromJson(packagesJson(onSale: false));
          await pumpPackages(tester, repo: repo);
          final buy = tester.widget<PrimaryButton>(
            find.widgetWithText(PrimaryButton, l10n.iapBuy),
          );
          expect(buy.onPressed, isNull);
          expect(find.text(l10n.iapNotOnSale), findsOneWidget);
          await tester.pump(const Duration(seconds: 2));
        },
        variant: TargetPlatformVariant.only(TargetPlatform.iOS),
      );

      testWidgets(
        'Buy is disabled with a reason when StoreKit has no product',
        (tester) async {
          final store = FakeIapStore()..known = {};
          await pumpPackages(tester, store: store);
          final buy = tester.widget<PrimaryButton>(
            find.widgetWithText(PrimaryButton, l10n.iapBuy),
          );
          expect(buy.onPressed, isNull);
          expect(find.text(l10n.iapStoreUnavailable), findsOneWidget);
          expect(find.text('EGP 500.00'), findsNothing);
          await tester.pump(const Duration(seconds: 2));
        },
        variant: TargetPlatformVariant.only(TargetPlatform.iOS),
      );

      testWidgets(
        'everything owned: owned marks and Buy disabled',
        (tester) async {
          final repo = FakeIapRepository()
            ..catalog = IapCatalog.fromJson(packagesJson(owned: true));
          await pumpPackages(tester, repo: repo);
          expect(find.text(l10n.iapOwned), findsOneWidget);
          expect(find.text(l10n.iapAllOwned), findsOneWidget);
          final buy = tester.widget<PrimaryButton>(
            find.widgetWithText(PrimaryButton, l10n.iapBuy),
          );
          expect(buy.onPressed, isNull);
          await tester.pump(const Duration(seconds: 2));
        },
        variant: TargetPlatformVariant.only(TargetPlatform.iOS),
      );

      testWidgets(
        'success: snackbar, packages refreshed',
        (tester) async {
          final repo = FakeIapRepository();
          final store = FakeIapStore();
          final iap = await pumpPackages(tester, repo: repo, store: store);
          iap.bindSession(authenticated: true);
          await tester.tap(find.text(l10n.iapBuy));
          await tester.pump();
          store.emit([purchased()]);
          await tester.pumpAndSettle();
          expect(find.text(l10n.iapSuccess), findsOneWidget);
          expect(store.completed, hasLength(1));
          expect(repo.fetchCalls, greaterThanOrEqualTo(2));
          await tester.pump(const Duration(seconds: 2));
        },
        variant: TargetPlatformVariant.only(TargetPlatform.iOS),
      );

      testWidgets(
        'a server refusal shows its message; pending and verifying show '
        'a status line',
        (tester) async {
          final repo = FakeIapRepository()
            ..submitAnswers = [
              const IapFailure(IapFailureCode.accountMismatch, statusCode: 403),
            ];
          final store = FakeIapStore();
          final iap = await pumpPackages(tester, repo: repo, store: store);
          iap.bindSession(authenticated: true);
          await tester.tap(find.text(l10n.iapBuy));
          await tester.pump();
          store.emit([
            const IapStoreTransaction(
              productId: 'com.wael.app.pkg.year1',
              status: IapStoreStatus.pending,
            ),
          ]);
          await tester.pump();
          expect(find.text(l10n.iapPending), findsOneWidget);

          store.emit([purchased()]);
          await tester.pumpAndSettle();
          expect(find.text(l10n.iapErrorOtherAccount), findsOneWidget);
          expect(store.completed, isEmpty);
          await tester.pump(const Duration(seconds: 2));
        },
        variant: TargetPlatformVariant.only(TargetPlatform.iOS),
      );

      testWidgets(
        'cancelled shows nothing',
        (tester) async {
          final store = FakeIapStore();
          final iap = await pumpPackages(tester, store: store);
          iap.bindSession(authenticated: true);
          await tester.tap(find.text(l10n.iapBuy));
          await tester.pump();
          store.emit([
            const IapStoreTransaction(
              productId: 'com.wael.app.pkg.year1',
              status: IapStoreStatus.cancelled,
            ),
          ]);
          await tester.pumpAndSettle();
          for (final t in [
            l10n.iapSuccess,
            l10n.iapPending,
            l10n.iapVerifying,
            l10n.iapErrorRetryLater,
          ]) {
            expect(find.text(t), findsNothing);
          }
          await tester.pump(const Duration(seconds: 2));
        },
        variant: TargetPlatformVariant.only(TargetPlatform.iOS),
      );

      testWidgets(
        'Restore Purchases with nothing to restore says so',
        (tester) async {
          final store = FakeIapStore();
          final iap = await pumpPackages(tester, store: store);
          iap.bindSession(authenticated: true);
          await tester.ensureVisible(find.text(l10n.iapRestorePurchases));
          await tester.tap(find.text(l10n.iapRestorePurchases));
          await tester.pumpAndSettle();
          expect(store.restoreCalls, 1);
          expect(find.text(l10n.iapRestoreNothing), findsOneWidget);
          await tester.pump(const Duration(seconds: 2));
        },
        variant: TargetPlatformVariant.only(TargetPlatform.iOS),
      );

      testWidgets(
        'load failure: message with retry; empty list: empty state',
        (tester) async {
          final repo = FakeIapRepository()
            ..fetchError = const IapFailure(IapFailureCode.network);
          await pumpPackages(tester, repo: repo);
          expect(find.text(l10n.iapLoadFailed), findsOneWidget);

          repo
            ..fetchError = null
            ..catalog = IapCatalog.fromJson({
              'app_account_token': kToken,
              'packages': [],
            });
          await tester.tap(find.text(l10n.retry));
          await tester.pumpAndSettle();
          expect(find.text(l10n.iapNoPackages), findsOneWidget);
          await tester.pump(const Duration(seconds: 2));
        },
        variant: TargetPlatformVariant.only(TargetPlatform.iOS),
      );
    });

    group('Packages entry [$name]', () {
      Future<void> pumpHome(WidgetTester tester) => pumpScreen(
        tester,
        locale,
        const HomeScreen(),
        extraProviders: [
          ChangeNotifierProvider<AcademyCatalogProvider>.value(
            value: AcademyCatalogProvider(fake()),
          ),
          ChangeNotifierProvider<HomeProvider>.value(
            value: HomeProvider(director: testDirector),
          ),
          ChangeNotifierProvider<IapProvider>.value(value: fakeIapProvider()),
        ],
        size: const Size(390, 1600),
      );

      Future<void> pumpCourses(WidgetTester tester) => pumpScreen(
        tester,
        locale,
        const CoursesScreen(),
        extraProviders: [
          ChangeNotifierProvider<AcademyCatalogProvider>.value(
            value: AcademyCatalogProvider(fake()),
          ),
          ChangeNotifierProvider<HomeProvider>.value(
            value: HomeProvider(director: testDirector),
          ),
          ChangeNotifierProvider<IapProvider>.value(value: fakeIapProvider()),
        ],
        size: const Size(390, 1600),
      );

      testWidgets('iOS: Home and Courses show the packages entry, which opens '
          '/packages', (tester) async {
        // Courses first: re-pumping keeps a pushed route on top.
        await pumpCourses(tester);
        expect(find.byType(PackagesEntryTile), findsOneWidget);

        await pumpHome(tester);
        expect(find.byType(PackagesEntryTile), findsOneWidget);
        expect(find.text(l10n.iapPackagesTitle), findsOneWidget);
        await tester.tap(find.byType(PackagesEntryTile));
        await tester.pumpAndSettle();
        expect(find.text('route:/packages'), findsOneWidget);
        await tester.pump(const Duration(seconds: 2));
      }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

      testWidgets(
        'Android: no packages entry and no iap string on Home and Courses',
        (tester) async {
          await pumpHome(tester);
          expect(find.byType(PackagesEntryTile), findsNothing);
          expectNoIapText(l10n);
          await pumpCourses(tester);
          expect(find.byType(PackagesEntryTile), findsNothing);
          expectNoIapText(l10n);
        },
        variant: TargetPlatformVariant.only(TargetPlatform.android),
      );
    });

    group('Locked subject and packages [$name]', () {
      Future<FakeAcademyRepository> pumpDetail(
        WidgetTester tester, {
        required IapProvider iap,
      }) async {
        final repo = fake();
        repo.detailJson['d1'] = detailBody(price: 1800);
        await pumpScreen(
          tester,
          locale,
          const CourseDetailScreen(courseId: 'd1'),
          extraProviders: [
            ChangeNotifierProvider<AcademyCatalogProvider>.value(
              value: AcademyCatalogProvider(repo),
            ),
            ChangeNotifierProvider(
              create: (_) => HomeProvider(director: testDirector),
            ),
            ChangeNotifierProvider<IapProvider>.value(value: iap),
          ],
          size: const Size(390, 2400),
        );
        return repo;
      }

      testWidgets(
        'iOS: a subject in a package names it and opens that package',
        (tester) async {
          final repo = FakeIapRepository()
            ..catalog = IapCatalog.fromJson(packagesWith(['d1']));
          final academy = await pumpDetail(
            tester,
            iap: fakeIapProvider(repo: repo),
          );
          expect(academy.accessCalls, ['d1']);
          final pkgName = l10n.isArabic ? 'الفرقة الأولى' : 'Year 1';
          expect(find.text(l10n.iapSubjectInPackage(pkgName)), findsOneWidget);
          expect(find.text(l10n.openWhatsApp), findsNothing);
          expect(find.text(l10n.copySupportLink), findsNothing);
          expect(find.text(l10n.contactSupportToActivate), findsNothing);
          expect(find.text(l10n.enrolledStudentsOnly), findsNothing);
          expect(find.text(l10n.priceLabel), findsNothing);

          await tester.ensureVisible(find.text(l10n.iapViewPackage));
          await tester.tap(find.text(l10n.iapViewPackage));
          await tester.pumpAndSettle();
          expect(find.text('route:/packages:pkg_1'), findsOneWidget);
          await tester.pump(const Duration(seconds: 2));
        },
        variant: TargetPlatformVariant.only(TargetPlatform.iOS),
      );

      testWidgets(
        'iOS: a subject in no package shows the neutral text only',
        (tester) async {
          final academy = await pumpDetail(tester, iap: fakeIapProvider());
          expect(academy.accessCalls, ['d1']);
          expect(find.text(l10n.iapSubjectNotAvailable), findsOneWidget);
          expect(find.text(l10n.iapViewPackage), findsNothing);
          expect(find.byType(PrimaryButton), findsNothing);
          expect(find.text(l10n.openWhatsApp), findsNothing);
          expect(find.text(l10n.copySupportLink), findsNothing);
          expect(find.text(l10n.priceLabel), findsNothing);
          await tester.pump(const Duration(seconds: 2));
        },
        variant: TargetPlatformVariant.only(TargetPlatform.iOS),
      );

      testWidgets(
        'Android: the locked subject renders no iap string',
        (tester) async {
          final repo = FakeIapRepository()
            ..catalog = IapCatalog.fromJson(packagesWith(['d1']));
          final iap = fakeIapProvider(repo: repo);
          await pumpDetail(tester, iap: iap);
          expectNoIapText(l10n);
          expect(repo.fetchCalls, 0);
          expect(find.text(l10n.requestPending), findsOneWidget);
        },
        variant: TargetPlatformVariant.only(TargetPlatform.android),
      );
    });
  }
}
