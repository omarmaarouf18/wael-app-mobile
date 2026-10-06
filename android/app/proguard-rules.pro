# Flutter wrapper and engine
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# flutter_secure_storage
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# webview_flutter (used by youtube_player_iframe)
-keep class io.flutter.plugins.webviewflutter.** { *; }
-keep class android.webkit.** { *; }
-keepattributes *JavascriptInterface*
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

# url_launcher
-keep class io.flutter.plugins.urllauncher.** { *; }

# package_info_plus
-keep class dev.fluttercommunity.plus.packageinfo.** { *; }
