#!/usr/bin/env bash
set -euo pipefail

PKG="com.funkin.karaoke"

echo "▶ Android preflight check for package: $PKG"
echo

# --- Helpers ---
fail() { echo "❌ $1"; exit 1; }
warn() { echo "⚠️  $1"; }
ok()   { echo "✅ $1"; }

# Normalize line endings just in case (no-op if already fine)
if command -v sed >/dev/null 2>&1; then
  sed -i '' $'s/\r$//' scripts/android_preflight.sh 2>/dev/null || true
fi

# --- Files we care about ---
APP_MANIFEST="android/app/src/main/AndroidManifest.xml"
APP_GRADLE_GROOVY="android/app/build.gradle"
APP_GRADLE_KTS="android/app/build.gradle.kts"
MAIN_KT="android/app/src/main/kotlin/${PKG//./\/}/MainActivity.kt"
GOOGLE_JSON="android/app/google-services.json"

# --- Check AndroidManifest.xml (activity name) ---
[ -f "$APP_MANIFEST" ] || fail "Missing $APP_MANIFEST"
grep -q 'android:name=".MainActivity"' "$APP_MANIFEST" || warn "AndroidManifest: activity not '.MainActivity' (double-check)."
ok "AndroidManifest present"

# --- Check build.gradle / build.gradle.kts (namespace + applicationId) ---
HAS_GRADLE=false
if [ -f "$APP_GRADLE_GROOVY" ]; then
  HAS_GRADLE=true
  grep -q "namespace \(['\"]$PKG['\"]\)" "$APP_GRADLE_GROOVY" || fail "build.gradle: namespace must be '$PKG'"
  grep -q "applicationId \(['\"]$PKG['\"]\)" "$APP_GRADLE_GROOVY" || fail "build.gradle: applicationId must be '$PKG'"
  ok "build.gradle namespace & applicationId OK"
fi

if [ -f "$APP_GRADLE_KTS" ]; then
  HAS_GRADLE=true
  grep -q "namespace *= *\"$PKG\"" "$APP_GRADLE_KTS" || fail "build.gradle.kts: namespace must be '$PKG'"
  grep -q "applicationId *= *\"$PKG\"" "$APP_GRADLE_KTS" || fail "build.gradle.kts: applicationId must be '$PKG'"
  ok "build.gradle.kts namespace & applicationId OK"
fi

$HAS_GRADLE || fail "No app Gradle file found (expected $APP_GRADLE_GROOVY or $APP_GRADLE_KTS)."

# --- Check MainActivity.kt file path & package line ---
[ -f "$MAIN_KT" ] || fail "Missing $MAIN_KT (folder must mirror package: android/app/src/main/kotlin/com/funkin/karaoke/MainActivity.kt)"
grep -q "^package $PKG" "$MAIN_KT" || fail "MainActivity.kt package must be 'package $PKG'"
grep -q "import io.flutter.embedding.android.FlutterActivity" "$MAIN_KT" || fail "MainActivity.kt must import FlutterActivity"
ok "MainActivity.kt path & package OK"

# --- Check google-services.json package_name ---
if [ -f "$GOOGLE_JSON" ]; then
  grep -q "\"package_name\": *\"$PKG\"" "$GOOGLE_JSON" || warn "google-services.json package_name is not '$PKG' — re-download from Firebase."
  ok "google-services.json present"
else
  warn "Missing android/app/google-services.json (required for Firebase on Android)."
fi

echo
ok "Preflight finished. If no ❌ above, you’re good to build."
