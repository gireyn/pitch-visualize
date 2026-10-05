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
    private static final float y_per_cent0 = 0.26666668f;
    private static final float zoom_x0 = 2.0f;
    /* Tuner strip tick geometry: fixed by design, independent of zoom. */
    private static final float TICK_TOP = 1.0f;
    private static final float TICK_MAJOR_HEIGHT = 7.0f;
    private static final float TICK_MAJOR_WIDTH = 2.0f;
    private static final float TICK_MINOR_HEIGHT = 4.0f;
    private static final float TICK_MINOR_WIDTH = 1.5f;
    /** Pitch history line width; the "hearing now" dot is 3x as thick. */
    private static final float PITCH_LINE_WIDTH = 1.0f;
    private static final float PITCH_DOT_RADIUS = (PITCH_LINE_WIDTH * 3.0f) / 2.0f;
    private static float x0 = 10 + 16.0f;

    private Analyzer analyzer;
    private boolean auto_scroll;
    private boolean bDragging;
    private boolean bZoomingX;
    private boolean bZoomingY;
    private int bottom_cent;
    private int bpm;
    private float cent_calibrated;
    private int colorMetronome;
    private int colorPitch;
    private int colorTempo;
    private boolean display_bpm;
    private boolean display_hz;
    private boolean display_metronome;
    private boolean display_tuner;
    private SurfaceHolder holder;
    private int meter;
    private Paint paint;
    Path pathTuner;
    private double[] peak_freq_buf;
    private int peak_freq_buf_pos;
    private float pre_x;
    private float pre_y;
    private float[] pts;
    private float scale;
    private Timer timer;
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
        this.cent_calibrated = 0.0f;
        this.auto_scroll = true;
        this.display_hz = false;
        this.display_tuner = true;
        this.display_bpm = false;
        this.bpm = 0;
        this.display_metronome = false;
        this.meter = 0;
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

    /** Activate a tuning config; null leaves the canvas black (no scale). */
    public void updateScaleConfig(ScaleConfig config) {
        this.scaleConfig = config;
        recomputeColumnX();
    }

    /**
     * Left-edge x of the note column / grid, sized from the widest label of the
     * active config (note name + two-digit register) so wide glyphs such as
     * 甲/癸 are never clipped at the screen edge.
     */
    private void recomputeColumnX() {
        this.paint.setTextSize(FONT_SIZE);
        ScaleConfig cfg = this.scaleConfig;
        if (cfg == null) {
            this.x0 = margin + 16.0f;
            return;
        }
        float maxName = 0.0f;
        for (int i = 0; i < cfg.names.length; i++) {
            float w = this.paint.measureText(cfg.names[i]);
            if (w > maxName) {
                maxName = w;
            }
        }
        float digits = this.paint.measureText("88");
        this.x0 = maxName + digits + 8.0f;
    }

    public boolean isCustomScale() {
        return this.scaleConfig != null;
    }

    public void draw() {
        Canvas canvas = this.holder.lockCanvas();
        if (canvas != null) {
            try {
                // Config-driven rendering only: the old fixed 12-EDO standard
                // view (and its semitone handling) is gone. With no config
                // loaded the canvas stays black; MainActivity always falls back
                // to the bundled config and says so if that fails.
                if (this.scaleConfig != null) {
                    drawCustom(canvas);
                } else {
                    canvas.scale(this.scale, this.scale);
                    canvas.drawColor(0xFF000000);
                }
            } finally {
                this.holder.unlockCanvasAndPost(canvas);
            }
        }
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
    private void drawPitchName(Canvas lockCanvas, double peakFreq, boolean pitchValid) {
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

        if (this.scaleConfig != null) {
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
        }
        if (this.display_hz) {
            this.paint.setTextSize(FONT_SIZE_HZ);
            this.paint.setColor(0xFFCCCCCC);
            this.paint.setTextAlign(Paint.Align.RIGHT);
            lockCanvas.drawText(String.format("%4.0fHz", Double.valueOf(d6)), (this.view_width * 4.0f) / 5.0f, 42.0f, this.paint);
            this.paint.setTextAlign(Paint.Align.LEFT);
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
        final int minorColor = minorTickColor(cfg.minColorValue());
        final float tickTop = this.y_tuner + TICK_TOP;

        // long ticks exactly at the scale notes
        for (int p = centerP - pSpan; p <= centerP + pSpan; p++) {
            for (int i = 0; i < n; i++) {
                double rel = cfg.noteAbsCent(i, p) - freq_to_cent2;
                if (rel >= -halfWidth && rel <= halfWidth) {
                    float fx = this.x_tuner + (float) (rel * 1.75);
                    int tickColor = majorTickColor(cfg.colorValueFor(i));
                    this.paint.setColor(tickColor);
                    this.paint.setStrokeWidth(TICK_MAJOR_WIDTH);
                    lockCanvas.drawLine(fx, tickTop, fx, tickTop + TICK_MAJOR_HEIGHT, this.paint);
                    // the marking text of a major tick uses the tick's colour
                    this.paint.setColor(tickColor);
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
                        this.paint.setColor(minorColor);
                        this.paint.setStrokeWidth(TICK_MINOR_WIDTH);
                        lockCanvas.drawLine(fx, tickTop, fx, tickTop + TICK_MINOR_HEIGHT, this.paint);
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

    /** clamp(x) = min(max(x, 0), 255). */
    private static int clamp(int v) {
        return v < 0 ? 0 : (v > 255 ? 255 : v);
    }

    /** grayv(v) = RGB(v, v, v), with v clamped into 0..255. */
    private static int grayv(int v) {
        int c = clamp(v);
        return 0xFF000000 | (c * 0x010101);
    }

    /**
     * Major (scale-note) tick colour: grayv(clamp(round(r / 84 * 255))), where
     * r is the note's configured value in the colour row — 42 becomes
     * RGB(128,128,128), while 84 and above clamp to white. Without a colour
     * row the defaults 136 (first note) and 84 (the rest) apply.
     */
    private static int majorTickColor(int r) {
        return grayv(Math.round(r * 255.0f / 84.0f));
    }

    /**
     * Minor (six-equal-division) tick colour, from the dimmest value in the
     * config: grayv(round(clamp(round(rMin / 84 * 255)) / 2)) — the 42 in
     * 21ed2_scb.txt gives RGB(64,64,64), the 84 default gives white/2 = white.
     */
    private static int minorTickColor(int rMin) {
        int major = clamp(Math.round(rMin * 255.0f / 84.0f));
        return grayv(Math.round(major / 2.0f));
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
                this.paint.setColor(customColor(i));
                // Per-note line thickness from the config's optional "…t" row;
                // without that row the classic 8t (first note) / 6t defaults.
                this.paint.setStrokeWidth(cfg.thicknessFor(i));
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
        this.paint.setStrokeWidth(PITCH_LINE_WIDTH);
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
            // The dot marks the pitch being heard right now: it sits on the
            // newest point of the curve, is as wide as three line thicknesses,
            // and disappears while no pitch is detected.
            if (pitchValid) {
                this.paint.setColor(this.colorPitch);
                this.paint.setStyle(Paint.Style.FILL);
                lockCanvas.drawCircle(this.pts[i31 - 2], this.pts[i31 - 1], PITCH_DOT_RADIUS, this.paint);
            }
        }
        drawPitchName(lockCanvas, d2, pitchValid);
    }

    public void hold() {
        timerStop();
    }

    public void unHold() {
        timerStart();
    }

    /**
     * Push the settings that the config-driven view actually uses. The old
     * semitone/chromatic/scale-degree parameters are gone with the standard
     * view; note names come from the config, and calibration/transpose stay
     * fixed at A4 = 440 Hz and C (the caller passes them).
     */
    public void updateSettings(double threshold, float hZoom, float vZoom, int calibration, int transpose,
                               boolean autoScroll, int scrollSpeed, int colorPitch, int colorTempo,
                               int colorMetronome, boolean displayHz, boolean displayTuner, int smooth, int meter) {
        this.analyzer.set_threshold(threshold);
        setCurrentHorizontalZooming(hZoom);
        setCurrentVerticalZooming(vZoom);
        this.cent_calibrated = ((float) ((Analyzer.log2(440.0d) - Analyzer.log2(calibration)) * 12.0d * 100.0d)) + (transpose * 100);
        this.auto_scroll = autoScroll;
        this.velocity_diff = scrollSpeed;
        this.display_hz = displayHz;
        this.display_tuner = displayTuner;
        if (smooth >= 1 && smooth <= 5) {
            this.peak_freq_buf = new double[smooth];
            this.peak_freq_buf_pos = 0;
        }
        // Config names are always used, and they are drawn monospaced.
        this.paint.setTypeface(Typeface.MONOSPACE);
        recomputeColumnX();
        this.meter = meter;
        this.colorPitch = colorPitch;
        this.colorTempo = colorTempo;
        this.colorMetronome = colorMetronome;
    }

    public void updateBpm(boolean z, int i, boolean z2) {
        this.display_bpm = z;
        this.bpm = i;
        this.display_metronome = z2;
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
