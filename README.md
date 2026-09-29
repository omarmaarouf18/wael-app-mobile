# wael-app frontend (Flutter)

Real auth against the wael-app gateway; academy content stays mock-backed
behind repository interfaces until the core service ships.

## Backend connection

The API base URL comes from `--dart-define=API_BASE_URL` (see
`lib/core/app_config.dart`). No URL is hardcoded in the app.

Per-platform defaults (local compose, default gateway port 8080):

| Target            | Default `API_BASE_URL`        |
|-------------------|-------------------------------|
| Android emulator  | `https://10.0.2.2:8080`       |
| iOS simulator     | `https://localhost:8080`      |
| Desktop / web     | `https://localhost:8080`      |
| Physical device   | `https://<host-LAN-IP>:8080`  |

Local compose serves the gateway over HTTPS with a self-signed certificate,
which debug builds accept (`AppConfig.allowSelfSigned` is debug-only).
Release builds always verify certificates.

Examples:

```bash
# Android emulator against local compose on default ports
flutter run --dart-define=API_BASE_URL=https://10.0.2.2:8080

# Host gateway on a custom port (see infrastructure/.env.local)
flutter run --dart-define=API_BASE_URL=https://10.0.2.2:18080

# Physical device on the same network (replace with the host LAN IP)
flutter run --dart-define=API_BASE_URL=https://192.168.1.50:8080
```

## Auth behavior

- Tokens live in `flutter_secure_storage` (never plain files or
  shared preferences).
- The client injects the JWT, refreshes once on 401, then logs out.
- HTTP 429 (gateway rate limit / auth lockout) shows the backend message.
- Backend dev OTPs render in debug builds only (`kDebugMode`), never in
  release builds.

## Quality gates

```bash
dart format lib/ test/
flutter analyze
flutter test
```
