// Regenerate legacy_pitch_golden.json from the retained Android sources:
// javac -d /tmp/pitch-fixture app/src/com/tadaoyamaoka/vocalpitchmonitor/{Analyzer,FFT4g}.java test/domain/audio/legacy_pitch_fixture.java
// java -cp /tmp/pitch-fixture legacy_pitch_fixture > test/domain/audio/legacy_pitch_golden.json
import com.tadaoyamaoka.vocalpitchmonitor.Analyzer;
import com.tadaoyamaoka.vocalpitchmonitor.FFT4g;

class legacy_pitch_fixture {
    public static void main(String[] args) throws Exception {
        if (args.length > 0 && args[0].equals("verify-fft")) {
            verifyLegacyFft();
            return;
        }
        double[] frequencies = {110, 261.6255653005986, 320, 342.3223386242056, 440};
        System.out.print("{\"sines\":[");
        for (int c = 0; c < frequencies.length; c++) {
            if (c > 0) System.out.print(",");
            System.out.print("{\"frequency\":" + frequencies[c] + ",\"frames\":[");
            run(frequencies[c], false, false);
            System.out.print("]}");
        }
        System.out.print("],\"harmonic\":[");
        run(110, true, false);
        System.out.print("],\"noise\":[");
        run(0, false, true);
        System.out.println("]}");
    }
    private static void run(double f, boolean harmonics, boolean noise) {
        Analyzer analyzer = new Analyzer();
        long state = 123456789;
        for (int i = 0; i < 44100 * 3; i++) {
            double phase = 2 * Math.PI * f * i / 44100;
            double wave = harmonics
                ? 0.2 * Math.sin(phase) + 0.7 * Math.sin(phase * 2) + 0.25 * Math.sin(phase * 3)
                : Math.sin(phase);
            state = (1664525 * state + 1013904223) & 0xffffffffL;
            short sample = noise ? (short) ((((state >>> 16) & 65535) - 32768) / 4)
                : (short) (8000 * wave);
            analyzer.addData(sample);
            if ((i + 1) % 1470 == 0) {
                if (i >= 1470) System.out.print(",");
                System.out.print(analyzer.get_peak_freq());
            }
        }
    }

    private static void verifyLegacyFft() throws Exception {
        var constructor = FFT4g.class.getDeclaredConstructor(int.class);
        constructor.setAccessible(true);
        for (int n : new int[] {16, 4096}) {
            double[] original = new double[n];
            double[] data = new double[n];
            for (int i = 0; i < n; i++)
                data[i] = original[i] = Math.sin(i * 0.7) + 0.3 * Math.cos(i * 2.1);
            FFT4g fft = constructor.newInstance(n);
            fft.rdft(1, data);
            double maxError = 0;
            for (int k = 0; k <= n / 2; k++) {
                double real = 0, imaginary = 0;
                for (int i = 0; i < n; i++) {
                    real += original[i] * Math.cos(2 * Math.PI * k * i / n);
                    imaginary += original[i] * Math.sin(2 * Math.PI * k * i / n);
                }
                maxError = Math.max(maxError, Math.abs(data[k == n / 2 ? 1 : 2 * k] - real));
                if (k > 0 && k < n / 2)
                    maxError = Math.max(maxError, Math.abs(data[2 * k + 1] - imaginary));
            }
            System.out.println("N=" + n + " max DFT error=" + maxError);
            fft.rdft(-1, data);
            maxError = 0;
            for (int i = 0; i < n; i++)
                maxError = Math.max(maxError, Math.abs(data[i] - original[i] * n / 2));
            System.out.println("round-trip error=" + maxError);
        }
    }
}
