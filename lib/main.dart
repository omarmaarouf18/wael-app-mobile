import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:nested/nested.dart' show SingleChildWidget;
import 'package:provider/provider.dart';

import 'core/theme.dart';

import 'core/catalog_cache.dart';
import 'core/constants.dart';
import 'core/error_messages.dart';
import 'core/secure_store.dart';
import 'l10n/app_localizations.dart';
import 'widgets/app_shell.dart';
import 'widgets/themed_error_banner.dart';

// Providers
import 'providers/locale_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/academy_catalog_provider.dart';
import 'providers/home_provider.dart';
import 'providers/notifications_provider.dart';

// Services
import 'player/player_engine.dart';
import 'player/youtube_iframe_engine.dart';
import 'repositories/academy_repository.dart';

// Screens
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/otp_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/main_shell.dart';
import 'screens/course_detail_screen.dart';
import 'screens/video_player_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/ebook_screen.dart';
import 'debug/component_library_screen.dart';
import 'debug/diagnostics_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Saved language (or the device language for fresh installs) loads before
  // the first frame, so the app never flashes the wrong language.
  final tokenStore = SecureTokenStore();
  final localeProvider = LocaleProvider(store: tokenStore);
  await localeProvider.load();
  runApp(WaelApp(localeProvider: localeProvider, tokenStore: tokenStore));
}

/// Named routes. Debug-only routes (`/debug`, `/components`) are registered
/// only when [includeDebugRoutes] is true, which defaults to `kDebugMode`, a
/// compile-time constant: in release builds they are absent from the table and
/// their screens are tree-shaken.
Map<String, WidgetBuilder> buildAppRoutes({
  bool includeDebugRoutes = kDebugMode,
}) {
  return {
    '/splash': (context) => const SplashScreen(),
    '/login': (context) => const LoginScreen(),
    '/signup': (context) => const SignupScreen(),
    '/otp': (context) => const OtpScreen(),
    '/forgot': (context) => const ForgotPasswordScreen(),
    '/main': (context) => const MainShell(),
    '/notifications': (context) => const NotificationsScreen(),
    '/settings': (context) => const SettingsScreen(),
    '/ebooks': (context) => const EbookScreen(),
    if (includeDebugRoutes) ...{
      '/debug': (context) => const DiagnosticsScreen(),
      '/components': (context) => const ComponentLibraryScreen(),
    },
  };
}

class WaelApp extends StatelessWidget {
  const WaelApp({
    super.key,
    this.providersOverride,
    this.localeProvider,
    this.tokenStore,
  });

  /// Injected providers for widget tests (fake auth repository, memory
  /// token store). Production passes nothing and gets the real bindings.
  final List<SingleChildWidget>? providersOverride;

  /// Preloaded before the first frame in `main()` (production) so the saved
  /// or device language is already in place. Tests pass nothing and get a
  /// default provider.
  final LocaleProvider? localeProvider;

  /// Shared with [localeProvider] in production so the language choice and
  /// the session use one store. Tests pass nothing.
  final TokenStore? tokenStore;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers:
          providersOverride ??
          [
            ChangeNotifierProvider.value(
              value: localeProvider ?? LocaleProvider(),
            ),
            ChangeNotifierProvider(
              create: (ctx) => AuthProvider(
                tokenStore: tokenStore,
                localeReader: () =>
                    ctx.read<LocaleProvider>().locale.languageCode,
              ),
            ),
            ChangeNotifierProxyProvider<AuthProvider, AcademyCatalogProvider>(
              create: (ctx) => AcademyCatalogProvider(
                HttpAcademyRepository(ctx.read<AuthProvider>().authedApi),
                cache: SecureCatalogCache(),
              ),
              // Catalog data (owned flags, details) is per student: drop it
              // when the session ends.
              update: (_, auth, catalog) {
                // Runs during build, so it must not notify.
                if (!auth.isAuthenticated && !catalog!.isPristine) {
                  catalog.reset(notify: false);
                }
                return catalog!;
              },
            ),
            // The protected player's real engine and Android channel.
            Provider<PlayerDependencies>(
              create: (_) =>
                  PlayerDependencies(engineFactory: YoutubeIframeEngine.new),
            ),
            ChangeNotifierProvider(create: (_) => HomeProvider()),
            ChangeNotifierProvider(create: (_) => NotificationsProvider()),
          ],
      child: Consumer<LocaleProvider>(
        builder: (context, localeProvider, _) {
          return MaterialApp(
            navigatorKey: AuthProvider.navigatorKey,
            title: AppConstants.appName,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.darkTheme,
            locale: localeProvider.locale,
            supportedLocales: const [Locale('en', ''), Locale('ar', '')],
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            initialRoute: '/splash',
            routes: buildAppRoutes(),
            onGenerateRoute: (settings) {
              if (settings.name == '/course-details') {
                // Missing (or mistyped) arguments must never open a fake
                // subject: show an error the student can back out of.
                final args = settings.arguments;
                final courseId = args is String && args.isNotEmpty
                    ? args
                    : null;
                if (courseId == null) {
                  return MaterialPageRoute(
                    builder: (context) => const _MissingSubjectRoute(),
                  );
                }
                return MaterialPageRoute(
                  builder: (context) => CourseDetailScreen(courseId: courseId),
                );
              }
              if (settings.name == '/video-player') {
                // The arguments carry the academy's video id only, never the
                // YouTube id.
                final args = settings.arguments;
                if (args is VideoPlayerArgs) {
                  return MaterialPageRoute<PlayerExit>(
                    settings: const RouteSettings(name: '/video-player'),
                    builder: (context) => VideoPlayerScreen(args: args),
                  );
                }
              }
              return null;
            },
          );
        },
      ),
    );
  }
}

/// Opened `/course-details` without a subject id: an error with back
/// navigation, never a fake subject.
class _MissingSubjectRoute extends StatelessWidget {
  const _MissingSubjectRoute();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppShell(
      showBack: true,
      body: Center(
        child: Padding(
          padding: const EdgeInsetsDirectional.all(AppSpacing.marginMobile),
          child: ThemedErrorBanner(
            message: ErrorMessages.subjectNotFound(l10n.isArabic),
            onRetry: () => Navigator.of(context).pop(),
          ),
        ),
      ),
    );
  }
}
