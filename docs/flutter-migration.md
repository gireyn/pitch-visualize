# Flutter migration

The root project is now the Flutter application. The original Java app in `app/`,
its tests in `tests/`, and the manual Android `build.sh` remain as reference while
parity is verified. `docs/legacy-android.md` preserves the original documentation.

## Work packets

| Packet | Ownership | Dependencies | Validation |
| --- | --- | --- | --- |
| P1 tuning | `lib/domain/tuning`, tuning tests | none | grammar, reference anchors, arbitrary periods, colors, cache |
| P2 DSP | `lib/domain/audio`, pitch math, DSP tests | none | FFT scale, sine/harmonic accuracy, chunked resampling, Java comparison |
| P3 platform | `android`, `ios`, platform service | channel contract | native compilation, permissions, lifecycle, picker cancellation |
| P4 app | other Dart code, assets, docs, app tests | P1–P3 interfaces | WAV validation, state transitions, responsive UI, full builds |

The native bridge transports PCM16 little endian with the real hardware sample
rate. A persistent Dart isolate resamples to 44.1 kHz and runs the shared detector.
Only analysis is resampled; recorded WAV preserves the input sample rate.

Recordings stay in app-private storage. Imported tuning text is copied into local
preferences alongside a parsed cache, so moving the source document does not lose
the selected tuning. Reimport to apply later changes to an external source file.
Existing Android tuning payload and settings are migrated when the app is updated
with the same application ID and signing identity. No advertising or runtime
network service is used. Legacy WAV recordings remain in the same Android folder.

Audio collection starts with an explicit user action. Backgrounding finalizes a
recording and stops capture; playback pauses. Recording duration is bounded to
five minutes. Imported audio accepts mono/stereo uncompressed PCM16 WAV and is
normalized to mono. Audio formats and malformed lengths are checked before use.
