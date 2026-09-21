# Migration validation

Validated locally on 2026-09-22 with Flutter 3.47.3 / Dart 3.13.3,
Xcode 27.0, Android SDK platform 36 and build tools 36.0.0.

| Check | Result |
| --- | --- |
| `flutter analyze` | No issues |
| `flutter test` | 151 tests passed |
| iOS integration test | Passed on iPad Pro 11-inch (M4), iOS 18.5 simulator |
| Android integration test | Passed on Pixel Tablet emulator, API 33 |
| Android release APK | Built successfully, development debug signing |
| iOS device release | Built successfully with `--no-codesign` |
| iOS simulator debug | Built and launched successfully |
| Release Android permissions | RECORD_AUDIO; no INTERNET |
| iOS Info.plist / PrivacyInfo.xcprivacy | `plutil -lint` passed |

The native integration test exercises platform channel registration, local storage,
tuning persistence, PCM16 WAV save/load, playback/pause/resume, DSP isolate and UI
pitch history. It generates a 440 Hz fixture and checks the detected pitch within
3 Hz. Test WAV and temporary preference changes are cleaned up. It does not use
the microphone or modify recordings created by the user.

Unit tests cover tuning expression grammar and legacy payloads; FFT vs direct DFT;
known frequencies, noise and harmonic-dominant signals; 8–192 kHz streaming
resampling; bounded worker backpressure and source timestamps; WAV boundaries;
settings and recording persistence; denied permissions, initialization disposal,
backgrounding, saving failures, interrupted playback, and frozen history.
Widget tests cover 320×568, 375×812, 812×375, 1024×768, 2× text scaling,
and a very dense imported equave.

## Device acceptance still needed

- iPhone and Android physical microphone signal, noise and latency.
- Permission dialogs and recovery from a denied microphone permission.
- Bluetooth/wired headset changes and phone-call interruptions.
- Picking real files from Files / Android document providers.
- Production signing and store submission configuration.

The local Android emulator used for the smoke test was started read-only and
stopped after verification. The pre-existing iOS simulator was left available.

## Logarithmic FFT spectrogram

Validated on 2026-09-22: `flutter analyze` reported no issues, all 161 Flutter
unit/widget tests passed, and `flutter build apk --debug --no-pub` succeeded.
The added checks cover equal octave spacing, Hann-window amplitude calibration
(0 and −6 dBFS), silent/DC input, harmonics independent of the pitch gate,
isolate spectrum delivery, bounded/frozen spectrum history, mode switching,
actual raster output and disposal during pending image decoding.

The [rendered FFT preview](screenshots/fft-spectrum.png) uses a synthetic harmonic
glissando with silent intervals passed through the real analyzer and Flutter
renderer. It is a test fixture, not a microphone recording. The chart uses the
active tuning's note names on a logarithmic C1–C9 axis (approximately 33 Hz to
8.37 kHz); 576 display bands do not increase the 4096-point FFT's physical
frequency resolution.
