# VocalPitchMonitor (no-ads) — with musescore-xen-tuner scale configs

An Android pitch monitor app built from scratch (pure Java, no Gradle, no
third-party SDKs) that is behaviorally and visually alike the original
`VocalPitchMonitor.apk` — **without any ads** — and adds **tuning-config
importing** using the exact text grammar of
[musescore-xen-tuner](musescore-xen-tuner/).

Build output: `VocalPitchMonitor-NoAds.apk` (signed, installable).

## Features

- **Pitch monitor** (faithful port): 4096-point FFT + autocorrelation pitch
  detection with octave-error correction and harmonic-sum refinement, the
  pitch-history graph, big note name, tuner needle, BPM/metronome, and the
  original settings (threshold, zooming, calibration, transpose, colors,
  note names, button visibility, …).
- **No ads**: no AdMob, no Google Play Services, no INTERNET permission.
  The only permission is `RECORD_AUDIO`.
- **Tuning-config only**: the app always runs on a tuning config. The bundled
  **"7ed2 on C"** scale is the default; import others via the scale button.
- **Scale config importing** (`Scale` button → *Import tuning config…*):
  pick any `.txt`/`.json` tuning config through the system file picker.
- **The app remembers the config file and always runs on it**:
  - the file URI and display name are persisted in app preferences;
  - a parsed cache of the scale is persisted as well;
  - on every launch the file is re-read and re-parsed automatically;
  - if the file is gone or the URI permission was lost, the cached scale is
    still applied — closing/killing the app never corrupts the active scale.
- **Continuous microtonal pitch**: the FFT+ACF detector is refined with
  parabolic interpolation (ACF lag and log-power FFT peak) so the pitch line
  tracks smoothly — sub-cent precision, no octave jumps on voice-like
  spectra.
- **Full musescore-xen-tuner grammar** for pitches (see
  `app/src/com/tadaoyamaoka/vocalpitchmonitor/ScaleConfig.java`):
  - `1200c` / `1/13*1901.955c` — cents, arbitrary arithmetic expression
  - `3/2`, `1/1` — frequency ratios (→ cents via log2)
  - `5\53`, `72\186ed6` — equal divisions (`a\b` = a steps of b-edo;
    `a\bedc` = a steps of b-edc, c defaults to 2)
  - `1000me`, `ie2` — xen-tuner decimal units
  - `Math.pow(3/2,3)`, `MATH.log(3)/Math.LN2`, `2**3`, `^`, `PI`, `E`, … —
    `Math.*`/`MATH.*` functions and constants (JS-`eval`-like semantics)
  - reference note `甲4: 320` / `A4: 440` / `E4: 320` — scale names or
    standard letter notes; the reference anchors the first listed nominal
    (xen-tuner relative-nominal-0 semantics)
  - optional scale-name line: `甲 乙 丙 丁 戊 己 庚 辛 壬 癸`
  - optional per-note color line: `136 84 84 …` — one gray value per scale
    note inside a period (do not include the next-period note); each value
    is R=G=B in 0..255 (136 → RGB(136,136,136)). A missing line falls back
    to the same defaults (first note 136, the others 84); a shorter list
    wraps around from the start.
  - `//` comments and blank lines ignored, UTF-8 (BOM tolerated)
- **Note colors come from the tuning config**: each scale note's grid row and
  left-column label are drawn in its config color. The old "Scale" and
  "Chromatic" color groups were removed from Settings → Color (only Pitch,
  Beats and Metronome colors remain there).
- Custom scales are rendered on their own grid (rows at the exact scale-note
  cents across periods, names + register on the left), the big display shows
  the nearest scale note, and the left column is sized to the widest note
  name so wide glyphs (甲, 癸, …) are never clipped. The top tuner strip
  shows a fixed ±(1200/7)-cent window — the ratio 2^(±1/7) — around the
  detected pitch: long ticks sit exactly on the scale notes (name + register
  below) and five short ticks between every adjacent pair of notes divide
  the log-pitch interval into six equal parts.
- "Semitone" is not meaningful for arbitrary tuning scales: the two semitone
  settings ("Indicate lines of a semitone", "Display semitones on the
  vertical axis") were removed from Settings and are always off. The
  "Display frequency in Hz" option is on by default (also applied once when
  upgrading an older install).

## Project layout

```
app/                          Android app source (Java + resources)
  AndroidManifest.xml
  res/                        layouts/drawables/values/menus (from the original UI)
  src/com/tadaoyamaoka/vocalpitchmonitor/
    MainActivity.java         main logic, config import + persistence
    MainSurfaceView.java      pitch display (standard + custom-scale modes)
    Analyzer.java             FFT+ACF pitch detection (ported)
    FFT4g.java                Ooura real FFT (ported)
    Recorder.java             AudioRecord/AudioTrack capture & playback
    Settings.java             preferences (+ config URI/name/payload keys)
    SettingsActivity.java     settings UI (ported)
    LoadActivity.java         recorded-wav loader (ported)
    ColorPopupWindow.java     color picker (ported)
    LongClickRepeatAdapter.java (ported)
    ScaleConfig.java          musescore-xen-tuner config parser (new)
    MathEval.java             JS-eval-like expression evaluator (new)
tests/                        JVM unit tests for the parser + pitch detector
build.sh                      builds the APK with aapt2/javac/d8/apksigner
_work/                        build toolchain + reference APK decompilation
VocalPitchMonitor-NoAds.apk   the built, signed APK
```

## Building

Requires only a JDK (17) and the Android SDK build-tools + platform jars
(already staged under `_work/`; `build.sh` resolves them):

```bash
./build.sh          # -> VocalPitchMonitor-NoAds.apk
```

## Testing

```bash
# parser grammar + tuning-config tests (uses the real 天干音阶.txt etc.)
javac -d _build/test -encoding UTF-8 \
  tests/TestParser.java tests/TestPitch.java \
  app/src/com/tadaoyamaoka/vocalpitchmonitor/{MathEval,ScaleConfig,Analyzer,FFT4g}.java
java -cp _build/test TestParser   # grammar/conversion checks
java -cp _build/test TestPitch    # pitch detection on synthetic sines
```

## Using a tuning config

Example (`天干音阶.txt` — already in this folder):

```
// standard note
甲4: 320

// pitches of one period; the last one is the first note of the next period
0\186ed6 7\186ed6 16\186ed6 23\186ed6 30\186ed6 35\186ed6 42\186ed6 49\186ed6 58\186ed6 65\186ed6 72\186ed6
甲 乙 丙 丁 戊 己 庚 辛 壬 癸
```

1. Tap the scale name (top left, e.g. “C Major”).
2. Choose **Import tuning config…** and pick `天干音阶.txt`.
3. The monitor now displays the 天干 scale: detected notes as 甲4/乙4/…,
   grid rows at the exact scale pitches, register repeating every ~1200.76c
   (72/186 of the 6:1 equave).
4. The choice survives app restarts automatically.

## License

The original VocalPitchMonitor is open source (Apache-2.0, © tadaoyamaoka).
This port keeps the same package name and adds no proprietary components;
the xen-tuner grammar is ported from musescore-xen-tuner (GPL-3.0, © euwbah).
