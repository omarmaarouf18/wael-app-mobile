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
# Lowest-friction local target on Linux desktop (native Wayland/X11, localhost network loopback)
flutter run -d linux --dart-define=API_BASE_URL=https://localhost:18080

# Android emulator against local compose on default ports
flutter run --dart-define=API_BASE_URL=https://10.0.2.2:8080

# Host gateway on a custom port (see infrastructure/.env.local)
flutter run --dart-define=API_BASE_URL=https://10.0.2.2:18080

# Physical device on the same network (replace with the host LAN IP)
flutter run --dart-define=API_BASE_URL=https://192.168.1.50:8080
```

### Lowest-friction target on development machine
Linux desktop (`-d linux`) is the lowest-friction target on this machine:
1. **Zero emulator overhead**: Starts in seconds without KVM/Android emulator or simulator processes.
2. **Direct host loopback**: Connects directly to `https://localhost:18080` without NAT router aliases (`10.0.2.2`) or port forwarding.
3. **Full TLS support**: Uses `dart:io` `badCertificateCallback` directly for self-signed certificates in debug mode.

*(Note: On systems where `libsecret-1` headers are not in `/usr/lib64/pkgconfig`, point `PKG_CONFIG_PATH` to the libsecret sysroot).*

### Diagnostics screen (Debug Mode Only)
Navigate to `/debug` (or use the debug button in development builds) to access the diagnostics screen:
- Gateway base URL
- Session authentication state with masked user ID and email
- Live SSE stream connection status (connected / disconnected)
- Rolling buffer of the last 50 API calls (method, sanitized path without query parameters, HTTP status, latency)
- Completely excluded in release mode builds.

## Auth behavior

- Tokens live in `flutter_secure_storage` (never plain files or
  shared preferences).
- The client injects the JWT, refreshes once on 401, then logs out.
- HTTP 429 (gateway rate limit / auth lockout) shows the backend message.
- Backend dev OTPs render in debug builds only (`kDebugMode`), never in
  release builds.

## Quality gates

Offline gates (fast, deterministic, requires no Docker stack):

```bash
dart format lib/ test/
bash ../scripts/frontend_composition_gate.sh
flutter analyze
flutter test
```

The composition gate (`scripts/frontend_composition_gate.sh`) scans `lib/screens/` for raw
`Scaffold(`, `AppBar(`, `BoxDecoration(`, `TextStyle(`, `fontSize:`, `Color(0x...)`,
`Color.fromARGB(`, `Color.fromRGBO(`, `Colors.x` (except `Colors.transparent`), `.toUpperCase()` and `EdgeInsets.only` /
`fromLTRB`. Existing violations are recorded in `scripts/frontend_gate_baseline.txt` and
the gate is a ratchet: more violations than the baseline fails, and fewer also fails until
you lower the baseline in the same commit with `scripts/frontend_composition_gate.sh
--update`. It fails closed (exit 2) if `lib/screens` is missing. It runs after `dart format` in
`.githooks/pre-push` and in CI, followed by its self-test, `scripts/frontend_gate_test.sh`. Rules and token
reference: `docs/frontend/DESIGN_SYSTEM.md`; per-file counts: `docs/frontend/STATUS.md`.

*Note: In offline CI, 22 live integration tests across `live_matrix_test.dart`, `gateway_ratelimit_test.dart`, `sse_reconnect_test.dart`, and `failure_modes_test.dart` are skipped (`skip: !runLive`) because they require the live Docker Compose microservice stack.*

### Running Live Integration Suites Against the Stack

When the local microservice stack is running (`docker compose -p wael-app up -d`), execute the env-gated integration suites using `--dart-define=RUN_LIVE_TESTS=true`:

```bash
# 1. Full live behavior matrix (auth, lockout, token rotation, inbox, SSE delivery)
flutter test --dart-define=RUN_LIVE_TESTS=true test/live_matrix_test.dart

# 2. Gateway rate limiting (100 req/min burst + 429 Retry-After verification)
flutter test --dart-define=RUN_LIVE_TESTS=true test/gateway_ratelimit_test.dart

# 3. Live SSE reconnection & backoff (includes notification-service docker restart)
flutter test --dart-define=RUN_LIVE_TESTS=true test/sse_reconnect_test.dart

# 4. Service failure modes (sequentially stops & restarts gateway, auth, notif, redis, mongo)
flutter test --dart-define=RUN_LIVE_TESTS=true test/failure_modes_test.dart
```
