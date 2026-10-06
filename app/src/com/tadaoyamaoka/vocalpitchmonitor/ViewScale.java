package com.tadaoyamaoka.vocalpitchmonitor;

/**
 * How much of the screen one view unit gets: the canvas' size rule.
 *
 * <p>The pitch view is laid out in view units, and inside them in t (1 view
 * unit = 4t). This class turns a screen's pixel size into pixels per view unit.
 *
 * <p>A proportional rule — the old {@code scale = width / 480} — gave a big
 * screen the same amount of music as a phone with everything magnified: on a
 * 1840x2800 pad the text came out 61 px tall against 24 px on a 720x1600 phone,
 * while the visible pitch range was <em>smaller</em> (about 2740 cents against
 * 4000), so the pad was strictly worse than the phone. The rule here still
 * grows with the screen, but far more slowly: the fourth root of the area
 * ratio, i.e. sqrt(sqrt(w*h / (720*1600))). Against the phone that gives
 *
 * <pre>
 *   720x1600   the phone this drawing was tuned on   1.50x   (unchanged)
 *   1080x2400                                        1.84x
 *   1840x2800  tablet                                2.18x   (was 3.83x)
 * </pre>
 *
 * <p>The 720x1600 phone is the anchor of the rule, so it keeps exactly the
 * 1.5 px per unit it always had, pixel for pixel. Since only the screen's area
 * matters, rotating a device changes no size either.
 *
 * <p>The rest of the window — the config name, the buttons, the BPM box — is
 * ordinary Android layout in dip, that is density-based, and is deliberately
 * left alone by this rule.
 */
public final class ViewScale {
    /** The screen the drawing was tuned on. */
    public static final int REFERENCE_WIDTH = 720;
    public static final int REFERENCE_HEIGHT = 1600;
    /** Pixels per view unit on that screen. */
    public static final float REFERENCE_SCALE = 1.5f;

    private ViewScale() {
    }

    /**
     * Pixels per view unit for a surface of {@code width} x {@code height}
     * pixels. A surface that has not been measured yet (either side not
     * positive) gets the reference scale.
     */
    public static float of(int width, int height) {
        if (width <= 0 || height <= 0) {
            return REFERENCE_SCALE;
        }
        double areaRatio = (width * (double) height)
                / ((double) REFERENCE_WIDTH * (double) REFERENCE_HEIGHT);
        return (float) (REFERENCE_SCALE * Math.sqrt(Math.sqrt(areaRatio)));
    }
}
