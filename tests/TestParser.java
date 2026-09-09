import com.tadaoyamaoka.vocalpitchmonitor.ScaleConfig;
import com.tadaoyamaoka.vocalpitchmonitor.MathEval;
import java.io.File;
import java.nio.charset.Charset;
import java.nio.file.Files;

public class TestParser {
    static int fails = 0;
    static void check(String label, boolean cond) { System.out.println((cond ? "PASS " : "FAIL ") + label); if (!cond) fails++; }
    static void checkNear(String label, double got, double exp, double eps) {
        boolean ok = Math.abs(got - exp) <= eps;
        System.out.println((ok ? "PASS " : "FAIL ") + label + " got=" + got + " exp=" + exp);
        if (!ok) fails++;
    }
    public static void main(String[] args) throws Exception {
        checkNear("eval 1/13*1901.955", MathEval.eval("1/13*1901.9550008653873"), 146.3042, 1e-3);
        checkNear("eval Math.pow(3/2,3)", MathEval.eval("Math.pow(3/2,3)"), 3.375, 1e-9);
        checkNear("eval MATH.pow", MathEval.eval("MATH.pow(3, 2)"), 9.0, 1e-9);
        checkNear("eval Math.log(3)/Math.LN2", MathEval.eval("(1*1200*Math.log(3)/Math.LN2)"), 1901.9550008653873, 1e-6);
        checkNear("eval 2**3", MathEval.eval("2**3"), 8.0, 1e-9);
        check("eval NaN invalid", Double.isNaN(MathEval.eval("1+")));
        checkNear("c cents", ScaleConfig.parseCentsOrRatio("204.15565774574566c"), 204.15565774574566, 1e-9);
        checkNear("ratio 3/2", ScaleConfig.parseCentsOrRatio("3/2"), 701.9550008653873, 1e-6);
        checkNear("ratio 2187/2048", ScaleConfig.parseCentsOrRatio("2187/2048"), 113.68500605771193, 1e-6);
        checkNear("ed a\\b", ScaleConfig.parseCentsOrRatio("5\\53"), 5.0 * 1200.0 / 53.0, 1e-9);
        checkNear("ed a\\bedc", ScaleConfig.parseCentsOrRatio("7\\186ed6"), 7.0 * 1200.0 * Math.log(6.0) / Math.log(2.0) / 186.0, 1e-9);
        checkNear("ed 72\\186ed6", ScaleConfig.parseCentsOrRatio("72\\186ed6"), 1200.7567745285369, 1e-6);
        checkNear("me", ScaleConfig.parseCentsOrRatio("1000me"), 1000.0 / Math.log(2.0) * 1.2, 1e-9);
        checkNear("ie", ScaleConfig.parseCentsOrRatio("ie2"), (1000.0 / 2.0) / Math.log(2.0) * 1.2, 1e-9);
        check("invalid ed", ScaleConfig.parseCentsOrRatio("5ed") == null);

        String tg = new String(Files.readAllBytes(new File("/media/fsek294Gi/package/pitch-visualize/pitch-visualize/天干音阶.txt").toPath()), Charset.forName("UTF-8"));
        ScaleConfig cfg = ScaleConfig.parse(tg, "天干音阶");
        if (cfg.error != null) { System.out.println("FAIL 天干 parse: " + cfg.error); fails++; }
        else {
            check("天干 names count=10", cfg.names.length == 10);
            check("天干 refIndex=0 (甲)", cfg.refIndex == 0);
            checkNear("天干 equave", cfg.equaveCents, 1200.7567745285369, 1e-6);
            checkNear("甲4 freq", cfg.noteFreq(0, 4), 320.0, 1e-9);
            checkNear("甲5 freq", cfg.noteFreq(0, 5), 320.0 * Math.pow(2.0, cfg.equaveCents / 1200.0), 1e-6);
            int[] nn = cfg.nearestNote((AnalyzerRef.log2(320.0) - AnalyzerRef.LOG2_FC1) * 1200.0);
            check("nearest(320Hz) = 甲4", nn[0] == 0 && nn[1] == 4);
        }
        String tg2 = new String(Files.readAllBytes(new File("/media/fsek294Gi/package/pitch-visualize/pitch-visualize/musescore-xen-tuner/tunings/天干音阶.txt").toPath()), Charset.forName("UTF-8"));
        ScaleConfig cfg2 = ScaleConfig.parse(tg2, "天干音阶");
        if (cfg2.error != null) { System.out.println("FAIL tg2 parse: " + cfg2.error); fails++; }
        else { check("tg2 E4 anchors first nominal", cfg2.refIndex == 0); checkNear("tg2 freq(0,4)=320", cfg2.noteFreq(0, 4), 320.0, 1e-9); }
        String sx = new String(Files.readAllBytes(new File("/media/fsek294Gi/package/pitch-visualize/pitch-visualize/musescore-xen-tuner/tunings/散星音阶.txt").toPath()), Charset.forName("UTF-8"));
        ScaleConfig cfg3 = ScaleConfig.parse(sx, "散星音阶");
        if (cfg3.error != null) { System.out.println("FAIL 散星 parse: " + cfg3.error); fails++; }
        else { check("散星 N=9", cfg3.cents.length == 9); checkNear("散星 equave=1200", cfg3.equaveCents, 1200.0, 1e-9); }
        String ji = new String(Files.readAllBytes(new File("/media/fsek294Gi/package/pitch-visualize/pitch-visualize/musescore-xen-tuner/tunings/ji2,3,5.txt").toPath()), Charset.forName("UTF-8"));
        ScaleConfig cfg4 = ScaleConfig.parse(ji, "ji235");
        if (cfg4.error != null) { System.out.println("FAIL ji235 parse: " + cfg4.error); fails++; }
        else {
            check("ji235 N=7", cfg4.cents.length == 7);
            checkNear("ji235 C4 freq", cfg4.noteFreq(0, 4), 261.6255653005986, 1e-9);
            checkNear("ji235 81/64 -> 407.82c", cfg4.cents[2], 407.8200034615497, 1e-6);
        }
        ScaleConfig back = ScaleConfig.fromPayload(cfg.toPayload());
        check("payload round-trip", back != null && back.refIndex == cfg.refIndex && back.cents.length == cfg.cents.length);
        ScaleConfig cfg5 = ScaleConfig.parse("E4: 330\n1/1 9/8 5/4 4/3 3/2 5/3 15/8 2/1\nC D E F G A B", "test");
        if (cfg5.error != null) { System.out.println("FAIL cfg5: " + cfg5.error); fails++; }
        else {
            check("cfg5 E4 name-match index 2", cfg5.refIndex == 2);
            checkNear("cfg5 freq(2,4)=330", cfg5.noteFreq(2, 4), 330.0, 1e-9);
            checkNear("cfg5 C4 = 264", cfg5.noteFreq(0, 4), 264.0, 1e-9);
            check("cfg5 no color line -> colors null", cfg5.colors == null);
        }

        // per-note colors in the tuning config
        String tgColors = new String(Files.readAllBytes(new File("/media/fsek294Gi/package/pitch-visualize/pitch-visualize/天干音阶.txt").toPath()), Charset.forName("UTF-8"));
        ScaleConfig cfgColors = ScaleConfig.parse(tgColors, "天干音阶");
        if (cfgColors.error != null) { System.out.println("FAIL 天干 colors parse: " + cfgColors.error); fails++; }
        else {
            check("天干 colors count=10", cfgColors.colors != null && cfgColors.colors.length == 10);
            check("天干 colors[0]=RGB(136)", cfgColors.colors != null && cfgColors.colors[0] == 0xFF888888);
            check("天干 colors[1]=RGB(84)", cfgColors.colors != null && cfgColors.colors[1] == 0xFF545454);
            check("天干 colorFor(0) = first color", cfgColors.colorFor(0) == 0xFF888888);
            check("天干 colorFor(10) wraps to colors[0]", cfgColors.colorFor(10) == 0xFF888888);
            check("天干 colorFor(11) wraps to colors[1]", cfgColors.colorFor(11) == 0xFF545454);
        }
        ScaleConfig cfgColorsBack = ScaleConfig.fromPayload(cfgColors.toPayload());
        check("colors payload round-trip", cfgColorsBack != null && cfgColorsBack.colors != null
                && cfgColorsBack.colors.length == cfgColors.colors.length
                && cfgColorsBack.colors[0] == cfgColors.colors[0]
                && cfgColorsBack.colors[1] == cfgColors.colors[1]);

        // a color line shorter than the note count wraps
        ScaleConfig cfg6 = ScaleConfig.parse("C4: 261.6255653005986\n0\\12 1\\12 2\\12 3\\12 4\\12 5\\12 6\\12 7\\12 8\\12 9\\12 10\\12 11\\12 12\\12\nC C# D D# E F F# G G# A A# B\n136 84", "wrap");
        if (cfg6.error != null) { System.out.println("FAIL cfg6: " + cfg6.error); fails++; }
        else {
            check("wrap colors length=2", cfg6.colors != null && cfg6.colors.length == 2);
            check("wrap colorFor(0)=136", cfg6.colorFor(0) == 0xFF888888);
            check("wrap colorFor(1)=84", cfg6.colorFor(1) == 0xFF545454);
            check("wrap colorFor(2) wraps to 136", cfg6.colorFor(2) == 0xFF888888);
            check("wrap names intact", "C".equals(cfg6.names[0]) && "B".equals(cfg6.names[11]));
        }

        // default file bundled look: 7ed2 colors
        String ed2 = new String(Files.readAllBytes(new File("/media/fsek294Gi/package/pitch-visualize/pitch-visualize/7ed2 on C.txt").toPath()), Charset.forName("UTF-8"));
        ScaleConfig cfg7 = ScaleConfig.parse(ed2, "7ed2 on C");
        if (cfg7.error != null) { System.out.println("FAIL 7ed2 parse: " + cfg7.error); fails++; }
        else {
            check("7ed2 names C..B", "C".equals(cfg7.names[0]) && "B".equals(cfg7.names[6]));
            check("7ed2 colors length=7", cfg7.colors != null && cfg7.colors.length == 7);
            check("7ed2 colors[0]=136", cfg7.colors != null && cfg7.colors[0] == 0xFF888888);
            check("7ed2 colors[1]=84", cfg7.colors != null && cfg7.colors[1] == 0xFF545454);
        }
        // fallback defaults when a config carries no colors
        check("no-color fallback colorFor(0)=136", cfg5.colorFor(0) == 0xFF888888);
        check("no-color fallback colorFor(1)=84", cfg5.colorFor(1) == 0xFF545454);
        System.out.println(fails == 0 ? "ALL TESTS PASSED" : fails + " TESTS FAILED");
        System.exit(fails == 0 ? 0 : 1);
    }
    static class AnalyzerRef {
        static final double LOG2_FC1 = Math.log(55.0 * Math.pow(2.0, -0.75)) / Math.log(2.0);
        static double log2(double d) { return Math.log(d) / Math.log(2.0); }
    }
}
