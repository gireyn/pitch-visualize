package com.tadaoyamaoka.vocalpitchmonitor;

import android.content.Context;
import android.graphics.Canvas;
import android.graphics.Paint;
import android.graphics.Path;
import android.graphics.Typeface;
import android.util.AttributeSet;
import android.view.MotionEvent;
import android.view.SurfaceHolder;
import android.view.SurfaceView;
import android.view.ViewTreeObserver;

import java.util.Timer;
import java.util.TimerTask;

/**
 * The main pitch display. Faithful port of the original VocalPitchMonitor
 * MainSurfaceView (black background, pitch-history graph, big note name,
 * tuner, BPM/metronome), extended with a custom-scale rendering mode driven
 * by an imported musescore-xen-tuner tuning config.
 */
public class MainSurfaceView extends SurfaceView implements SurfaceHolder.Callback {
    private static final float FONT_SIZE = 16.0f;
    private static final float FONT_SIZE_HZ = 16.0f;
    private static final float FONT_SIZE_PITCH = 32.0f;
    private static final float FONT_SIZE_TUNER = 14.0f;
    private static final float VIEW_HEIGHT = 800.0f;
    private static final float VIEW_WIDTH = 480.0f;
    /**
     * Half-width of the tuner tick window in cents: 1200/7 cents, i.e. the
     * frequency ratio 2^(±1/7) (one 7-edo step each side of the needle).
     */
    private static final float TUNER_HALF_WINDOW_CENTS = 1200.0f / 7.0f;
    private static int margin = 10;
    private static String[] note_str = null;
    private static final String[] note_str_english;
    private static final float y_per_cent0 = 0.26666668f;
    private static final float zoom_x0 = 2.0f;
    private static float x0 = 10 + 16.0f;
    private static final String[] note_sharp = {"", "♯", "", "♯", "", "", "♯", "", "♯", "", "♯", ""};

    private Analyzer analyzer;
    private boolean auto_scroll;
    private boolean bDragging;
    private boolean bZoomingX;
    private boolean bZoomingY;
    private int bottom_cent;
    private int bpm;
    private float cent_calibrated;
    private int[] color;
    private int[] colorChromatic;
    private int colorMetronome;
    private int colorPitch;
    private int colorSemitone;
    private int colorTempo;
    private boolean display_bpm;
    private boolean display_hz;
    private boolean display_metronome;
    private boolean display_semitone;
    private boolean display_tuner;
    private SurfaceHolder holder;
    private boolean indicate_semitone;
    private boolean isChromatic;
    private boolean isMajor;
    private int meter;
    private int octave_offset;
    private Paint paint;
    Path pathTuner;
    private double[] peak_freq_buf;
    private int peak_freq_buf_pos;
    private float pre_x;
    private float pre_y;
    private float[] pts;
    private float scale;
    private int scale_key;
    private Timer timer;
    private boolean traditional;
    private int velocity;
    private int velocity_diff;
    private float view_height;
    private float view_width;
    float x_tuner;
    private float y_per_cent;
    float y_tuner;
    private float zoom_x;

    /** Active imported tuning config; null = standard 12-EDO mode. */
    private ScaleConfig scaleConfig = null;

    static {
        String[] strArr = {"C", "C", "D", "D", "E", "F", "F", "G", "G", "A", "A", "B"};
        note_str_english = strArr;
        note_str = strArr;
    }

    public MainSurfaceView(Context context) {
        super(context);
        initView();
    }

    public MainSurfaceView(Context context, AttributeSet attributeSet) {
        super(context, attributeSet);
        initView();
    }

    private void initView() {
        this.paint = new Paint(Paint.ANTI_ALIAS_FLAG);
        this.scale = 1.0f;
        this.y_per_cent = y_per_cent0;
        this.bottom_cent = 2400;
        this.velocity = 0;
        this.velocity_diff = 2;
        this.zoom_x = zoom_x0;
        this.pts = new float[((int) (VIEW_HEIGHT - x0)) * 4];
        this.bZoomingX = false;
        this.bZoomingY = false;
        this.bDragging = false;
        this.indicate_semitone = false;
        this.display_semitone = false;
        this.octave_offset = 1;
        this.cent_calibrated = 0.0f;
        this.auto_scroll = true;
        this.display_hz = false;
        this.display_tuner = true;
        this.traditional = false;
        this.display_bpm = false;
        this.bpm = 0;
        this.display_metronome = false;
        this.meter = 0;
        this.scale_key = 0;
        this.isMajor = true;
        this.isChromatic = false;
        this.peak_freq_buf = new double[3];
        this.peak_freq_buf_pos = 0;
        init();
    }

    public void init() {
        SurfaceHolder holder = getHolder();
        this.holder = holder;
        holder.addCallback(this);
        setFocusable(true);
        requestFocus();
        this.paint.setTypeface(Typeface.MONOSPACE);
    }

    public void setAnalyzer(Analyzer analyzer) {
        this.analyzer = analyzer;
    }

    @Override
    public void surfaceCreated(SurfaceHolder surfaceHolder) {
        getViewTreeObserver().addOnGlobalLayoutListener(new ViewTreeObserver.OnGlobalLayoutListener() {
            @Override
            public void onGlobalLayout() {
                MainSurfaceView.this.changeScale();
            }
        });
        changeScale();
        timerStart();
    }

    private void changeScale() {
        if (getWidth() > getHeight()) {
            this.view_width = VIEW_HEIGHT;
        } else {
            this.view_width = VIEW_WIDTH;
        }
        this.scale = getWidth() / this.view_width;
        this.view_height = getHeight() / this.scale;
        this.x_tuner = (this.view_width / zoom_x0) + 19.2f;
        this.y_tuner = 54.0f;
        Path path = new Path();
        this.pathTuner = path;
        path.moveTo(this.x_tuner, this.y_tuner);
        this.pathTuner.lineTo(this.x_tuner - 6.0f, this.y_tuner - 5.0f);
        this.pathTuner.lineTo(this.x_tuner + 6.0f, this.y_tuner - 5.0f);
    }

    @Override
    public void surfaceChanged(SurfaceHolder surfaceHolder, int i, int i2, int i3) {
    }

    @Override
    public void surfaceDestroyed(SurfaceHolder surfaceHolder) {
        timerStop();
        try {
            Thread.sleep(100L);
        } catch (InterruptedException unused) {
        }
    }

    private void timerStart() {
        Timer timer = new Timer(true);
        this.timer = timer;
        timer.schedule(new TimerTask() {
            @Override
            public void run() {
                MainSurfaceView.this.draw();
            }
        }, 33L, 33L);
    }

    private void timerStop() {
        Timer timer = this.timer;
        if (timer != null) {
            timer.cancel();
            this.timer = null;
        }
    }

    /** Activate an imported tuning config (custom-scale mode), or null for standard mode. */
    public void updateScaleConfig(ScaleConfig config) {
        this.scaleConfig = config;
        if (config != null) {
            // map scale names onto the 12 semitone slots for any fallback labels
            String[] mapped = new String[12];
            for (int s = 0; s < 12; s++) {
                int best = 0;
                double bestDev = Double.MAX_VALUE;
                for (int i = 0; i < config.cents.length; i++) {
                    double dev = Math.abs(config.cents[i] - s * 100.0);
                    if (dev < bestDev) {
                        bestDev = dev;
                        best = i;
                    }
                }
                mapped[s] = config.names[best];
            }
            note_str = mapped;
        }
        this.isChromatic = false;
        recomputeColumnX();
    }

    /**
     * Left-edge x of the note column / grid. In custom mode the column is
     * sized from the widest label (note name + two-digit register) so wide
     * glyphs such as 甲/癸 are never clipped at the screen edge; in the
     * standard mode it keeps the original letter/traditional width.
     */
    private void recomputeColumnX() {
        this.paint.setTextSize(FONT_SIZE);
        ScaleConfig cfg = this.scaleConfig;
        if (cfg != null) {
            float maxName = 0.0f;
            for (int i = 0; i < cfg.names.length; i++) {
                float w = this.paint.measureText(cfg.names[i]);
                if (w > maxName) {
                    maxName = w;
                }
            }
            float digits = this.paint.measureText("88");
            this.x0 = maxName + digits + 8.0f;
            return;
        }
        if (!this.traditional) {
            this.x0 = margin + 16.0f;
        } else {
            this.x0 = margin + 24.0f;
        }
        if (this.display_semitone) {
            this.x0 += 8.0f;
        }
    }

    public boolean isCustomScale() {
        return this.scaleConfig != null;
    }

    public void draw() {
        Canvas canvas = this.holder.lockCanvas();
        if (canvas != null) {
            try {
                if (this.scaleConfig != null) {
                    drawCustom(canvas);
                } else {
                    drawStandard(canvas);
                }
            } finally {
                this.holder.unlockCanvasAndPost(canvas);
            }
        }
    }

    /* ====================================================================
     * Standard 12-EDO mode — faithful port of the original drawing code.
     * ==================================================================== */
    private void drawStandard(Canvas lockCanvas) {
        lockCanvas.scale(this.scale, this.scale);
        lockCanvas.drawColor(0xFF000000);
        this.paint.setStrokeCap(Paint.Cap.BUTT);
        double d2 = this.analyzer.get_peak_freq();
        float freq_to_cent = Analyzer.freq_to_cent(d2);
        if (freq_to_cent >= 0.0f) {
            freq_to_cent += this.cent_calibrated;
        }
        float[] fArr2 = this.analyzer.get_pitch_buf();
        int i10 = this.analyzer.get_pitch_buf_pos();
        int i11 = this.analyzer.get_pitch_buf_size();
        int i12 = (freq_to_cent > 0.0f ? 1 : (freq_to_cent == 0.0f ? 0 : -1));
        if (i12 >= 0 && this.auto_scroll && !this.bDragging) {
            int i13 = this.bottom_cent;
            if (freq_to_cent < i13 + 100) {
                int i14 = this.velocity;
                this.bottom_cent = i13 + i14;
                this.velocity = i14 - this.velocity_diff;
            } else if (freq_to_cent > (i13 + (this.view_height / this.y_per_cent)) - 100.0f) {
                int i15 = this.velocity;
                this.bottom_cent = i13 + i15;
                this.velocity = i15 + this.velocity_diff;
            } else {
                this.velocity = 0;
            }
        }
        this.paint.setColor(0xFFCCCCCC);
        this.paint.setStrokeWidth(1.5f);
        float f4 = x0;
        lockCanvas.drawLine(f4, 0.0f, f4, this.view_height, this.paint);
        if (this.display_bpm || this.display_metronome) {
            drawBpmOverlay(lockCanvas);
        }
        this.paint.setTextSize(FONT_SIZE);
        this.paint.setTextAlign(Paint.Align.RIGHT);
        int i20 = (this.bottom_cent / 100) * 100;
        int i21 = (int) (i20 + (this.view_height / this.y_per_cent) + 100.0f);
        for (int i22 = i20; i22 < i21; i22 += 100) {
            int i23 = this.octave_offset + (i22 / 1200);
            int i24 = ((i22 / 100) + 12) % 12;
            int i25 = ((i24 - this.scale_key) + 12) % 12;
            float f12 = x0 - 1.0f;
            boolean semitoneLine;
            if (this.isChromatic) {
                this.paint.setColor(this.colorChromatic[i24]);
                this.paint.setStrokeWidth(1.5f);
                semitoneLine = false;
            } else if (i25 == 0) {
                this.paint.setColor(this.color[0]);
                this.paint.setStrokeWidth(zoom_x0);
                f12 -= 4.0f;
                semitoneLine = false;
            } else if (i25 == 1 || (((this.isMajor && i25 == 3) || (!this.isMajor && i25 == 4)) || i25 == 6 || ((this.isMajor && i25 == 8) || ((!this.isMajor && i25 == 9) || ((this.isMajor && i25 == 10) || (!this.isMajor && i25 == 11)))))) {
                this.paint.setColor(this.colorSemitone);
                this.paint.setStrokeWidth(1.0f);
                semitoneLine = true;
            } else {
                this.paint.setColor(this.color[i25]);
                this.paint.setStrokeWidth(1.5f);
                semitoneLine = false;
            }
            float f13 = this.view_height - ((i22 - this.bottom_cent) * this.y_per_cent);
            if (semitoneLine && !this.indicate_semitone) {
                // thin semitone gridline only
            } else {
                lockCanvas.drawLine(f12, f13, this.view_width, f13, this.paint);
            }
            // labels: natural rows always; black-key rows only when semitones are displayed
            boolean blackKey = i24 == 1 || i24 == 3 || i24 == 6 || i24 == 8 || i24 == 10;
            if (!blackKey || this.display_semitone) {
                if (!this.traditional) {
                    lockCanvas.drawText(note_str[i24] + getSemitoneString(i24) + i23, x0 - 4.0f, f13 + 4.0f, this.paint);
                } else if (!"ファ".equals(note_str[i24])) {
                    lockCanvas.drawText(note_str[i24] + getSemitoneString(i24) + i23, x0 - 4.0f, f13 + 4.0f, this.paint);
                } else {
                    lockCanvas.drawText(getSemitoneString(i24) + Integer.toString(i23), x0 - 4.0f, f13 + 4.0f, this.paint);
                    this.paint.setTextAlign(Paint.Align.LEFT);
                    lockCanvas.drawText("フ", 0.0f, f13 + 4.0f, this.paint);
                    this.paint.setTextSize(11.2f);
                    lockCanvas.drawText("ァ", 12.0f, f13 + 4.0f, this.paint);
                    this.paint.setTextSize(FONT_SIZE);
                    this.paint.setTextAlign(Paint.Align.RIGHT);
                }
            }
        }
        this.paint.setTextAlign(Paint.Align.LEFT);
        this.paint.setColor(this.colorPitch);
        this.paint.setStrokeWidth(1.0f);
        int i30 = (int) ((this.view_width - x0) / this.zoom_x);
        float f15 = -1.0f;
        int i31 = 0;
        for (int i32 = 0; i32 < i30; i32++) {
            float f16 = x0 + (i32 * this.zoom_x);
            float f17 = fArr2[(((i10 + i11) - i30) + i32) % i11];
            if (f17 >= 0.0f) {
                f17 += this.cent_calibrated;
                float f18 = this.view_height - ((f17 - this.bottom_cent) * this.y_per_cent);
                if (f15 < 0.0f || Math.abs(f17 - f15) > 400.0f) {
                    float[] fArr4 = this.pts;
                    fArr4[i31] = f16;
                    fArr4[i31 + 1] = f18;
                } else {
                    float[] fArr5 = this.pts;
                    fArr5[i31] = fArr5[i31 - 2];
                    fArr5[i31 + 1] = fArr5[i31 - 1];
                }
                float[] fArr6 = this.pts;
                fArr6[i31 + 2] = f16;
                fArr6[i31 + 3] = f18;
                i31 += 4;
            }
            f15 = f17;
        }
        if (i31 >= 4) {
            lockCanvas.drawLines(this.pts, 0, i31, this.paint);
        }
        drawPitchName(lockCanvas, d2, freq_to_cent >= 0.0f, false);
    }

    private void drawBpmOverlay(Canvas lockCanvas) {
        float f5 = Analyzer.get_interval_sec();
        int i16 = this.analyzer.get_total_analyze_cnt();
        int i17 = this.bpm;
        float f6 = (60.0f / i17) / f5;
        float f7 = i16;
        int i18 = (int) (f7 / f6);
        float f8 = f7 - (i18 * f6);
        if (this.display_metronome) {
            float f9 = 7.0f - (i17 * 0.016666668f);
            float f10 = (((f8 + f9) % f6) - f9) / f9;
            if (f10 <= 1.0f) {
                this.paint.setColor(this.colorMetronome);
                this.paint.setStrokeWidth((1.0f - Math.abs(f10)) * 20.0f);
                this.paint.setStyle(Paint.Style.STROKE);
                lockCanvas.drawRect(0.0f, 0.0f, this.view_width, this.view_height, this.paint);
                this.paint.setStyle(Paint.Style.FILL);
            }
        }
        if (this.display_bpm) {
            this.paint.setColor(this.colorTempo);
            float f11 = this.view_width - (f8 * this.zoom_x);
            int i9 = i18;
            while (f11 > x0) {
                int i19 = this.meter;
                if (i19 <= 0 || i9 % i19 != 0) {
                    this.paint.setStrokeWidth(0.5f);
                } else {
                    this.paint.setStrokeWidth(1.5f);
                }
                lockCanvas.drawLine(f11, 0.0f, f11, this.view_height, this.paint);
                f11 -= this.zoom_x * f6;
                i9--;
            }
        }
    }

    /** Big note name + tuner + Hz. */
    private void drawPitchName(Canvas lockCanvas, double peakFreq, boolean pitchValid, boolean custom) {
        double[] dArr = this.peak_freq_buf;
        int i33 = this.peak_freq_buf_pos;
        int i34 = i33 + 1;
        this.peak_freq_buf_pos = i34;
        dArr[i33] = peakFreq;
        if (i34 >= dArr.length) {
            this.peak_freq_buf_pos = 0;
        }
        if (!pitchValid) {
            return;
        }
        double d4 = 0.0d;
        int i35 = 0;
        for (double d5 : dArr) {
            if (d5 > 0.0d) {
                d4 += d5;
                i35++;
            }
        }
        if (i35 == 0) {
            return;
        }
        double d6 = d4 / i35;
        float freq_to_cent2 = Analyzer.freq_to_cent(d6) + this.cent_calibrated;

        if (custom && this.scaleConfig != null) {
            int[] nearest = this.scaleConfig.nearestNote(freq_to_cent2);
            int noteIdx = nearest[0];
            int period = nearest[1];
            String name = this.scaleConfig.names[noteIdx];
            String reg = Integer.toString(period);
            this.paint.setColor(0xFFFFFFFF);
            this.paint.setTextSize(FONT_SIZE_PITCH);
            this.paint.setTextAlign(Paint.Align.LEFT);
            float cx = this.view_width / zoom_x0;
            float nameW = this.paint.measureText(name);
            float regW = this.paint.measureText(reg);
            float total = nameW + 8.0f + regW;
            lockCanvas.drawText(name, cx - (total / 2.0f), 42.0f, this.paint);
            lockCanvas.drawText(reg, cx - (total / 2.0f) + nameW + 8.0f, 42.0f, this.paint);
            // nearest note deviation marker on the tuner
            double dev = freq_to_cent2 - this.scaleConfig.noteAbsCent(noteIdx, period);
            if (this.display_tuner) {
                drawTunerCustom(lockCanvas, freq_to_cent2, (float) dev);
            }
        } else {
            int i36 = ((int) (freq_to_cent2 + 0.5d)) + 50;
            int i37 = (i36 / 1200) + this.octave_offset;
            int i38 = (i36 % 1200) / 100;
            float f19 = this.view_width / zoom_x0;
            this.paint.setColor(0xFFFFFFFF);
            this.paint.setTextSize(FONT_SIZE_PITCH);
            this.paint.setTextAlign(Paint.Align.LEFT);
            if (!this.traditional) {
                lockCanvas.drawText(note_str[i38], f19 - 10.666667f, 42.0f, this.paint);
            } else if (!"ファ".equals(note_str[i38])) {
                lockCanvas.drawText(note_str[i38], f19 - 10.666667f, 42.0f, this.paint);
            } else {
                lockCanvas.drawText("フ", f19 - 6.4f, 42.0f, this.paint);
                this.paint.setTextSize(22.4f);
                lockCanvas.drawText("ァ", 9.6f + f19, 42.0f, this.paint);
                this.paint.setTextSize(FONT_SIZE_PITCH);
            }
            if ("♯".equals(note_sharp[i38])) {
                drawSharp(lockCanvas, f19 + 8.0f, 42.0f, FONT_SIZE_PITCH);
            }
            this.paint.setTextAlign(Paint.Align.LEFT);
            this.paint.setTextSize(FONT_SIZE_PITCH);
            lockCanvas.drawText(Integer.toString(i37), f19 + 25.6f, 42.0f, this.paint);
            if (this.display_tuner) {
                drawTunerStandard(lockCanvas, freq_to_cent2);
            }
        }
        if (this.display_hz) {
            this.paint.setTextSize(FONT_SIZE_HZ);
            this.paint.setColor(0xFFCCCCCC);
            this.paint.setTextAlign(Paint.Align.RIGHT);
            lockCanvas.drawText(String.format("%4.0fHz", Double.valueOf(d6)), (this.view_width * 4.0f) / 5.0f, 42.0f, this.paint);
            this.paint.setTextAlign(Paint.Align.LEFT);
        }
    }

    private void drawTunerStandard(Canvas lockCanvas, float freq_to_cent2) {
        int i39 = 0xFFCCCCCC;
        this.paint.setColor(0xFFCCCCCC);
        lockCanvas.drawPath(this.pathTuner, this.paint);
        float f20 = freq_to_cent2 + TUNER_HALF_WINDOW_CENTS;
        int i40 = ((int) (((freq_to_cent2 - TUNER_HALF_WINDOW_CENTS) + 10.0f) / 10.0f)) * 10;
        while (true) {
            float f21 = i40;
            if (f21 >= f20) {
                break;
            }
            float f22 = this.x_tuner + ((f21 - freq_to_cent2) * 1.75f);
            if (i40 % 100 == 0) {
                this.paint.setColor(i39);
                int i41 = (i40 % 1200) / 100;
                float f23 = this.y_tuner + FONT_SIZE_TUNER + 7.0f;
                this.paint.setTextSize(FONT_SIZE_TUNER);
                if (!this.traditional) {
                    lockCanvas.drawText(note_str[i41], f22 - 4.6666665f, f23, this.paint);
                } else {
                    this.paint.setTextAlign(Paint.Align.RIGHT);
                    if (!"ファ".equals(note_str[i41])) {
                        lockCanvas.drawText(note_str[i41], 4.2000003f + f22, f23, this.paint);
                    } else {
                        lockCanvas.drawText("フ", f22 - 2.8f, f23, this.paint);
                        this.paint.setTextSize(9.8f);
                        lockCanvas.drawText("ァ", 4.2000003f + f22, f23, this.paint);
                        this.paint.setTextSize(FONT_SIZE_TUNER);
                    }
                    this.paint.setTextAlign(Paint.Align.LEFT);
                }
                if ("♯".equals(note_sharp[i41])) {
                    drawSharp(lockCanvas, 3.5f + f22, f23, FONT_SIZE_TUNER);
                }
                this.paint.setColor(0xFFCCCCCC);
                this.paint.setStrokeWidth(zoom_x0);
                lockCanvas.drawLine(f22, this.y_tuner + 1.0f, f22, this.y_tuner + 8.0f, this.paint);
            } else if (i40 % 50 == 0) {
                this.paint.setColor(0xFFCCCCCC);
                this.paint.setStrokeWidth(1.5f);
                lockCanvas.drawLine(f22, this.y_tuner + 1.0f, f22, this.y_tuner + 8.0f, this.paint);
            } else {
                this.paint.setColor(0xFF888888);
                this.paint.setStrokeWidth(1.5f);
                lockCanvas.drawLine(f22, this.y_tuner + 1.0f, f22, this.y_tuner + 5.0f, this.paint);
            }
            i40 += 10;
        }
    }

    /**
     * Custom-scale tuner strip. The strip shows a fixed window of
     * ±(1200/7) cents around the detected pitch, centered on the needle:
     * - long ticks sit exactly on the scale notes (light gray, like the
     *   original 100-cent ticks), with the note name + register below;
     * - between every adjacent pair of notes (including the wrap into the
     *   next period) five short ticks divide the log-pitch interval into
     *   six equal parts — the look of the original 10-cent ticks.
     * The fixed 10/50/100-cent grid is not drawn in this mode any more.
     */
    private void drawTunerCustom(Canvas lockCanvas, float freq_to_cent2, float dev) {
        ScaleConfig cfg = this.scaleConfig;
        if (cfg == null) {
            return;
        }
        this.paint.setColor(0xFFCCCCCC);
        lockCanvas.drawPath(this.pathTuner, this.paint);
        final float halfWidth = TUNER_HALF_WINDOW_CENTS; // fixed ±(1200/7)-cent window
        int n = cfg.cents.length;
        double refAbs = (Analyzer.log2(cfg.refFreq) - Analyzer.log2_f_c1) * 1200.0;
        int centerP = (int) Math.round((freq_to_cent2 - refAbs) / cfg.equaveCents) + cfg.refRegister;
        int pSpan = (int) Math.ceil(halfWidth / cfg.equaveCents) + 1;

        // long ticks exactly at the scale notes
        for (int p = centerP - pSpan; p <= centerP + pSpan; p++) {
            for (int i = 0; i < n; i++) {
                double rel = cfg.noteAbsCent(i, p) - freq_to_cent2;
                if (rel >= -halfWidth && rel <= halfWidth) {
                    float fx = this.x_tuner + (float) (rel * 1.75);
                    this.paint.setColor(0xFFCCCCCC);
                    this.paint.setStrokeWidth(zoom_x0);
                    lockCanvas.drawLine(fx, this.y_tuner + 1.0f, fx, this.y_tuner + 8.0f, this.paint);
                    this.paint.setColor(0xFFFFFFFF);
                    this.paint.setTextSize(FONT_SIZE_TUNER);
                    lockCanvas.drawText(cfg.names[i] + Integer.toString(p), fx + 3.0f, this.y_tuner + FONT_SIZE_TUNER + 4.0f, this.paint);
                }
            }
        }
        // five short ticks per adjacent pair, splitting the log-pitch gap
        // into six equal parts (k = 1..5 between the two long ticks)
        for (int p = centerP - pSpan; p <= centerP + pSpan; p++) {
            for (int j = 0; j < n; j++) {
                double start = cfg.noteAbsCent(j, p);
                double end = j + 1 < n
                        ? cfg.noteAbsCent(j + 1, p)
                        : cfg.noteAbsCent(0, p + 1);
                if (end <= start) {
                    continue;
                }
                for (int k = 1; k <= 5; k++) {
                    double rel = (start + (end - start) * k / 6.0) - freq_to_cent2;
                    if (rel >= -halfWidth && rel <= halfWidth) {
                        float fx = this.x_tuner + (float) (rel * 1.75);
                        this.paint.setColor(0xFF888888);
                        this.paint.setStrokeWidth(1.5f);
                        lockCanvas.drawLine(fx, this.y_tuner + 1.0f, fx, this.y_tuner + 5.0f, this.paint);
                    }
                }
            }
        }
        // deviation indicator
        this.paint.setColor(this.colorPitch);
        this.paint.setStrokeWidth(2.0f);
        float fdx = this.x_tuner + (dev * 1.75f);
        lockCanvas.drawLine(fdx - 3.0f, this.y_tuner + 2.0f, fdx + 3.0f, this.y_tuner + 2.0f, this.paint);
    }

    /**
     * Color of scale note index {@code i} in custom mode: the tuning
     * config's own color list (wrapped when shorter than the note count),
     * or the default look — RGB(136,136,136) for the first note and
     * RGB(84,84,84) for the others — when the config has no color line.
     */
    private int customColor(int i) {
        ScaleConfig cfg = this.scaleConfig;
        return cfg != null ? cfg.colorFor(i) : 0xFF545454;
    }

    /* ====================================================================
     * Custom-scale mode.
     * ==================================================================== */
    private void drawCustom(Canvas lockCanvas) {
        ScaleConfig cfg = this.scaleConfig;
        lockCanvas.scale(this.scale, this.scale);
        lockCanvas.drawColor(0xFF000000);
        this.paint.setStrokeCap(Paint.Cap.BUTT);
        double d2 = this.analyzer.get_peak_freq();
        float freq_to_cent = Analyzer.freq_to_cent(d2);
        if (freq_to_cent >= 0.0f) {
            freq_to_cent += this.cent_calibrated;
        }
        float[] pitchBuf = this.analyzer.get_pitch_buf();
        int bufPos = this.analyzer.get_pitch_buf_pos();
        int bufSize = this.analyzer.get_pitch_buf_size();
        boolean pitchValid = freq_to_cent >= 0.0f;

        // auto scroll
        if (pitchValid && this.auto_scroll && !this.bDragging) {
            int i13 = this.bottom_cent;
            if (freq_to_cent < i13 + 100) {
                int i14 = this.velocity;
                this.bottom_cent = i13 + i14;
                this.velocity = i14 - this.velocity_diff;
            } else if (freq_to_cent > (i13 + (this.view_height / this.y_per_cent)) - 100.0f) {
                int i15 = this.velocity;
                this.bottom_cent = i13 + i15;
                this.velocity = i15 + this.velocity_diff;
            } else {
                this.velocity = 0;
            }
        }

        // left border line
        this.paint.setColor(0xFFCCCCCC);
        this.paint.setStrokeWidth(1.5f);
        lockCanvas.drawLine(x0, 0.0f, x0, this.view_height, this.paint);

        if (this.display_bpm || this.display_metronome) {
            drawBpmOverlay(lockCanvas);
        }

        // scale-note grid rows across the visible cent range
        this.paint.setTextAlign(Paint.Align.RIGHT);
        this.paint.setTextSize(FONT_SIZE);
        double topCent = this.bottom_cent + (this.view_height / this.y_per_cent);
        int visP0 = (int) Math.floor((this.bottom_cent - 100.0) / cfg.equaveCents) - 1;
        int visP1 = (int) Math.ceil((topCent + 100.0) / cfg.equaveCents) + 1;
        int rowsDrawn = 0;
        for (int p = visP0; p <= visP1; p++) {
            for (int i = 0; i < cfg.cents.length; i++) {
                if (rowsDrawn > 4000) {
                    return; // pathological configs: keep the frame cheap
                }
                double abs = cfg.noteAbsCent(i, p);
                if (abs < this.bottom_cent - 60.0 || abs > topCent + 60.0) {
                    continue;
                }
                float y = (float) (this.view_height - ((abs - this.bottom_cent) * this.y_per_cent));
                boolean tonic = (i == 0);
                this.paint.setColor(customColor(i));
                this.paint.setStrokeWidth(tonic ? zoom_x0 : 1.5f);
                float lx = x0 - 1.0f;
                lockCanvas.drawLine(lx, y, this.view_width, y, this.paint);
                String label = cfg.names[i] + Integer.toString(p);
                lockCanvas.drawText(label, x0 - 4.0f, y + 4.0f, this.paint);
                rowsDrawn++;
            }
        }

        // pitch history graph
        this.paint.setTextAlign(Paint.Align.LEFT);
        this.paint.setColor(this.colorPitch);
        this.paint.setStrokeWidth(1.0f);
        int i30 = (int) ((this.view_width - x0) / this.zoom_x);
        float f15 = -1.0f;
        int i31 = 0;
        for (int i32 = 0; i32 < i30; i32++) {
            float f16 = x0 + (i32 * this.zoom_x);
            float f17 = pitchBuf[(((bufPos + bufSize) - i30) + i32) % bufSize];
            if (f17 >= 0.0f) {
                f17 += this.cent_calibrated;
                float f18 = (float) (this.view_height - ((f17 - this.bottom_cent) * this.y_per_cent));
                if (f15 < 0.0f || Math.abs(f17 - f15) > 400.0f) {
                    this.pts[i31] = f16;
                    this.pts[i31 + 1] = f18;
                } else {
                    this.pts[i31] = this.pts[i31 - 2];
                    this.pts[i31 + 1] = this.pts[i31 - 1];
                }
                this.pts[i31 + 2] = f16;
                this.pts[i31 + 3] = f18;
                i31 += 4;
            }
            f15 = f17;
        }
        if (i31 >= 4) {
            lockCanvas.drawLines(this.pts, 0, i31, this.paint);
        }
        drawPitchName(lockCanvas, d2, pitchValid, true);
    }

    private void drawSharp(Canvas canvas, float f, float f2, float f3) {
        float f4 = (0.2f * f3) + f;
        float f5 = (0.38f * f3) + f;
        float f6 = (0.05f * f3) + f;
        float f7 = f + (0.53f * f3);
        this.paint.setStrokeWidth(f3 * 0.075f);
        canvas.drawLines(new float[]{f4, f2 - (0.1f * f3), f4, f2 - (0.85f * f3), f5, f2 - (0.15f * f3), f5, f2 - (0.9f * f3), f6, f2 - (0.3f * f3), f7, f2 - (0.4f * f3), f6, f2 - (0.6f * f3), f7, f2 - (0.7f * f3)}, this.paint);
    }

    private String getSemitoneString(int i) {
        return this.display_semitone ? ("".equals(note_sharp[i]) ? " " : "#") : "";
    }

    public void hold() {
        timerStop();
    }

    public void unHold() {
        timerStart();
    }

    public void updateSettings(double d, float f, float f2, boolean z, boolean z2, int i, int i2, int i3,
                               boolean z3, int i4, int i5, int i6, int i7, int[] iArr, int i8, int[] iArr2,
                               boolean z4, boolean z5, int i9, boolean z6, int i10) {
        this.analyzer.set_threshold(d);
        setCurrentHorizontalZooming(f);
        setCurrentVerticalZooming(f2);
        this.indicate_semitone = z;
        this.display_semitone = z2;
        this.octave_offset = i;
        this.cent_calibrated = ((float) ((Analyzer.log2(440.0d) - Analyzer.log2(i2)) * 12.0d * 100.0d)) + (i3 * 100);
        this.auto_scroll = z3;
        this.velocity_diff = i4;
        this.display_hz = z4;
        this.display_tuner = z5;
        if (i9 >= 1 && i9 <= 5) {
            this.peak_freq_buf = new double[i9];
            this.peak_freq_buf_pos = 0;
        }
        this.traditional = z6;
        if (this.scaleConfig == null) {
            if (!z6) {
                note_str = note_str_english;
            } else {
                String[] stringArray = getResources().getStringArray(R.array.note_name_traditional);
                String str = stringArray[1];
                String str2 = stringArray[3];
                String str3 = stringArray[4];
                String str4 = stringArray[5];
                note_str = new String[]{stringArray[0], stringArray[0], str, str, stringArray[2], str2, str2, str3, str3, str4, str4, stringArray[6]};
            }
        }
        if (!z6) {
            this.paint.setTypeface(Typeface.MONOSPACE);
        } else {
            this.paint.setTypeface(Typeface.SANS_SERIF);
        }
        recomputeColumnX();
        this.meter = i10;
        this.colorPitch = i5;
        this.colorTempo = i6;
        this.colorMetronome = i7;
        this.color = iArr;
        this.colorSemitone = i8;
        this.colorChromatic = iArr2;
    }

    public void updateScale(int i, boolean z) {
        this.scale_key = i;
        this.isMajor = z;
        this.isChromatic = false;
    }

    public void updateBpm(boolean z, int i, boolean z2) {
        this.display_bpm = z;
        this.bpm = i;
        this.display_metronome = z2;
    }

    public void updateScaleChromatic() {
        this.isChromatic = true;
    }

    public float getCurrentHorizontalZooming() {
        return this.zoom_x / zoom_x0;
    }

    public void setCurrentHorizontalZooming(float f) {
        this.zoom_x = f * zoom_x0;
    }

    public float getCurrentVerticalZooming() {
        return this.y_per_cent / y_per_cent0;
    }

    public void setCurrentVerticalZooming(float f) {
        this.y_per_cent = f * y_per_cent0;
    }

    public int getBottomCent() {
        return this.bottom_cent;
    }

    public void setBottomCent(int i) {
        this.bottom_cent = i;
    }

    @Override
    public boolean onTouchEvent(MotionEvent motionEvent) {
        int action = motionEvent.getAction() & 255;
        if (action == MotionEvent.ACTION_DOWN) {
            this.pre_y = motionEvent.getY(0);
            this.bDragging = true;
        } else if (action == MotionEvent.ACTION_UP || action == MotionEvent.ACTION_POINTER_UP) {
            this.bZoomingX = false;
            this.bZoomingY = false;
            this.bDragging = false;
        } else if (action == MotionEvent.ACTION_MOVE) {
            if (motionEvent.getPointerCount() == 2) {
                if (this.bZoomingX) {
                    float abs2 = Math.abs(motionEvent.getX(0) - motionEvent.getX(1));
                    float f = this.zoom_x + ((abs2 - this.pre_x) * this.scale * 0.001f);
                    this.zoom_x = f;
                    if (f < Settings.HORIZONTAL_ZOOMING_MIN * zoom_x0) {
                        this.zoom_x = Settings.HORIZONTAL_ZOOMING_MIN * zoom_x0;
                    } else if (this.zoom_x > Settings.HORIZONTAL_ZOOMING_MAX * zoom_x0) {
                        this.zoom_x = Settings.HORIZONTAL_ZOOMING_MAX * zoom_x0;
                    }
                    this.pre_x = abs2;
                }
                if (this.bZoomingY) {
                    float abs3 = Math.abs(motionEvent.getY(0) - motionEvent.getY(1));
                    float f2 = this.y_per_cent + ((abs3 - this.pre_y) * this.scale * 2.0E-4f);
                    this.y_per_cent = f2;
                    if (f2 < Settings.VERTICAL_ZOOMING_MIN * y_per_cent0) {
                        this.y_per_cent = Settings.VERTICAL_ZOOMING_MIN * y_per_cent0;
                    } else if (this.y_per_cent > Settings.VERTICAL_ZOOMING_MAX * y_per_cent0) {
                        this.y_per_cent = Settings.VERTICAL_ZOOMING_MAX * y_per_cent0;
                    }
                    this.pre_y = abs3;
                }
            } else if (this.bDragging) {
                float y = motionEvent.getY(0);
                int i = (int) (this.bottom_cent + ((y - this.pre_y) * this.scale * 1.5d));
                this.bottom_cent = i;
                if (i < 0) {
                    this.bottom_cent = 0;
                } else if (i > Settings.BOTTOM_CENT_MAX) {
                    this.bottom_cent = Settings.BOTTOM_CENT_MAX;
                }
                this.pre_y = y;
            }
        } else if (action == MotionEvent.ACTION_POINTER_DOWN) {
            if (motionEvent.getPointerCount() == 2) {
                double abs = Math.abs(Math.atan2(motionEvent.getY(0) - motionEvent.getY(1), motionEvent.getX(0) - motionEvent.getX(1)));
                if (abs < 0.7853981633974483d || abs > 2.356194490192345d) {
                    this.pre_x = Math.abs(motionEvent.getX(0) - motionEvent.getX(1));
                    this.bZoomingX = true;
                } else {
                    this.pre_y = Math.abs(motionEvent.getY(0) - motionEvent.getY(1));
                    this.bZoomingY = true;
                }
                this.bDragging = false;
            }
        }
        return true;
    }
}
