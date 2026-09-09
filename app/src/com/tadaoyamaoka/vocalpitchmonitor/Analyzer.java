package com.tadaoyamaoka.vocalpitchmonitor;

/**
 * Pitch analyzer: 4096-point FFT + autocorrelation (via FFT) with octave-error
 * correction and harmonic-sum refinement. A faithful Java port of the original
 * VocalPitchMonitor Analyzer (which is itself based on the classic
 * "vocal pitch monitor" algorithm).
 */
public class Analyzer {
    public static int ANALYZE_INTERVAL = 1470;
    public static final int FFTSIZE;
    private static final double FREQ_A3 = Math.pow(2.0d, 0.0d) * 220.0d;
    private static final double FREQ_A3_SHARP = Math.pow(2.0d, 0.08333333333333333d) * 220.0d;
    public static final int PITCH_BUF_SIZE = 800;
    public static final double SAMPLE_FREQ = 44100.0d;
    private static final double f_c1;
    private static final double f_c8;
    private static double[] han_window;
    public static final double log2_f_c1;

    private double[] acf_data;
    private FFT4g fft;
    private double[] fft_data;
    private double[] wave_data;
    private int wave_data_pos = 0;
    int analyze_cnt = 0;
    int total_analyze_cnt = 0;
    private double threshold = 2.0d;
    private final int range = 3;
    double peak_freq = -1.0d;
    private float[] pitch_buf = new float[PITCH_BUF_SIZE];
    private int pitch_buf_pos = 0;

    private double power(double d, double d2) {
        return (d * d) + (d2 * d2);
    }

    public int get_pitch_buf_size() {
        return PITCH_BUF_SIZE;
    }

    static {
        int pow3 = (int) Math.pow(2.0d, ((int) log2(44100.0d / (FREQ_A3_SHARP - FREQ_A3))) + 1);
        FFTSIZE = pow3;
        han_window = new double[pow3];
        for (int i = 0; i < FFTSIZE; i++) {
            han_window[i] = (0.5d - (Math.cos((i * 6.283185307179586d) / FFTSIZE) * 0.5d)) / 32767.0d;
        }
        double pow4 = Math.pow(2.0d, -0.75d) * 55.0d;
        f_c1 = pow4;
        f_c8 = Math.pow(2.0d, -0.75d) * 7040.0d;
        log2_f_c1 = log2(pow4);
    }

    public static double log2(double d) {
        return Math.log(d) / Math.log(2.0d);
    }

    public static float freq_to_cent(double d) {
        if (d < 0.0d) {
            return -1.0f;
        }
        return (float) ((log2(d) - log2_f_c1) * 12.0d * 100.0d);
    }

    public float[] get_pitch_buf() {
        return this.pitch_buf;
    }

    public int get_pitch_buf_pos() {
        return this.pitch_buf_pos;
    }

    public double get_peak_freq() {
        return this.peak_freq;
    }

    public void set_threshold(double d) {
        this.threshold = d;
    }

    public static float get_interval_sec() {
        return ANALYZE_INTERVAL / 44100.0f;
    }

    public int get_total_analyze_cnt() {
        return this.total_analyze_cnt;
    }

    public void set_total_analyze_cnt(int i) {
        this.total_analyze_cnt = i;
    }

    public void clearData() {
        this.wave_data_pos = 0;
        this.analyze_cnt = 0;
    }

    public Analyzer() {
        int i = FFTSIZE;
        this.wave_data = new double[i];
        this.fft_data = new double[i];
        this.fft = new FFT4g(i);
        this.acf_data = new double[i];
        for (int i2 = 0; i2 < PITCH_BUF_SIZE; i2++) {
            this.pitch_buf[i2] = -1.0f;
        }
    }

    public void addData(short s) {
        double[] dArr = this.wave_data;
        int i = this.wave_data_pos;
        int i2 = i + 1;
        this.wave_data_pos = i2;
        dArr[i] = s;
        if (i2 == FFTSIZE) {
            this.wave_data_pos = 0;
        }
        int i3 = this.analyze_cnt + 1;
        this.analyze_cnt = i3;
        if (i3 == ANALYZE_INTERVAL) {
            analyze();
            this.analyze_cnt = 0;
        }
    }

    private void analyze() {
        for (int i = 0; i < FFTSIZE; i++) {
            this.fft_data[i] = han_window[i] * this.wave_data[((this.wave_data_pos + FFTSIZE) + i) % FFTSIZE];
        }
        this.fft.rdft(1, this.fft_data);
        this.acf_data[0] = power(this.fft_data[0], 0.0d);
        this.acf_data[1] = power(this.fft_data[1], 0.0d);
        for (int i3 = 1; i3 < FFTSIZE / 2; i3++) {
            double[] dArr = this.acf_data;
            int i4 = i3 * 2;
            double[] dArr2 = this.fft_data;
            int i5 = i4 + 1;
            dArr[i4] = power(dArr2[i4], dArr2[i5]);
            this.acf_data[i5] = 0.0d;
        }
        this.fft.rdft(-1, this.acf_data);
        if (Math.sqrt(this.acf_data[0]) >= this.threshold) {
            this.peak_freq = detect_pitch();
        } else {
            this.peak_freq = -1.0d;
        }
        float[] fArr = this.pitch_buf;
        int i6 = this.pitch_buf_pos;
        this.pitch_buf_pos = i6 + 1;
        fArr[i6] = freq_to_cent(this.peak_freq);
        if (this.pitch_buf_pos == PITCH_BUF_SIZE) {
            this.pitch_buf_pos = 0;
        }
        this.total_analyze_cnt++;
    }

    /**
     * Peak detection over the autocorrelation function with octave correction
     * (checks the FFT magnitude at f/3, f/2, f, 2f, 3f) and a harmonic-sum
     * refinement. Ported from the original (smali-verified control flow).
     */
    double detect_pitch() {
        // start from the top of the search range
        int i2 = ((int) (44100.0d / f_c8)) - 1;
        double d2 = this.acf_data[i2];
        for (int i3 = 1; i3 < 5; i3++) {
            double d3 = this.acf_data[i2 + i3];
            if (d3 > d2) {
                d2 = d3;
            }
        }
        double d4 = 0.0d;
        int i4 = 0;
        double d5 = -1.0d;
        while (true) {
            if (i2 >= (44100.0d / f_c1) + 1.0d) {
                break;
            }
            int i5 = i2 + 1;
            double d6 = this.acf_data[i5];
            for (int i6 = 1; i6 < 5; i6++) {
                double d7 = this.acf_data[i5 + i6];
                if (d7 > d6) {
                    d6 = d7;
                }
            }
            double d8 = d6 - d2;
            if (d8 < 0.0d && d5 > 0.0d && d2 > d4) {
                i4 = i2;
                d4 = d2;
            }
            if (d8 != 0.0d) {
                d2 = d6;
                d5 = d8;
            }
            i2 = i5;
        }
        if (i4 == 0 || d4 < this.acf_data[0] * 0.5d) {
            return -1.0d;
        }
        double d9 = 44100.0d / i4;
        // Parabolic interpolation of the ACF peak: the coarse lag i4 quantizes
        // the pitch to 44100/lag steps (~2.3 Hz at 440 Hz). Interpolating the
        // parabola through acf[i4-1], acf[i4], acf[i4+1] yields a continuous
        // fractional lag so microtonal pitch changes are tracked smoothly.
        if (i4 > 0 && i4 + 1 < this.acf_data.length) {
            double y0 = this.acf_data[i4 - 1];
            double y1 = this.acf_data[i4];
            double y2 = this.acf_data[i4 + 1];
            double denom = y0 - 2.0d * y1 + y2;
            if (denom != 0.0d) {
                double delta = 0.5d * (y0 - y2) / denom; // in (-0.5, 0.5)
                if (delta > -0.5d && delta < 0.5d) {
                    d9 = 44100.0d / (i4 + delta);
                }
            }
        }
        double d10 = get_fft_value_around_f(d9);
        double d11 = d9 / 3.0d;
        double d12 = get_fft_value_around_f(d11 * 2.0d);
        if (d10 < 0.24d || d12 <= 3.15d * d10 || d11 < f_c1) {
            double d13 = get_fft_value_around_f(1.5d * d9);
            if (d10 >= 0.24d && d13 > d10 && d9 / 2.0d >= f_c1) {
                d11 = d9 / 2.0d;
            } else {
                d11 = d9 * 2.0d;
                double d14 = get_fft_value_around_f(d11);
                double d15 = 3.0d * d9;
                double d16 = get_fft_value_around_f(d15);
                if (d14 < 0.24d || d14 <= d10 * 1.25d || d16 >= d14 * 0.06d || d11 > f_c8) {
                    if (d16 >= 0.24d && d16 > 1.25d * d10 && d14 < 0.06d * d16 && d15 <= f_c8) {
                        d9 = d15;
                    }
                    if (Math.sqrt((d10 * d10) + (d14 * d14) + (d16 * d16)) < 0.7d) {
                        return -1.0d;
                    }
                    d11 = d9;
                }
            }
        }
        // harmonic-sum refinement over the ACF peaks
        int i8 = 2;
        int i10 = 1;
        int i9 = (int) (((FFTSIZE / 2) - 1) / (44100.0d / d11));
        while (i8 <= i9) {
            double d18 = i8 * 44100.0d;
            int i11 = (int) (d18 / (d11 / i10));
            int i12 = i11 + 3;
            if (i12 >= FFTSIZE / 2) {
                i12 = (FFTSIZE / 2) - 1;
            }
            double d19 = this.acf_data[i12];
            int i15 = i12;
            for (int i16 = i11 - 3; i16 <= i12; i16++) {
                double d20 = this.acf_data[i16];
                if (d20 >= d19) {
                    i15 = i16;
                    d19 = d20;
                }
            }
            if (i15 != i11 - 3 && i15 != i12) {
                double fracLag = i15;
                // parabolic interpolation of this harmonic's ACF peak for a
                // continuous (microtonal) contribution to the pitch sum
                if (i15 > 0 && i15 + 1 < this.acf_data.length) {
                    double y0 = this.acf_data[i15 - 1];
                    double y1 = this.acf_data[i15];
                    double y2 = this.acf_data[i15 + 1];
                    double den = y0 - 2.0d * y1 + y2;
                    if (den != 0.0d) {
                        double dl = 0.5d * (y0 - y2) / den;
                        if (dl > -0.5d && dl < 0.5d) {
                            fracLag = i15 + dl;
                        }
                    }
                }
                d11 += d18 / fracLag;
                i10++;
            }
            i8++;
        }
        double pitch = d11 / i10;
        // Final microtonal refinement: the ACF estimate is quantized by the
        // integer lag and its parabola is flattened by the window envelope.
        // The FFT spectral peak (a clean parabola for a dominant partial)
        // gives continuous sub-cent precision. Only accept it when it agrees
        // with the ACF estimate within a small octave-region window, so octave
        // errors (strong harmonics, weak fundamentals) stay protected.
        double fftPeak = interpolatedFftPeakNear(pitch);
        if (fftPeak > 0.0d) {
            double ratio = fftPeak / pitch;
            if (ratio > 0.8d && ratio < 1.25d) {
                pitch = fftPeak;
            }
        }
        return pitch;
    }

    /** Parabolic-interpolated FFT peak (in Hz) within +-6% of the given pitch. */
    private double interpolatedFftPeakNear(double pitchHz) {
        double binHz = 44100.0d / FFTSIZE;
        double loHz = pitchHz * 0.94d;
        double hiHz = pitchHz * 1.06d;
        int kLo = (int) (loHz / binHz);
        int kHi = (int) (hiHz / binHz);
        if (kLo < 1) {
            kLo = 1;
        }
        if (kHi > FFTSIZE / 2 - 1) {
            kHi = FFTSIZE / 2 - 1;
        }
        if (kHi <= kLo) {
            return -1.0d;
        }
        int best = kLo;
        double bestP = -1.0d;
        for (int k = kLo; k <= kHi; k++) {
            double p = power(this.fft_data[k * 2], this.fft_data[k * 2 + 1]);
            if (p > bestP) {
                bestP = p;
                best = k;
            }
        }
        if (best <= 0 || best >= FFTSIZE / 2 - 1) {
            return -1.0d;
        }
        double p0 = Math.log(1.0d + power(this.fft_data[(best - 1) * 2], this.fft_data[(best - 1) * 2 + 1]));
        double p1 = Math.log(1.0d + bestP);
        double p2 = Math.log(1.0d + power(this.fft_data[(best + 1) * 2], this.fft_data[(best + 1) * 2 + 1]));
        double denom = p0 - 2.0d * p1 + p2;
        if (denom == 0.0d) {
            return best * binHz;
        }
        double delta = 0.5d * (p0 - p2) / denom;
        if (delta < -0.5d) {
            delta = -0.5d;
        }
        if (delta > 0.5d) {
            delta = 0.5d;
        }
        return (best + delta) * binHz;
    }

    private double get_fft_value_around_f(double d) {
        int i = FFTSIZE;
        int i2 = (int) ((d * 1.0208333333333333d) / (44100.0d / i));
        double d2 = 0.0d;
        int i3 = 0;
        for (int i4 = (int) ((0.9791666666666666d * d) / (44100.0d / i)); i4 <= i2; i4++) {
            double[] dArr = this.fft_data;
            int i5 = i4 * 2;
            double power = power(dArr[i5], dArr[i5 + 1]);
            if (power > d2) {
                i3 = i4;
                d2 = power;
            }
        }
        double[] dArr2 = this.fft_data;
        int i6 = (i3 - 1) * 2;
        double[] dArr3 = this.fft_data;
        int i7 = (i3 + 1) * 2;
        return Math.sqrt(((d2 + power(dArr2[i6], dArr2[i6 + 1])) + power(dArr3[i7], dArr3[i7 + 1])) / 3.0d);
    }
}
