# wael-app frontend (Flutter)

Real auth against the wael-app gateway. Academy content is read through
`AcademyRepository` (`lib/repositories/academy_repository.dart`: levels,
subjects, subject detail over `/api/v1/academy/`, models in
`lib/models/academy_catalog.dart`). Home, courses and course detail are on it;
the notes tab stays a coming-soon state until the server turns on
`features.files` (see "Notes & books" below, SPEC Phase 5). No
screen shows mock or demo data: anything a student sees as real comes from the
API, or from `lib/content/director_profile.dart` (the director card: the
owner's own name, verified 2026-10-02, and titles and photo supplied by the
owner on 2026-10-08). `docs/frontend/CONTENT-GAPS.md` lists what
exists and what is missing.
Opening a locked subject creates its access request through the real
`POST /api/v1/academy/subjects/{id}/access-request` (SPEC decision 9, Phase 3.3);
the subject screen then shows "Request pending". There is no payment screen in
the app (payment happens outside it, ADR-0003).

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

### Video player (Android)
Lesson videos play in a protected embedded player (`youtube_player_iframe`): Android
`FLAG_SECURE` (no screenshots or recording), a moving name-and-phone watermark, no
YouTube links or controls, and a server check on open and on every resume. The
YouTube logo is left visible (it cannot be tapped); a mask over the top edge hides
YouTube's title bar while the video is not playing and for 4 seconds after every
start, resume, replay and seek, and it is taller in full screen (owner decision
2026-10-05). Whether that fully covers the title bar on a real phone is still the
owner's device check. What it
hides, what it cannot, the backend contract and the manual device checks are in
`docs/frontend/VIDEO_PLAYER.md`. Release builds declare `INTERNET` in the main
manifest.

### Component library (Debug Mode Only)
`/components` shows every shared widget from `lib/widgets/` with an EN/AR toggle. Open the
diagnostics screen (`/debug`) and tap the widgets icon in the app bar. The route is only
registered when `kDebugMode` is true, so it is not in release builds. Verify with
`flutter test --dart-define=dart.vm.product=true test/debug_routes_test.dart` (runs the
route-table test as a release build) or by searching a release binary for
`ComponentLibraryScreen`.

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
- The client injects the JWT and refreshes once on a 401 (concurrent requests wait for
  that one refresh and share its result; a failed refresh logs out once).
- Restoring the session at start-up (`AuthProvider.tryRestore`) keeps the student logged
  in: a 401 from `/me` runs the refresh once; only a rejected refresh (401/403), a 403
  from `/me`, or `session_replaced` ends the session. A network error, timeout, 5xx, 408
  or 429 keeps the tokens and opens the app offline with a banner and a retry button
  (`Retry-After` is honoured on 408/429).
- HTTP 429 (gateway rate limit / auth lockout) shows the backend message.
- Backend dev OTPs render in debug builds only (`kDebugMode`), never in
  release builds.

## App behavior

- **Language**: the app starts in the device language (Arabic for `ar`, English for `en`,
  Arabic for any other); a language the student chose is saved in secure storage, wins on
  later launches and is loaded before the first frame (`lib/providers/locale_provider.dart`).
- **Timeouts**: 15 seconds per request, 30 seconds for the video `/play` call; a timeout is
  a network error. The splash screen waits at most 20 seconds for the session restore and
  then continues offline with the stored tokens.
- **Offline cache**: the catalog (levels, subjects, owned subjects and entitlements) is
  kept as small JSON in secure storage (`lib/core/catalog_cache.dart`), replaced on every
  refresh and cleared on logout. When the network fails the last copy is shown with the
  offline banner and a retry action; a global banner shows while the session or the
  catalog is offline and clears on the next success or when the app resumes. Lists show
  skeleton placeholders while loading, and subject detail, notifications and the e-book
  tab support pull-to-refresh (a no-op on the e-book tab while `features.files` is off).
- **Notes & books** (SPEC Phase 5 client, behind the app-config flag `features.files`;
  missing, false or never fetched means off): the notes tab ("المذكرات والكتب" / "Notes &
  books") lists the files of owned subjects grouped by subject, and subject detail offers
  Download on an owned subject's files (locked subjects show titles only, D4). A download
  streams `GET /api/v1/academy/subjects/{id}/files/{fileId}/download` into the app-private
  cache (`<cache>/pdfs`, `lib/services/file_downloads.dart`) with progress and cancel; then
  "Open" hands it to the phone's PDF app and "Share" opens the system share sheet
  (`lib/services/file_opener.dart`, a method channel in `MainActivity.kt` with the app's
  own `PdfFileProvider`: `content://` URI, read grant per intent, no storage permission, no
  in-app viewer). No PDF app shows a message with Share. Downloaded files open and share
  offline; sign-out, another account, or a fresh server answer that the subject is no
  longer owned or the file is gone deletes the copy. `path_provider` 2.1.6 (BSD-3-Clause)
  is pinned for the cache directory.
- **Fonts**: Cairo, Syne and Plus Jakarta Sans are bundled assets (`assets/fonts/`);
  `GoogleFonts.config.allowRuntimeFetching` is `false`, so no font is downloaded.
- **Support links**: a pending request, the Settings Help section, and the session-replaced notice on the login screen open the support WhatsApp chat with `url_launcher` (external app with browser fallback; only `https://wa.me` links are ever opened).
- **Public config & update gating**: the app reads `GET /api/v1/academy/app-config` via `AppConfigProvider` (terms/privacy URLs, support WhatsApp link, update metadata). If the installed version is strictly below `min_version`, a blocking update gate is shown at launch (`/update-gate`); if below `latest_version`, an inline update row is shown in Settings About section. Fails soft if unreachable, timeout, or malformed. This is the emergency lever for a broken build: raising `MIN_VERSION` on the server blocks older builds at their next cold start (details and limits in `AI_CONTEXT.md`). Unknown fields in any response are ignored and unknown codes, notification types and routes degrade to generic, safe behaviour (`test/forward_compat_test.dart`).
- **Legal pages**: the full terms, privacy policy and how-to-delete pages live on the website (`https://legal.elmetracademy.app`, English UI appends `#en`). The app links to them from signup (a short in-app summary sheet behind the consent checkbox), Settings > About and the delete-account screen; bundled fallback URLs (`lib/core/legal_links.dart`) keep every link working even with empty app-config or offline. Only `https` pages are ever opened.

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
