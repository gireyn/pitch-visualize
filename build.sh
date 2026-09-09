#!/usr/bin/env bash
# Build a signed, no-ads VocalPitchMonitor APK using the Android SDK build tools
# directly (no Gradle). Output: VocalPitchMonitor-NoAds.apk in the project root.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
APP="$ROOT/app"
BUILD="$ROOT/_build"
SDK="$ROOT/_work/sdk"

AAPT2="$SDK/android-15/aapt2"
ANDROID_JAR="$SDK/android-35/android.jar"
D8="$SDK/android-15/d8"
ZIPALIGN="$SDK/android-15/zipalign"
APKSIGNER="$SDK/android-15/apksigner"
KEYSTORE="$BUILD/debug.keystore"

# JDK: prefer the downloaded BellSoft JDK 17, fall back to any javac on PATH
JDK_DIR="$(ls -d "$ROOT"/_work/tools/jdk-17* 2>/dev/null | head -1 || true)"
if [ -n "$JDK_DIR" ]; then
    JAVAC="$JDK_DIR/bin/javac"
    KEYTOOL="$JDK_DIR/bin/keytool"
    export PATH="$JDK_DIR/bin:$PATH"
else
    JAVAC="$(command -v javac)"
    KEYTOOL="$(command -v keytool)"
fi
echo "Using javac: $JAVAC"

rm -rf "$BUILD"
mkdir -p "$BUILD/gen" "$BUILD/classes" "$BUILD/dex"

echo "== 1/6 aapt2 compile =="
"$AAPT2" compile --dir "$APP/res" -o "$BUILD/res.zip"

echo "== 2/6 aapt2 link =="
"$AAPT2" link \
    -o "$BUILD/base.apk" \
    -I "$ANDROID_JAR" \
    --manifest "$APP/AndroidManifest.xml" \
    --java "$BUILD/gen" \
    --min-sdk-version 21 \
    --target-sdk-version 35 \
    --version-code 4 \
    --version-name 4.0 \
    "$BUILD/res.zip"

echo "== 3/6 javac =="
find "$APP/src" "$BUILD/gen" -name "*.java" > "$BUILD/sources.txt"
"$JAVAC" \
    -source 1.8 -target 1.8 \
    -bootclasspath "$ANDROID_JAR" \
    -encoding UTF-8 \
    -d "$BUILD/classes" \
    @"$BUILD/sources.txt"

echo "== 4/6 d8 =="
"$D8" --release --lib "$ANDROID_JAR" --min-api 21 \
    --output "$BUILD/dex" \
    $(find "$BUILD/classes" -name "*.class")

echo "== 5/6 package =="
cp "$BUILD/base.apk" "$BUILD/unsigned.apk"
(cd "$BUILD/dex" && zip -q -X "$BUILD/unsigned.apk" classes.dex)
"$ZIPALIGN" -f 4 "$BUILD/unsigned.apk" "$BUILD/aligned.apk"

echo "== 6/6 sign =="
if [ ! -f "$KEYSTORE" ]; then
    "$KEYTOOL" -genkeypair -keystore "$KEYSTORE" -alias androiddebugkey \
        -storepass android -keypass android -keyalg RSA -keysize 2048 -validity 10000 \
        -dname "CN=Android Debug,O=Android,C=US" >/dev/null 2>&1
fi
"$APKSIGNER" sign --ks "$KEYSTORE" --ks-pass pass:android --key-pass pass:android \
    --out "$ROOT/VocalPitchMonitor-NoAds.apk" "$BUILD/aligned.apk"

echo "== done: $ROOT/VocalPitchMonitor-NoAds.apk =="
"$APKSIGNER" verify --verbose "$ROOT/VocalPitchMonitor-NoAds.apk" | head -5
ls -la "$ROOT/VocalPitchMonitor-NoAds.apk"
