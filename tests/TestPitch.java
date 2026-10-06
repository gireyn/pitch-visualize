import com.tadaoyamaoka.vocalpitchmonitor.Analyzer;
import com.tadaoyamaoka.vocalpitchmonitor.ScaleConfig;
import java.io.File;
import java.nio.charset.Charset;
import java.nio.file.Files;

public class TestPitch {
    public static void main(String[] args) throws Exception {
        testFreq(new Analyzer(), 440.0, "A4 440Hz");
        testFreq(new Analyzer(), 261.6255653005986, "C4 261.63Hz");
        testFreq(new Analyzer(), 319.0, "甲4 319Hz");
        testFreq(new Analyzer(), 342.3223386242056, "乙4 342.32Hz");
        testFreq(new Analyzer(), 110.0, "A2 110Hz");
        String tg = new String(Files.readAllBytes(new File("/media/fsek294Gi/package/pitch-visualize/pitch-visualize/天干音阶.txt").toPath()), Charset.forName("UTF-8"));
        ScaleConfig cfg = ScaleConfig.parse(tg, "天干音阶");
        if (cfg.error != null) { System.out.println("FAIL config: " + cfg.error); System.exit(1); }
        int[] n1 = cfg.nearestNote((Analyzer.log2(319.0) - Analyzer.log2_f_c1) * 1200.0);
        System.out.println("319Hz -> " + cfg.names[n1[0]] + n1[1] + (n1[0]==0 && n1[1]==4 ? "  PASS" : "  FAIL"));
        int[] n2 = cfg.nearestNote((Analyzer.log2(342.3223386242056) - Analyzer.log2_f_c1) * 1200.0);
        System.out.println("342.32Hz -> " + cfg.names[n2[0]] + n2[1] + (n2[0]==1 && n2[1]==4 ? "  PASS" : "  FAIL"));
        int[] n3 = cfg.nearestNote((Analyzer.log2(640.2798244251317) - Analyzer.log2_f_c1) * 1200.0);
        System.out.println("640.28Hz -> " + cfg.names[n3[0]] + n3[1] + (n3[0]==0 && n3[1]==5 ? "  PASS" : "  FAIL"));
        testHoldGate();
    }

    /**
     * HOLD: a held stretch of audio must consume no room in the pitch history
     * — the first sample analysed after the hold is appended directly after
     * the last one from before it, so the melody line continues exactly where
     * it stopped — while the analysis itself (peak_freq) and the counter that
     * drives the BPM/metronome keep running. The .wav recording never goes
     * through the analyzer's history (Recorder writes its own buffer), so it
     * is unaffected either way.
     */
    static void testHoldGate() {
        Analyzer a = new Analyzer();
        double amp = 8000.0;
        int block = Analyzer.ANALYZE_INTERVAL * 30; // 30 analysis steps
        feed(a, amp, 440.0, block);
        int posBefore = a.get_pitch_buf_pos();
        int cntBefore = a.get_total_analyze_cnt();
        a.setPitchHistoryPaused(true);
        boolean gated = a.isPitchHistoryPaused();
        feed(a, amp, 880.0, block);
        boolean frozen = gated && a.get_pitch_buf_pos() == posBefore;
        boolean counting = a.get_total_analyze_cnt() > cntBefore;
        boolean analysing = a.get_peak_freq() > 800.0;
        a.setPitchHistoryPaused(false);
        feed(a, amp, 880.0, Analyzer.ANALYZE_INTERVAL);
        boolean continues = a.get_pitch_buf_pos() == posBefore + 1;
        boolean ok = frozen && counting && analysing && continues;
        System.out.println(String.format(
                "hold gate: history frozen %s, analysis alive %s (%d steps), continues directly %s%s",
                frozen, analysing, a.get_total_analyze_cnt(), continues, ok ? "  PASS" : "  FAIL"));
        if (!ok) {
            System.exit(1);
        }
    }

    static void feed(Analyzer a, double amp, double freq, int samples) {
        for (int i = 0; i < samples; i++) {
            a.addData((short) (amp * Math.sin(2 * Math.PI * freq * i / 44100.0)));
        }
    }

    static void testFreq(Analyzer a, double freq, String label) {
        double amp = 8000.0;
        for (int i = 0; i < 44100 * 3; i++) {
            a.addData((short) (amp * Math.sin(2 * Math.PI * freq * i / 44100.0)));
        }
        double peak = a.get_peak_freq();
        double err = Math.abs(peak - freq) / freq * 100.0;
        System.out.println(String.format("%s -> detected %.3f Hz (err %.2f%%) %s", label, peak, err, err < 2.0 ? "PASS" : "FAIL"));
    }
}
