import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:nested/nested.dart' show SingleChildWidget;
import 'package:provider/provider.dart';

import 'core/theme.dart';

import 'core/constants.dart';
import 'l10n/app_localizations.dart';
import 'models/course.dart';

// Providers
import 'providers/locale_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/home_provider.dart';
import 'providers/courses_provider.dart';
import 'providers/payment_provider.dart';
import 'providers/ebook_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/notifications_provider.dart';

// Services
import 'services/push_notification_service.dart';

// Screens
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/otp_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/main_shell.dart';
import 'screens/course_detail_screen.dart';
import 'screens/payment_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/ebook_screen.dart';
import 'debug/component_library_screen.dart';
import 'debug/diagnostics_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PushNotificationService().initialize();
  runApp(const WaelApp());
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
  const WaelApp({super.key, this.providersOverride});

  /// Injected providers for widget tests (fake auth repository, memory
  /// token store). Production passes nothing and gets the real bindings.
  final List<SingleChildWidget>? providersOverride;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers:
          providersOverride ??
          [
            ChangeNotifierProvider(create: (_) => LocaleProvider()),
            ChangeNotifierProvider(create: (_) => AuthProvider()),
            ChangeNotifierProvider(create: (_) => HomeProvider()),
            ChangeNotifierProvider(create: (_) => CoursesProvider()),
            ChangeNotifierProvider(create: (_) => PaymentProvider()),
            ChangeNotifierProvider(create: (_) => EBookProvider()),
            ChangeNotifierProvider(create: (_) => SettingsProvider()),
            ChangeNotifierProvider(create: (_) => NotificationsProvider()),
          ],
      child: Consumer<LocaleProvider>(
        builder: (context, localeProvider, _) {
          return MaterialApp(
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
                final courseId =
                    settings.arguments as String? ?? 'architectural-discipline';
                return MaterialPageRoute(
                  builder: (context) => CourseDetailScreen(courseId: courseId),
                );
              }
              if (settings.name == '/payment') {
                final course =
                    settings.arguments as Course? ??
                    Provider.of<CoursesProvider>(
                      context,
                      listen: false,
                    ).allCourses.first;
                return MaterialPageRoute(
                  builder: (context) => PaymentScreen(course: course),
                );
              }
              return null;
            },
          );
        },
      ),
    );
  }
}
