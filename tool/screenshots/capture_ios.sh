#!/usr/bin/env bash
# App Store screenshots on an iOS Simulator (macOS with Xcode only).
# Run from frontend/:  tool/screenshots/capture_ios.sh OUT_DIR
#
# Needs API_BASE_URL (https), SHOT_EMAIL, SHOT_PASSWORD (the store demo
# account). Optional: SHOT_LANGS ("ar en"), SHOT_DEVICES (comma-separated
# Simulator device names, first available wins), IOS_BUNDLE_ID, SHOT_LOG_DIR.
#
# Creates a throwaway Simulator of the newest 6.9-inch iPhone, fixes the
# status bar (9:41, full battery, full signal), and for each language runs
# tool/screenshots/main.dart with `flutter run` (debug: the Simulator runs
# debug builds only; the app shows no debug-only UI on these screens). Each
# `WAEL_SHOT:<lang>:<name>` line the tour prints becomes
# OUT_DIR/<lang>/<name>.png. Written for the macOS system bash (3.2).
set -euo pipefail

out="${1:?usage: capture_ios.sh OUT_DIR}"
: "${API_BASE_URL:?API_BASE_URL is required}"
: "${SHOT_EMAIL:?SHOT_EMAIL is required}"
: "${SHOT_PASSWORD:?SHOT_PASSWORD is required}"
case "$API_BASE_URL" in https://*) ;; *) echo "API_BASE_URL must be https" >&2; exit 1 ;; esac
langs="${SHOT_LANGS:-ar en}"
devices="${SHOT_DEVICES:-iPhone 17 Pro Max,iPhone 16 Pro Max}"
bundle_id="${IOS_BUNDLE_ID:-com.wael.app}"
log_dir="${SHOT_LOG_DIR:-${TMPDIR:-/tmp}/wael-shot-logs}"
for lang in $langs; do
  case "$lang" in ar | en) ;; *) echo "unsupported language: $lang" >&2; exit 1 ;; esac
done
mkdir -p "$out" "$log_dir"

# Newest iOS runtime that offers one of the wanted device types.
pick="$(xcrun simctl list runtimes -j | python3 -c '
import json, sys
want = sys.argv[1].split(",")
rts = [r for r in json.load(sys.stdin)["runtimes"]
       if r.get("isAvailable") and "iOS" in (r.get("platform") or r.get("name", ""))]
rts.sort(key=lambda r: [int(x) for x in r["version"].split(".")])
for r in reversed(rts):
    types = {d["name"]: d["identifier"] for d in r.get("supportedDeviceTypes", [])}
    for w in want:
        if w in types:
            print(r["identifier"] + "|" + types[w] + "|" + w + " (iOS " + r["version"] + ")")
            sys.exit(0)
sys.exit("no available iOS runtime offers: " + ", ".join(want))
' "$devices")"
runtime="${pick%%|*}"
rest="${pick#*|}"
device_type="${rest%%|*}"
label="${rest#*|}"
echo "Simulator: $label"

udid="$(xcrun simctl create "Wael store screenshots" "$device_type" "$runtime")"
flutter_pid=""
cleanup() {
  if [ -n "$flutter_pid" ]; then kill "$flutter_pid" 2>/dev/null || true; fi
  xcrun simctl shutdown "$udid" >/dev/null 2>&1 || true
  xcrun simctl delete "$udid" >/dev/null 2>&1 || true
}
trap cleanup EXIT

xcrun simctl boot "$udid"
xcrun simctl bootstatus "$udid" -b >/dev/null
xcrun simctl ui "$udid" appearance dark
xcrun simctl status_bar "$udid" override \
  --time "9:41" --dataNetwork wifi --wifiMode active --wifiBars 3 \
  --cellularMode active --cellularBars 4 \
  --batteryState charged --batteryLevel 100

for lang in $langs; do
  echo "== $lang"
  xcrun simctl uninstall "$udid" "$bundle_id" >/dev/null 2>&1 || true
  log="$log_dir/flutter-run-$lang.log"
  marks="$log_dir/marks-$lang.txt"
  : > "$marks"
  flutter run -d "$udid" --debug -t tool/screenshots/main.dart \
    --dart-define=API_BASE_URL="$API_BASE_URL" \
    --dart-define=SHOT_EMAIL="$SHOT_EMAIL" \
    --dart-define=SHOT_PASSWORD="$SHOT_PASSWORD" \
    --dart-define=SHOT_LANG="$lang" \
    < /dev/null > "$log" 2>&1 &
  flutter_pid=$!

  handled=0
  deadline=$((SECONDS + 1500))
  while :; do
    grep -o 'WAEL_SHOT:[a-z]*:[A-Za-z0-9_]*' "$log" > "$marks" || true
    total="$(wc -l < "$marks" | tr -d ' ')"
    while [ "$handled" -lt "$total" ]; do
      handled=$((handled + 1))
      line="$(sed -n "${handled}p" "$marks")"
      shot_lang="$(echo "$line" | cut -d: -f2)"
      name="$(echo "$line" | cut -d: -f3)"
      mkdir -p "$out/$shot_lang"
      xcrun simctl io "$udid" screenshot --type=png "$out/$shot_lang/$name.png" >/dev/null 2>&1
      size="$(sips -g pixelWidth -g pixelHeight "$out/$shot_lang/$name.png" | awk '/pixel/ {print $2}' | paste -sd x -)"
      echo "captured $shot_lang/$name.png ($size)"
    done
    if grep -q 'WAEL_SHOT_FAIL' "$log"; then
      grep -h 'WAEL_SHOT_FAIL' "$log" >&2
      exit 1
    fi
    if grep -q 'WAEL_SHOT_DONE' "$log"; then
      break
    fi
    if ! kill -0 "$flutter_pid" 2>/dev/null; then
      echo "flutter run exited before the tour finished; last lines:" >&2
      tail -n 60 "$log" >&2
      exit 1
    fi
    if [ "$SECONDS" -ge "$deadline" ]; then
      echo "timed out; last lines:" >&2
      tail -n 60 "$log" >&2
      exit 1
    fi
    sleep 1
  done
  grep -h 'WAEL_SHOT_NOTE' "$log" || true
  kill "$flutter_pid" 2>/dev/null || true
  wait "$flutter_pid" 2>/dev/null || true
  flutter_pid=""
done

echo "Screenshots in $out"
