# Pitch Visual — Android pitch monitor with musescore-xen-tuner scale configs

*(formerly VocalPitchMonitor; the launcher label is **Pitch Visual**, the package id stays
`com.tadaoyamaoka.vocalpitchmonitor` so it upgrades over an existing install)*

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
  pick any `.txt`/`.json` tuning config through the system file picker. The
  name shown in the top-left corner follows the **file name** on every load,
  so renaming the config file renames it in the app.
- **Menu (bottom-right button)**: *Import tuning config…*, **Save as .wav**,
  **Import .wav**, *Settings*. "Save as .wav" opens the system save dialog
  with the timestamp pre-filled and writes the current recording there
  (44.1 kHz / 16-bit mono PCM WAV, no permission needed). "Import .wav" reads
  a picked WAV into memory for analysis and playback — nothing is copied and
  there is no hidden library any more (the old Save/Load pair that wrote to
  the app's private folder is gone, and with it the Load screen).
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
  - reference note `甲4: 319` / `A4: 440` / `C4: 262` — scale names or
    standard letter notes; the reference anchors the first listed nominal
    (xen-tuner relative-nominal-0 semantics)
  - optional scale-name line: `甲 乙 丙 丁 戊 己 庚 辛 壬 癸`
  - optional per-note color line: `136 84 84 …` — one gray value per scale
    note inside a period (do not include the next-period note); each value
    is R=G=B in 0..255 (136 → RGB(136,136,136)). A shorter list wraps around
    from the start; when there is no line at all, four default levels apply
    (see below).
  - `NN` as a note name means "this note has no name". The reference note
    must have a real name, and a scale in which every note is `NN` is a parse
    error, because the large display needs a name to show.
  - optional per-note **line-thickness** row: `6t 8t 6t …` — one value per
    scale note, again without the next-period note. The trailing `t` marks
    the row and is ignored by the arithmetic; one unit of thickness is 1/4
    of the value before it, so `8t` = 2.0 units, `7t` = 1.75, `6t` = 1.5,
    `7.5t` = 1.875, `13/2t` (= `6.5t`) = 1.625 and `5*Math.LN2t` ≈ 0.866.
    Anything the general expression evaluator accepts is allowed, and only
    that: pitch syntax (`\`, `ed`, the `c`/`me` suffixes, the `ie` prefix)
    is a parse error here, as is a wrong value count or a half-written row.
    Neither the colour row nor this row is required, and they may appear in
    either order; without the thickness row the classic defaults apply —
    2.0 units (8t) for the first note and 1.5 units (6t) for the others.
  - `//` comments and blank lines ignored, UTF-8 (BOM tolerated)
- **Note colors come from the tuning config**: each scale note's grid row and
  left-column label are drawn in its config color. Without a colour row there
  are four default levels — the first note ("root") named → 136, the first
  note unnamed and every other named note → 84, an unnamed non-root note → 42
  — so an unnamed note reads dimmer than a named one.
- **Unnamed notes**: an `NN` name is skipped when drawing labels (the grid row
  and its tuner tick stay, in their dimmed colour), and the large text above
  the tuner strip shows the nearest note that *does* have a name. The tuning
  deviation marker still targets the true nearest note, named or not. The old "Scale" and
  "Chromatic" color groups were removed from Settings → Color (only Pitch,
  Beats and Metronome colors remain there).
- Custom scales are rendered on their own grid (rows at the exact scale-note
  cents across periods, names + register on the left), the big display shows
  the nearest scale note, and the left column is sized to the widest note
  name so wide glyphs (甲, 癸, …) are never clipped. The top tuner strip
  shows a fixed ±(1200/7)-cent window — the ratio 2^(±1/7) — around the
  detected pitch: long ticks sit exactly on the scale notes (name + register
  below) and five short ticks between every adjacent pair of notes divide
  the log-pitch interval into six equal parts. Tick height and thickness are
  fixed constants (major 7 × 2.0, minor 4 × 1.5 view units), while their
  **colours follow the config**: a major tick and its marking text use
  `grayv(clamp(round(r / 84 * 255)))` with `r` the note's colour value
  (42 → RGB(128,128,128); 84 and above clamp to white), and every minor
  tick uses `grayv(round(clamp(round(rMin / 84 * 255)) / 2))` from the
  dimmest value in the colour row (42 → RGB(64,64,64)), where
  `clamp(x) = min(max(x, 0), 255)` and `grayv(v)` is RGB(v, v, v).
- **"Hearing now" dot**: the pitch-history line is 9t (2.25 view units) wide
  and ends in a filled dot of 20t across (a 2.5-unit radius) in the line's own
  colour, drawn only while a pitch is actually detected. Both stop **48t
  (12 units) short of the right edge** so the newest pitch is easy to spot;
  the line's left end stays at the origin and the scale-note grid rows still
  span the full width.
- **Screen-independent gestures**: one finger drags the pitch view exactly
  1:1 — the grid follows the finger, so the same movement feels the same on a
  phone and on a tablet (the old code multiplied by the display scale, so a
  large screen moved several times further than the finger). The two pinches
  are multiplicative: spreading the fingers by a factor scales the time or
  pitch axis by that factor.
- "Semitone" is not meaningful for arbitrary tuning scales: the two semitone
  settings ("Indicate lines of a semitone", "Display semitones on the
  vertical axis") were removed from Settings and are always off. The
  "Display frequency in Hz" option is on by default (also applied once when
  upgrading an older install).
- The old fixed 12-EDO **standard view** is gone entirely (renderer, its
  scale-degree/chromatic/semitone colours, the note-name mode and the
  octave-number setting): the app always renders the active tuning config,
  and shows an empty black screen only if no config can be loaded at all.

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
甲4: 319

// pitches of one period; the last one is the first note of the next period
0\186ed6 7\186ed6 16\186ed6 23\186ed6 30\186ed6 35\186ed6 42\186ed6 49\186ed6 58\186ed6 65\186ed6 72\186ed6
甲 乙 丙 丁 戊 己 庚 辛 壬 癸
```

1. Tap the scale name (top left, e.g. “C Major”).
2. Choose **Import tuning config…** and pick `天干音阶.txt` (its reference
   note is 甲4 = 319 Hz since the official change).
3. The monitor now displays the 天干 scale: detected notes as 甲4/乙4/…,
   grid rows at the exact scale pitches, register repeating every ~1200.76c
   (72/186 of the 6:1 equave).
4. The choice survives app restarts automatically.

## License

The original VocalPitchMonitor is open source (Apache-2.0, © tadaoyamaoka).
This port keeps the same package name and adds no proprietary components;
the xen-tuner grammar is ported from musescore-xen-tuner (GPL-3.0, © euwbah).
