# Pitch detector regression checks

`flutter test test/domain/audio` verifies the FFT against a direct DFT, its
unnormalized N/2 inverse scaling, pitch estimates, 8–192 kHz stream conversion,
isolate backpressure, and generation-based invalidation on pause/reset.

The detector retains the legacy 4096-point Hann window, 1470-sample cadence,
threshold, ACF periodicity test, octave correction, harmonic lag averaging,
spectral interpolation, and C1 reference. Its new radix-2 FFT is mathematically
correct; the retained Android `FFT4g.java` is not a strict numerical reference.

Reproduce the legacy discrepancy without Android dependencies:

```sh
mkdir -p /tmp/pitch-fixture
javac -d /tmp/pitch-fixture app/src/com/tadaoyamaoka/vocalpitchmonitor/Analyzer.java app/src/com/tadaoyamaoka/vocalpitchmonitor/FFT4g.java test/domain/audio/legacy_pitch_fixture.java
java -cp /tmp/pitch-fixture legacy_pitch_fixture verify-fft
```

The legacy implementation reports maximum direct-DFT errors of 2.0471935654590503
at N=16 and 563.3084533628704 at N=4096 for the fixture waveform; its round-trip
errors are 15.340547021306119 and 4392.799186257168. The new FFT passes the N=16
DFT and round-trip comparisons at 1e-12 tolerance.

Regenerate the retained Android pitch baseline:

```sh
java -cp /tmp/pitch-fixture legacy_pitch_fixture > test/domain/audio/legacy_pitch_golden.json
```

Tests compare both detectors after their first complete window: 110,
261.6255653005986, 320, 342.3223386242056, and 440 Hz stay within 0.5 Hz of the
legacy estimate and within 0.5% of the known input. Startup artifacts caused by
the incorrect legacy FFT are deliberately excluded from strict comparison.
Noise remains unvoiced, and a weak 110 Hz fundamental with a dominant second
harmonic remains in the correct octave.

`PitchWorker.addPcm` accepts aligned mono PCM16 LE at integer sample rates from
8000 to 192000 Hz, with chunks up to 192000 bytes. Streaming linear interpolation
preserves phase across arbitrary chunk boundaries. Upsampling waits for the next
source sample, so an ended stream can leave up to five 44.1 kHz output samples
pending rather than extrapolating unknown audio beyond the input.
The worker analyzes one block at a time and caps pending audio at eight blocks
and 192000 bytes. Overflow drops old pending blocks and resets the detector's
window, preventing artificial periodicity across a discontinuity. Audio
recording should retain the original native-rate PCM independently of analysis.
`PitchFrame.timeSeconds` follows input audio time since reset, including queued
blocks discarded by backpressure. Each block carries its source start time;
after a dropped block or sample-rate change, the fresh analysis window uses
that time as its origin. The timestamp therefore remains monotonic across
discontinuities. Explicit `reset()` starts a new timeline at zero.
