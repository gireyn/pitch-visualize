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
 *   甲4: 320                  ← reference note "name[register]: frequency"
 *   0\186ed6 7\186ed6 ...     ← nominal pitches; the LAST one is the equave
 *   甲 乙 丙 丁 戊 己 庚 辛 壬 癸  ← optional scale note names
 *   136 84 ... 84             ← optional per-note colors (0..255, R=G=B)
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
    /** Size of one period (equave) in cents. */
    public double equaveCents = 0.0;
    /** Parse error message, or null if parse succeeded. */
    public String error = null;

    /**
     * Color used to draw note {@code i} (rows, labels): the config's own
     * color list when present (wrapped), otherwise the default look —
     * RGB(136,136,136) for the first note and RGB(84,84,84) for the rest.
     */
    public int colorFor(int i) {
        if (colors != null && colors.length > 0) {
            return colors[i % colors.length];
        }
        return i == 0 ? 0xFF888888 : 0xFF545454;
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
            c.error = "reference note line must look like \"甲4: 320\"";
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

        // ---- optional scale note names and per-note colors ----
        // The color list, when present, is the last line of the config: every
        // token is an integer 0..255 (equal R,G,B) and there are at most as
        // many values as scale notes (a shorter list wraps around).
        int nameEnd = lines.size();
        if (lines.size() > 2) {
            String[] lastTokens = lines.get(lines.size() - 1).split("\\s+");
            boolean colorLine = lastTokens.length >= 1 && lastTokens.length <= n;
            if (colorLine) {
                int[] vals = new int[lastTokens.length];
                for (int t = 0; t < lastTokens.length && colorLine; t++) {
                    String tok = lastTokens[t];
                    boolean okTok = tok.length() > 0 && tok.length() <= 3;
                    int v = 0;
                    for (int d = 0; okTok && d < tok.length(); d++) {
                        char ch = tok.charAt(d);
                        if (ch < '0' || ch > '9') {
                            okTok = false;
                        } else {
                            v = v * 10 + (ch - '0');
                        }
                    }
                    if (okTok && v <= 255) {
                        vals[t] = v;
                    } else {
                        colorLine = false;
                    }
                }
                if (colorLine) {
                    c.colors = new int[vals.length];
                    for (int t = 0; t < vals.length; t++) {
                        c.colors[t] = 0xFF000000 | (vals[t] * 0x010101);
                    }
                    nameEnd = lines.size() - 1;
                }
            }
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
            if (lines.length >= 11 && lines[10].startsWith("colors")) {
                String[] cTok2 = lines[10].substring(6).trim().split("\\s+");
                c.colors = new int[cTok2.length];
                for (int i = 0; i < cTok2.length; i++) {
                    int v = Integer.parseInt(cTok2[i]);
                    c.colors[i] = 0xFF000000 | (v * 0x010101);
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
