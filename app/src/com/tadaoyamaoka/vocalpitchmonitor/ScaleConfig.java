package com.tadaoyamaoka.vocalpitchmonitor;

import java.util.ArrayList;
import java.util.List;

/**
 * Parser for tuning-config files (e.g. 天干音阶.txt) following the
 * musescore-xen-tuner text-config grammar strictly.
 *
 * Supported config layout (mirrors xen-tuner's parseTuningConfig):
 * <pre>
 *   // comment lines start with //
 *   甲4: 319                  ← reference note "name[register]: frequency"
 *   0\186ed6 7\186ed6 ...     ← nominal pitches; the LAST one is the equave
 *   甲 乙 丙 丁 戊 己 庚 辛 壬 癸  ← optional scale note names
 *   136 84 ... 84             ← optional per-note colors (0..255, R=G=B)
 *   6t 8t 6t ... 6t           ← optional per-note line thickness
 * </pre>
 *
 * The optional rows may appear as the last lines of the config in either
 * order; a row is recognised by its content. The thickness row is the one
 * whose tokens all end in "t": the stem before the "t" is a general
 * Math.* expression (the same evaluator the pitch tokens use), and one unit
 * of thickness is 1/4 of that value — so 8t = 2.0 units, 7t = 1.75,
 * 6t = 1.5, 7.5t = 1.875, 13/2t = 1.625, 5*Math.LN2t ≈ 0.866. Pitch-only
 * syntax ("\", "ed", the "c"/"me" suffixes, the "ie" prefix) is *not*
 * accepted there: such a token is a parse error, exactly like a wrong token
 * count. Without the row the classic defaults apply — 2.0 units (8t) for the
 * first note and 1.5 units (6t) for every other note.
 * </pre>
 *
 * Every cents/ratio token is parsed with {@link #parseCentsOrRatio(String)},
 * a faithful port of xen-tuner's parseCentsOrRatio, which supports:
 *  - "c" suffix      : value in cents, arbitrary Math.* expression before it
 *  - "me" suffix     : decimal value, offset = v / ln2 * 1.2 cents
 *  - "ie" prefix     : offset = 1000/v / ln2 * 1.2 cents
 *  - "\" or "ed"     : equal division a\bedc → a/b of the c:1 equave
 *  - plain ratio     : log2(ratio) * 1200 cents (negative ratios inverted)
 *  - Math.* / MATH.* function calls and constants inside expressions
 */
public class ScaleConfig {

    /** Display name, usually the imported file name without extension. */
    public String displayName = "";
    /** Reference note name as written in the config (e.g. "甲"). */
    public String refName = "";
    /** Index of the reference note within the scale (nominal). */
    public int refIndex = -1;
    /** Register (octave number) of the reference note. */
    public int refRegister = 4;
    /** Reference frequency in Hz. */
    public double refFreq = 0.0;
    /** Cents of each scale note within one period. */
    public double[] cents;
    /** Names of the scale notes. */
    public String[] names;
    /**
     * Optional per-note colors (ARGB), one per scale note within one period
     * (the next-period leading note is NOT included, mirroring the names).
     * A config line of integers supplies equal R,G,B values, e.g. "136"
     * means RGB(136,136,136). When the list is shorter than the note count
     * it wraps around from the start; null = no color line in the config.
     */
    public int[] colors = null;
    /**
     * Optional per-note line thickness in view units, one per scale note within
     * one period (like {@link #colors}), written in the config as the "…t" row
     * where one unit is 1/4 of the value before the "t" (8t = 2.0 units,
     * 7t = 1.75, 6t = 1.5). A wrong token count is a parse error, not a wrap;
     * null = no thickness row, which means the classic defaults.
     */
    public float[] thickness = null;
    /** Classic thickness of the first note's line, i.e. "8t". */
    public static final float DEFAULT_THICKNESS_FIRST = 2.0f;
    /** Classic thickness of every other note's line, i.e. "6t". */
    public static final float DEFAULT_THICKNESS_OTHER = 1.5f;
    /**
     * A note name written as "NN" means "this note has no name". The reference
     * note must have a real name, and a scale with no named note at all is
     * rejected: the large display shows the nearest named note.
     */
    public static final String NO_NAME = "NN";

    /** True when a name token is a real name ("NN" and blanks are not). */
    public static boolean isNamed(String name) {
        return name != null && name.length() > 0 && !NO_NAME.equals(name);
    }

    /** True when note {@code i} of this config carries a real name. */
    public boolean noteIsNamed(int i) {
        return names != null && i >= 0 && i < names.length && isNamed(names[i]);
    }
    /** Size of one period (equave) in cents. */
    public double equaveCents = 0.0;
    /** Parse error message, or null if parse succeeded. */
    public String error = null;

    /**
     * Color used to draw note {@code i} (rows, labels): the config's own color
     * list when present (wrapped), otherwise four default levels —
     * <pre>
     *   first note, named ("root")      RGB(136,136,136)
     *   first note without a name       RGB(84,84,84)
     *   other notes with a name         RGB(84,84,84)
     *   other notes without a name      RGB(42,42,42)
     * </pre>
     * so an unnamed note is dimmer than a named one, and the root stays the
     * brightest when it has a name.
     */
    public int colorFor(int i) {
        if (colors != null && colors.length > 0) {
            return colors[i % colors.length];
        }
        boolean named = noteIsNamed(i);
        if (i == 0) {
            return named ? 0xFF888888 : 0xFF545454;
        }
        return named ? 0xFF545454 : 0xFF2A2A2A;
    }

    /**
     * The configured grey value r (0..255) of note {@code i}: the colour row's
     * value when present, otherwise the classic 136 (first note) / 84 (rest).
     */
    public int colorValueFor(int i) {
        return colorFor(i) & 0xFF;
    }

    /**
     * Dimmest of each note's <em>effective</em> colour value: the colour row
     * where it exists, and the four default levels where it does not (so a
     * config with no colour row and only named notes gives 84, while one with
     * unnamed notes gives 42). Minor tuner ticks are drawn from it.
     */
    public int minColorValue() {
        int count = cents != null ? cents.length : 0;
        if (count <= 0) {
            return 84;
        }
        int min = 255;
        for (int i = 0; i < count; i++) {
            int v = colorFor(i) & 0xFF;
            if (v < min) {
                min = v;
            }
        }
        return min;
    }

    /**
     * Line thickness used to draw note {@code i}: the config's own "…t" row
     * when it has one, otherwise the classic defaults — 2.0 units (8t) for the
     * first note and 1.5 units (6t) for every other note.
     */
    public float thicknessFor(int i) {
        if (thickness != null && thickness.length > 0) {
            return thickness[(i % thickness.length + thickness.length) % thickness.length];
        }
        return i == 0 ? DEFAULT_THICKNESS_FIRST : DEFAULT_THICKNESS_OTHER;
    }

    /**
     * True when a trailing line is meant to be the thickness row: at least one
     * token carries the "t" suffix. Such a line must then be valid in full —
     * a half-written row like "5c 6t 6t" is a parse error instead of quietly
     * becoming the note-name row. Colour rows contain digits only and names
     * ending in "t" are not a thing in practice, so this marker is safe.
     */
    private static boolean looksLikeThicknessRow(String[] tokens) {
        for (int i = 0; i < tokens.length; i++) {
            String token = tokens[i];
            if (token.length() >= 2 && token.charAt(token.length() - 1) == 't') {
                return true;
            }
        }
        return false;
    }

    /**
     * One thickness token in view units: "8t" -> 2.0, "7t" -> 1.75, "6t" -> 1.5,
     * "7.5t" -> 1.875, "13/2t" -> 1.625, "5*Math.LN2t" -> 0.866. The stem is a
     * general Math.* expression evaluated by {@link MathEval}, and one unit is
     * 1/4 of its value. Pitch-only syntax ("\", "ed", the "c"/"me" suffixes,
     * the "ie" prefix) is not accepted: those tokens evaluate to NaN and are
     * reported as errors. Negative values clamp to 0 (an invisible line).
     * Returns null when the token is not a thickness.
     */
    public static Float thicknessUnit(String token) {
        if (token == null || token.length() < 2) {
            return null;
        }
        if (token.charAt(token.length() - 1) != 't') {
            return null;
        }
        String stem = token.substring(0, token.length() - 1).trim();
        if (stem.length() == 0 || stem.indexOf('\\') >= 0 || stem.contains("ed")) {
            return null;
        }
        double value = MathEval.eval(stem) / 4.0;
        if (Double.isNaN(value) || Double.isInfinite(value)) {
            return null;
        }
        return Float.valueOf((float) Math.max(0.0, value));
    }

    /**
     * Colour values of a colour row (all tokens integers 0..255, at most one
     * per note so a shorter row wraps), or null when the line is not one.
     */
    private static int[] parseColorRow(String[] tokens, int n) {
        if (tokens.length < 1 || tokens.length > n) {
            return null;
        }
        int[] vals = new int[tokens.length];
        for (int t = 0; t < tokens.length; t++) {
            String tok = tokens[t];
            if (tok.length() == 0 || tok.length() > 3) {
                return null;
            }
            int v = 0;
            for (int d = 0; d < tok.length(); d++) {
                char ch = tok.charAt(d);
                if (ch < '0' || ch > '9') {
                    return null;
                }
                v = v * 10 + (ch - '0');
            }
            if (v > 255) {
                return null;
            }
            vals[t] = v;
        }
        return vals;
    }

    /**
     * Parse a cents/ratio token exactly like musescore-xen-tuner's
     * parseCentsOrRatio(). Returns null when the token is invalid.
     */
    public static Double parseCentsOrRatio(String str) {
        if (str == null) {
            return null;
        }
        str = str.trim();
        double offset;
        try {
            if (str.endsWith("c")) {
                // in cents
                offset = MathEval.eval(str.substring(0, str.length() - 1));
            } else if (str.endsWith("me")) {
                // decimal: v / ln2 * 1.2 cents
                offset = MathEval.eval(str.substring(0, str.length() - 2)) / Math.log(2.0) * 1.2;
            } else if (str.startsWith("ie")) {
                // decimal inverse: 1000/v / ln2 * 1.2 cents
                String rest = str.substring(2).trim();
                double v;
                try {
                    v = Double.parseDouble(rest);
                } catch (NumberFormatException e) {
                    return null;
                }
                if (v == 0.0) {
                    return null;
                }
                offset = (1000.0 / v) / Math.log(2.0) * 1.2;
            } else if (str.indexOf('\\') >= 0 || str.indexOf("ed") >= 0) {
                // equal division: a\bedc  (c defaults to 2)
                String[] parts = str.split("\\\\|ed");
                if (parts.length < 2 || parts.length > 3 || parts[0].length() == 0 || parts[1].length() == 0) {
                    return null;
                }
                double a = MathEval.eval(parts[0]);
                double b = MathEval.eval(parts[1]);
                double c = parts.length > 2 && parts[2].length() > 0 ? MathEval.eval(parts[2]) : 2.0;
                if (Double.isNaN(a) || Double.isNaN(b) || Double.isNaN(c) || b == 0.0 || c <= 0.0) {
                    return null;
                }
                offset = a * 1200.0 * Math.log(c) / Math.log(2.0) / b;
            } else {
                // ratio
                double ratio = MathEval.eval(str);
                if (Double.isNaN(ratio)) {
                    return null;
                }
                if (ratio < 0.0) {
                    offset = -Analyzer.log2(-ratio) * 1200.0;
                } else if (ratio == 0.0) {
                    offset = 0.0;
                } else {
                    offset = Analyzer.log2(ratio) * 1200.0;
                }
            }
        } catch (Exception e) {
            return null;
        }
        if (Double.isNaN(offset)) {
            return null;
        }
        return Double.valueOf(offset);
    }

    /**
     * Parse a full tuning config text.
     *
     * @param text        file contents
     * @param displayName name shown in the UI (e.g. file name)
     * @return parsed config; check {@link #error} for failure
     */
    public static ScaleConfig parse(String text, String displayName) {
        ScaleConfig c = new ScaleConfig();
        c.displayName = displayName == null ? "" : displayName;
        if (text == null) {
            c.error = "empty config";
            return c;
        }
        String normalized = text.replace("\r\n", "\n").replace('\r', '\n');
        if (normalized.length() > 0 && normalized.charAt(0) == '\uFEFF') {
            normalized = normalized.substring(1); // strip UTF-8 BOM
        }
        String[] rawLines = normalized.split("\n");
        List<String> lines = new ArrayList<String>();
        for (String raw : rawLines) {
            int idx = raw.indexOf("//");
            String l = idx >= 0 ? raw.substring(0, idx) : raw;
            l = l.trim();
            if (l.length() > 0) {
                lines.add(l);
            }
        }
        if (lines.size() < 2) {
            c.error = "need at least a reference note line and a pitch line";
            return c;
        }

        // ---- reference note: "name[register]: frequency" ----
        String refLine = lines.get(0);
        int colon = refLine.indexOf(':');
        if (colon < 0) {
            c.error = "reference note line must look like \"甲4: 319\"";
            return c;
        }
        String refSpec = refLine.substring(0, colon).trim();
        String freqStr = refLine.substring(colon + 1).trim();
        double freq = MathEval.eval(freqStr);
        if (Double.isNaN(freq) || freq <= 0.0) {
            c.error = "invalid reference frequency: " + freqStr;
            return c;
        }
        c.refFreq = freq;

        String namePart = refSpec;
        int register = 4;
        int i = refSpec.length() - 1;
        while (i >= 0 && Character.isDigit(refSpec.charAt(i))) {
            i--;
        }
        if (i < refSpec.length() - 1) {
            namePart = refSpec.substring(0, i + 1);
            try {
                register = Integer.parseInt(refSpec.substring(i + 1));
            } catch (NumberFormatException e) {
                register = 4;
            }
        }
        c.refName = namePart;
        c.refRegister = register;

        // ---- nominal pitches (last token is the equave) ----
        String[] tokens = lines.get(1).split("\\s+");
        if (tokens.length < 2) {
            c.error = "need at least one scale pitch and an equave";
            return c;
        }
        double[] nominals = new double[tokens.length];
        for (i = 0; i < tokens.length; i++) {
            Double v = parseCentsOrRatio(tokens[i]);
            if (v == null) {
                c.error = "cannot parse pitch: " + tokens[i];
                return c;
            }
            nominals[i] = v.doubleValue();
        }
        double equave = nominals[nominals.length - 1];
        if (equave == 0.0) {
            c.error = "equave size must be non-zero";
            return c;
        }
        int n = nominals.length - 1;
        c.cents = new double[n];
        for (i = 0; i < n; i++) {
            c.cents[i] = nominals[i];
        }
        c.equaveCents = equave;

        // ---- optional trailing rows: note names, colors, line thickness ----
        // The colour row (integers 0..255, equal R,G,B, at most one per note,
        // a shorter list wraps) and the thickness row (one "…t" value per
        // note) may be given as the last lines in either order; a row is
        // recognised by its content, and everything above them is names.
        int nameEnd = lines.size();
        for (int pass = 0; pass < 2 && nameEnd > 2; pass++) {
            String[] tail = lines.get(nameEnd - 1).trim().split("\\s+");
            if (tail.length == 1 && tail[0].length() == 0) {
                nameEnd--;
                continue;
            }
            if (looksLikeThicknessRow(tail)) {
                if (c.thickness != null) {
                    c.error = "more than one thickness row";
                    return c;
                }
                if (tail.length != n) {
                    c.error = "thickness row needs " + n + " values, found " + tail.length;
                    return c;
                }
                float[] values = new float[n];
                for (int t = 0; t < n; t++) {
                    Float unit = thicknessUnit(tail[t]);
                    if (unit == null) {
                        c.error = "invalid thickness token: " + tail[t];
                        return c;
                    }
                    values[t] = unit.floatValue();
                }
                c.thickness = values;
                nameEnd--;
                continue;
            }
            int[] colorVals = parseColorRow(tail, n);
            if (colorVals != null) {
                if (c.colors != null) {
                    c.error = "more than one color row";
                    return c;
                }
                c.colors = new int[colorVals.length];
                for (int t = 0; t < colorVals.length; t++) {
                    c.colors[t] = 0xFF000000 | (colorVals[t] * 0x010101);
                }
                nameEnd--;
                continue;
            }
            break;
        }
        StringBuilder namesBuf = new StringBuilder();
        for (int k = 2; k < nameEnd; k++) {
            if (namesBuf.length() > 0) {
                namesBuf.append(' ');
            }
            namesBuf.append(lines.get(k));
        }
        String[] nameTokens = namesBuf.toString().trim().split("\\s+");
        c.names = new String[n];
        if (nameTokens.length >= 1 && nameTokens[0].length() > 0) {
            for (i = 0; i < n; i++) {
                c.names[i] = nameTokens[i % nameTokens.length];
            }
        } else {
            for (i = 0; i < n; i++) {
                c.names[i] = String.valueOf(i + 1);
            }
        }

        // ---- names must leave something to show ----
        int namedNotes = 0;
        for (i = 0; i < n; i++) {
            if (isNamed(c.names[i])) {
                namedNotes++;
            }
        }
        if (namedNotes == 0) {
            c.error = "a scale needs at least one named note (\"NN\" means no name)";
            return c;
        }
        if (!isNamed(namePart)) {
            c.error = "the reference note needs a name; \"" + namePart + "\" is not one";
            return c;
        }

        // ---- locate the reference note ----
        c.refIndex = -1;
        for (i = 0; i < n; i++) {
            if (c.names[i].equals(namePart)) {
                c.refIndex = i;
                break;
            }
        }
        if (c.refIndex < 0) {
            // xen-tuner anchors the reference note at relative nominal 0:
            // the first listed nominal is the reference note's tuning, and the
            // standard letter grid (A..G) is only used for naming. Standard
            // letters are always accepted (e.g. "A4: 440", "E4: 320").
            if (isStandardNoteName(namePart)) {
                c.refIndex = 0;
            }
        }
        if (c.refIndex < 0) {
            c.error = "reference note \"" + namePart + "\" is not one of the scale notes";
            return c;
        }
        return c;
    }

    /** True if the given name looks like a standard note letter + optional octave/accidental. */
    private static boolean isStandardNoteName(String spec) {
        if (spec == null || spec.length() == 0) {
            return false;
        }
        char c0 = Character.toLowerCase(spec.charAt(0));
        if ("abcdefg".indexOf(c0) < 0) {
            return false;
        }
        // everything after the letter must be accidentals and/or digits
        for (int i = 1; i < spec.length(); i++) {
            char c = spec.charAt(i);
            if (!Character.isDigit(c) && c != '#' && c != '♯' && c != 'b' && c != '♭' && c != 'x') {
                return false;
            }
        }
        return true;
    }

    /**
     * Absolute cents of scale note {@code i} at period {@code p}, measured
     * from the same baseline as {@link Analyzer#freq_to_cent} (C1 ≈ 32.70 Hz).
     */
    public double noteAbsCent(int i, int p) {
        double refAbs = (Analyzer.log2(refFreq) - Analyzer.log2_f_c1) * 1200.0;
        return refAbs + cents[i] - cents[refIndex] + (p - refRegister) * equaveCents;
    }

    /** Frequency in Hz of scale note {@code i} at period {@code p}. */
    public double noteFreq(int i, int p) {
        return refFreq * Math.pow(2.0, (cents[i] - cents[refIndex] + (p - refRegister) * equaveCents) / 1200.0);
    }

    /**
     * Find the nearest scale note (index, period) to an absolute-cent value.
     * Returns {index, period}; deviation in cents is the second element.
     */
    /**
     * Like {@link #nearestNote(double)} but skipping notes without a name, so
     * the large display above the tuner never shows "NN". Returns null when no
     * note is named (parsing rejects such a config).
     */
    public int[] nearestNamedNote(double absCent) {
        int bestI = -1;
        int bestP = refRegister;
        double bestDev = Double.MAX_VALUE;
        double refAbs = (Analyzer.log2(refFreq) - Analyzer.log2_f_c1) * 1200.0;
        for (int i = 0; i < cents.length; i++) {
            if (!noteIsNamed(i)) {
                continue;
            }
            double rel = absCent - refAbs - (cents[i] - cents[refIndex]);
            int p = (int) Math.round(rel / equaveCents) + refRegister;
            double dev = Math.abs(absCent - noteAbsCent(i, p));
            if (dev < bestDev) {
                bestDev = dev;
                bestI = i;
                bestP = p;
            }
        }
        return bestI < 0 ? null : new int[]{bestI, bestP};
    }

    public int[] nearestNote(double absCent) {
        int bestI = 0;
        int bestP = refRegister;
        double bestDev = Double.MAX_VALUE;
        double refAbs = (Analyzer.log2(refFreq) - Analyzer.log2_f_c1) * 1200.0;
        for (int i = 0; i < cents.length; i++) {
            double rel = absCent - refAbs - (cents[i] - cents[refIndex]);
            int p = (int) Math.round(rel / equaveCents) + refRegister;
            double dev = Math.abs(absCent - noteAbsCent(i, p));
            if (dev < bestDev) {
                bestDev = dev;
                bestI = i;
                bestP = p;
            }
        }
        return new int[]{bestI, bestP};
    }

    // ---------------- serialization (cached copy) ----------------

    /**
     * Serialize to a compact text form used as the on-device cache so the
     * scale survives file permission loss / app restarts.
     */
    public String toPayload() {
        StringBuilder sb = new StringBuilder();
        sb.append("XENCFG1\n");
        sb.append(displayName).append('\n');
        sb.append(refName).append('\n');
        sb.append(refIndex).append('\n');
        sb.append(refRegister).append('\n');
        sb.append(refFreq).append('\n');
        sb.append(equaveCents).append('\n');
        sb.append(cents.length).append('\n');
        for (int i = 0; i < cents.length; i++) {
            if (i > 0) {
                sb.append(' ');
            }
            sb.append(cents[i]);
        }
        sb.append('\n');
        for (int i = 0; i < names.length; i++) {
            if (i > 0) {
                sb.append(' ');
            }
            sb.append(names[i]);
        }
        if (colors != null && colors.length > 0) {
            sb.append("\ncolors ");
            for (int i = 0; i < colors.length; i++) {
                if (i > 0) {
                    sb.append(' ');
                }
                // Grayscale colors are stored like the file grammar values.
                sb.append((colors[i] >> 16) & 0xFF);
            }
        }
        if (thickness != null && thickness.length > 0) {
            sb.append("\nthickness ");
            for (int i = 0; i < thickness.length; i++) {
                if (i > 0) {
                    sb.append(' ');
                }
                // View units, printed so the value survives the round trip.
                sb.append(Float.toString(thickness[i]));
            }
        }
        return sb.toString();
    }

    /** Restore from a payload produced by {@link #toPayload()}; null on error. */
    public static ScaleConfig fromPayload(String payload) {
        if (payload == null) {
            return null;
        }
        try {
            String[] lines = payload.split("\n", -1);
            if (lines.length < 8 || !lines[0].equals("XENCFG1")) {
                return null;
            }
            ScaleConfig c = new ScaleConfig();
            c.displayName = lines[1];
            c.refName = lines[2];
            c.refIndex = Integer.parseInt(lines[3]);
            c.refRegister = Integer.parseInt(lines[4]);
            c.refFreq = Double.parseDouble(lines[5]);
            c.equaveCents = Double.parseDouble(lines[6]);
            int n = Integer.parseInt(lines[7]);
            if (n < 1 || lines.length < 9) {
                return null;
            }
            String[] cTok = lines[8].trim().split("\\s+");
            if (cTok.length < n) {
                return null;
            }
            c.cents = new double[n];
            for (int i = 0; i < n; i++) {
                c.cents[i] = Double.parseDouble(cTok[i]);
            }
            String[] nTok = lines.length >= 10 ? lines[9].trim().split("\\s+") : new String[0];
            c.names = new String[n];
            for (int i = 0; i < n; i++) {
                c.names[i] = i < nTok.length && nTok[i].length() > 0 ? nTok[i] : String.valueOf(i + 1);
            }
            for (int line = 10; line < lines.length; line++) {
                if (lines[line].startsWith("colors")) {
                    String[] cTok2 = lines[line].substring(6).trim().split("\\s+");
                    c.colors = new int[cTok2.length];
                    for (int i = 0; i < cTok2.length; i++) {
                        int v = Integer.parseInt(cTok2[i]);
                        c.colors[i] = 0xFF000000 | (v * 0x010101);
                    }
                } else if (lines[line].startsWith("thickness")) {
                    String[] tTok = lines[line].substring(9).trim().split("\\s+");
                    c.thickness = new float[tTok.length];
                    for (int i = 0; i < tTok.length; i++) {
                        c.thickness[i] = Float.parseFloat(tTok[i]);
                    }
                }
            }
            if (c.refIndex < 0 || c.refIndex >= n || c.refFreq <= 0.0 || c.equaveCents == 0.0) {
                return null;
            }
            return c;
        } catch (Exception e) {
            return null;
        }
    }
}
