package com.tadaoyamaoka.vocalpitchmonitor;

public class FFT4g {
    private int[] ip;
    private int n;
    private double[] w;

    /* JADX INFO: Access modifiers changed from: package-private */
    public FFT4g(int i) {
        this.n = i;
        int[] iArr = new int[((int) Math.sqrt(i / 2.0d)) + 2 + 1];
        this.ip = iArr;
        this.w = new double[i / 2];
        iArr[0] = 0;
    }

    public void rdft(int i, double[] dArr) {
        int i2 = this.ip[0];
        int i3 = this.n;
        if (i3 > (i2 << 2)) {
            i2 = i3 >> 2;
            makewt(i2);
        }
        int i4 = this.ip[1];
        int i5 = this.n;
        if (i5 > (i4 << 2)) {
            i4 = i5 >> 2;
            makect(i4, this.w, i2);
        }
        if (i >= 0) {
            int i6 = this.n;
            if (i6 > 4) {
                bitrv2(i6, dArr);
                cftfsub(dArr);
                rftfsub(dArr, i4, this.w, i2);
            } else if (i6 == 4) {
                cftfsub(dArr);
            }
            double d = dArr[0];
            double d2 = dArr[1];
            dArr[0] = d + d2;
            dArr[1] = d - d2;
            return;
        }
        double d3 = dArr[0];
        double d4 = (d3 - dArr[1]) * 0.5d;
        dArr[1] = d4;
        dArr[0] = d3 - d4;
        int i7 = this.n;
        if (i7 > 4) {
            rftbsub(dArr, i4, this.w, i2);
            bitrv2(this.n, dArr);
            cftbsub(dArr);
        } else if (i7 == 4) {
            cftfsub(dArr);
        }
    }

    private void makewt(int i) {
        int[] iArr = this.ip;
        iArr[0] = i;
        iArr[1] = 1;
        if (i > 2) {
            int i2 = i >> 1;
            double d = i2;
            double atan = Math.atan(1.0d) / d;
            double[] dArr = this.w;
            dArr[0] = 1.0d;
            dArr[1] = 0.0d;
            dArr[i2] = Math.cos(d * atan);
            double[] dArr2 = this.w;
            dArr2[i2 + 1] = dArr2[i2];
            if (i2 > 2) {
                for (int i3 = 2; i3 < i2; i3 += 2) {
                    double d2 = i3 * atan;
                    double cos = Math.cos(d2);
                    double sin = Math.sin(d2);
                    double[] dArr3 = this.w;
                    dArr3[i3] = cos;
                    dArr3[i3 + 1] = sin;
                    int i4 = i - i3;
                    dArr3[i4] = sin;
                    dArr3[i4 + 1] = cos;
                }
                bitrv2(i, this.w);
            }
        }
    }

    void makect(int i, double[] dArr, int i2) {
        this.ip[1] = i;
        if (i > 1) {
            int i3 = i >> 1;
            double d = i3;
            double atan = Math.atan(1.0d) / d;
            double cos = Math.cos(d * atan);
            dArr[i2 + 0] = cos;
            dArr[i2 + i3] = cos * 0.5d;
            for (int i4 = 1; i4 < i3; i4++) {
                double d2 = i4 * atan;
                dArr[i2 + i4] = Math.cos(d2) * 0.5d;
                dArr[(i2 + i) - i4] = Math.sin(d2) * 0.5d;
            }
        }
    }

    private void bitrv2(int i, double[] dArr) {
        int i2;
        this.ip[2] = 0;
        int i3 = i;
        int i4 = 1;
        while (true) {
            i2 = i4 << 3;
            if (i2 >= i3) {
                break;
            }
            i3 >>= 1;
            for (int i5 = 0; i5 < i4; i5++) {
                int[] iArr = this.ip;
                iArr[i4 + 2 + i5] = iArr[i5 + 2] + i3;
            }
            i4 <<= 1;
        }
        int i6 = i4 * 2;
        if (i2 == i3) {
            for (int i7 = 0; i7 < i4; i7++) {
                for (int i8 = 0; i8 < i7; i8++) {
                    int[] iArr2 = this.ip;
                    int i9 = (i8 * 2) + iArr2[i7 + 2];
                    int i10 = (i7 * 2) + iArr2[i8 + 2];
                    double d = dArr[i9];
                    int i11 = i9 + 1;
                    double d2 = dArr[i11];
                    double d3 = dArr[i10];
                    int i12 = i10 + 1;
                    double d4 = dArr[i12];
                    dArr[i9] = d3;
                    dArr[i11] = d4;
                    dArr[i10] = d;
                    dArr[i12] = d2;
                    int i13 = i9 + i6;
                    int i14 = i6 * 2;
                    int i15 = i10 + i14;
                    double d5 = dArr[i13];
                    int i16 = i13 + 1;
                    double d6 = dArr[i16];
                    double d7 = dArr[i15];
                    int i17 = i15 + 1;
                    double d8 = dArr[i17];
                    dArr[i13] = d7;
                    dArr[i16] = d8;
                    dArr[i15] = d5;
                    dArr[i17] = d6;
                    int i18 = i13 + i6;
                    int i19 = i15 - i6;
                    double d9 = dArr[i18];
                    int i20 = i18 + 1;
                    double d10 = dArr[i20];
                    double d11 = dArr[i19];
                    int i21 = i19 + 1;
                    double d12 = dArr[i21];
                    dArr[i18] = d11;
                    dArr[i20] = d12;
                    dArr[i19] = d9;
                    dArr[i21] = d10;
                    int i22 = i18 + i6;
                    int i23 = i19 + i14;
                    double d13 = dArr[i22];
                    int i24 = i22 + 1;
                    double d14 = dArr[i24];
                    double d15 = dArr[i23];
                    int i25 = i23 + 1;
                    double d16 = dArr[i25];
                    dArr[i22] = d15;
                    dArr[i24] = d16;
                    dArr[i23] = d13;
                    dArr[i25] = d14;
                }
                int i26 = (i7 * 2) + i6 + this.ip[i7 + 2];
                int i27 = i26 + i6;
                double d17 = dArr[i26];
                int i28 = i26 + 1;
                double d18 = dArr[i28];
                double d19 = dArr[i27];
                int i29 = i27 + 1;
                double d20 = dArr[i29];
                dArr[i26] = d19;
                dArr[i28] = d20;
                dArr[i27] = d17;
                dArr[i29] = d18;
            }
            return;
        }
        for (int i30 = 1; i30 < i4; i30++) {
            for (int i31 = 0; i31 < i30; i31++) {
                int[] iArr3 = this.ip;
                int i32 = (i31 * 2) + iArr3[i30 + 2];
                int i33 = (i30 * 2) + iArr3[i31 + 2];
                double d21 = dArr[i32];
                int i34 = i32 + 1;
                double d22 = dArr[i34];
                double d23 = dArr[i33];
                int i35 = i33 + 1;
                double d24 = dArr[i35];
                dArr[i32] = d23;
                dArr[i34] = d24;
                dArr[i33] = d21;
                dArr[i35] = d22;
                int i36 = i32 + i6;
                int i37 = i33 + i6;
                double d25 = dArr[i36];
                int i38 = i36 + 1;
                double d26 = dArr[i38];
                double d27 = dArr[i37];
                int i39 = i37 + 1;
                double d28 = dArr[i39];
                dArr[i36] = d27;
                dArr[i38] = d28;
                dArr[i37] = d25;
                dArr[i39] = d26;
            }
        }
    }

    private void rftfsub(double[] dArr, int i, double[] dArr2, int i2) {
        int i3 = this.n >> 1;
        int i4 = (i * 2) / i3;
        int i5 = 0;
        for (int i6 = 2; i6 < i3; i6 += 2) {
            int i7 = this.n - i6;
            i5 += i4;
            double d = 0.5d - dArr2[(i2 + i) - i5];
            double d2 = dArr2[i2 + i5];
            double d3 = dArr[i6];
            double d4 = d3 - dArr[i7];
            int i8 = i6 + 1;
            int i9 = i7 + 1;
            double d5 = dArr[i8] + dArr[i9];
            double d6 = (d * d4) - (d2 * d5);
            double d7 = (d * d5) + (d2 * d4);
            dArr[i6] = d3 - d6;
            dArr[i8] = dArr[i8] - d7;
            dArr[i7] = dArr[i7] + d6;
            dArr[i9] = dArr[i9] - d7;
        }
    }

    private void rftbsub(double[] dArr, int i, double[] dArr2, int i2) {
        dArr[1] = -dArr[1];
        int i3 = this.n >> 1;
        int i4 = (i * 2) / i3;
        int i5 = 0;
        for (int i6 = 2; i6 < i3; i6 += 2) {
            int i7 = this.n - i6;
            i5 += i4;
            double d = 0.5d - dArr2[(i2 + i) - i5];
            double d2 = dArr2[i2 + i5];
            double d3 = dArr[i6];
            double d4 = d3 - dArr[i7];
            int i8 = i6 + 1;
            int i9 = i7 + 1;
            double d5 = dArr[i8] + dArr[i9];
            double d6 = (d * d4) + (d2 * d5);
            double d7 = (d * d5) - (d2 * d4);
            dArr[i6] = d3 - d6;
            dArr[i8] = d7 - dArr[i8];
            dArr[i7] = dArr[i7] + d6;
            dArr[i9] = d7 - dArr[i9];
        }
        int i10 = i3 + 1;
        dArr[i10] = -dArr[i10];
    }

    private void cftfsub(double[] dArr) {
        int i = 8;
        if (this.n > 8) {
            cft1st(dArr);
            while (true) {
                int i2 = i << 2;
                if (i2 >= this.n) {
                    break;
                }
                cftmdl(i, dArr);
                i = i2;
            }
        } else {
            i = 2;
        }
        int i3 = 0;
        if ((i << 2) == this.n) {
            while (i3 < i) {
                int i4 = i3 + i;
                int i5 = i4 + i;
                int i6 = i5 + i;
                double d = dArr[i3];
                double d2 = dArr[i4];
                double d3 = d + d2;
                int i7 = i3 + 1;
                double d4 = dArr[i7];
                int i8 = i4 + 1;
                double d5 = dArr[i8];
                double d6 = d4 + d5;
                double d7 = d - d2;
                double d8 = d4 - d5;
                double d9 = dArr[i5];
                double d10 = dArr[i6];
                double d11 = d9 + d10;
                int i9 = i5 + 1;
                double d12 = dArr[i9];
                int i10 = i6 + 1;
                double d13 = dArr[i10];
                double d14 = d12 + d13;
                double d15 = d9 - d10;
                double d16 = d12 - d13;
                dArr[i3] = d3 + d11;
                dArr[i7] = d6 + d14;
                dArr[i5] = d3 - d11;
                dArr[i9] = d6 - d14;
                dArr[i4] = d7 - d16;
                dArr[i8] = d8 + d15;
                dArr[i6] = d7 + d16;
                dArr[i10] = d8 - d15;
                i3 += 2;
            }
            return;
        }
        while (i3 < i) {
            int i11 = i3 + i;
            double d17 = dArr[i3];
            double d18 = dArr[i11];
            int i12 = i3 + 1;
            int i13 = i11 + 1;
            dArr[i3] = d17 + d18;
            dArr[i12] = dArr[i12] + dArr[i13];
            dArr[i11] = d17 - d18;
            dArr[i13] = dArr[i12] - dArr[i13];
            i3 += 2;
        }
    }

    private void cftbsub(double[] dArr) {
        int i = 8;
        if (this.n > 8) {
            cft1st(dArr);
            while (true) {
                int i2 = i << 2;
                if (i2 >= this.n) {
                    break;
                }
                cftmdl(i, dArr);
                i = i2;
            }
        } else {
            i = 2;
        }
        int i3 = 0;
        if ((i << 2) == this.n) {
            while (i3 < i) {
                int i4 = i3 + i;
                int i5 = i4 + i;
                int i6 = i5 + i;
                double d = dArr[i3];
                double d2 = dArr[i4];
                double d3 = d + d2;
                int i7 = i3 + 1;
                double d4 = dArr[i7];
                int i8 = i4 + 1;
                double d5 = dArr[i8];
                double d6 = (-d4) - d5;
                double d7 = d - d2;
                double d8 = (-d4) + d5;
                double d9 = dArr[i5];
                double d10 = dArr[i6];
                double d11 = d9 + d10;
                int i9 = i5 + 1;
                double d12 = dArr[i9];
                int i10 = i6 + 1;
                double d13 = dArr[i10];
                double d14 = d12 + d13;
                double d15 = d9 - d10;
                double d16 = d12 - d13;
                dArr[i3] = d3 + d11;
                dArr[i7] = d6 - d14;
                dArr[i5] = d3 - d11;
                dArr[i9] = d6 + d14;
                dArr[i4] = d7 - d16;
                dArr[i8] = d8 - d15;
                dArr[i6] = d7 + d16;
                dArr[i10] = d8 + d15;
                i3 += 2;
            }
            return;
        }
        while (i3 < i) {
            int i11 = i3 + i;
            double d17 = dArr[i3];
            double d18 = dArr[i11];
            int i12 = i3 + 1;
            int i13 = i11 + 1;
            dArr[i3] = d17 + d18;
            dArr[i12] = (-dArr[i12]) - dArr[i13];
            dArr[i11] = d17 - d18;
            dArr[i13] = (-dArr[i12]) + dArr[i13];
            i3 += 2;
        }
    }

    private void cft1st(double[] dArr) {
        int i = 0;
        double d = dArr[0];
        double d2 = dArr[2];
        double d3 = d + d2;
        double d4 = dArr[1];
        double d5 = dArr[3];
        double d6 = d4 + d5;
        double d7 = d - d2;
        double d8 = d4 - d5;
        double d9 = dArr[4];
        double d10 = dArr[6];
        double d11 = d9 + d10;
        double d12 = dArr[5];
        double d13 = dArr[7];
        double d14 = d12 + d13;
        double d15 = d9 - d10;
        double d16 = d12 - d13;
        dArr[0] = d3 + d11;
        dArr[1] = d6 + d14;
        dArr[4] = d3 - d11;
        dArr[5] = d6 - d14;
        dArr[2] = d7 - d16;
        dArr[3] = d8 + d15;
        dArr[6] = d7 + d16;
        dArr[7] = d8 - d15;
        double d17 = this.w[2];
        double d18 = dArr[8];
        double d19 = dArr[10];
        double d20 = d18 + d19;
        double d21 = dArr[9];
        double d22 = dArr[11];
        double d23 = d21 + d22;
        double d24 = d18 - d19;
        double d25 = d21 - d22;
        double d26 = dArr[12];
        double d27 = dArr[14];
        double d28 = d26 + d27;
        double d29 = dArr[13];
        double d30 = dArr[15];
        double d31 = d29 + d30;
        double d32 = d26 - d27;
        double d33 = d29 - d30;
        dArr[8] = d20 + d28;
        dArr[9] = d23 + d31;
        dArr[12] = d31 - d23;
        dArr[13] = d20 - d28;
        double d34 = d24 - d33;
        double d35 = d25 + d32;
        dArr[10] = (d34 - d35) * d17;
        dArr[11] = (d34 + d35) * d17;
        double d36 = d33 + d24;
        double d37 = d32 - d25;
        dArr[14] = (d37 - d36) * d17;
        dArr[15] = d17 * (d37 + d36);
        for (int i2 = 16; i2 < this.n; i2 += 16) {
            i += 2;
            int i3 = i * 2;
            double[] dArr2 = this.w;
            double d38 = dArr2[i];
            double d39 = dArr2[i + 1];
            double d40 = dArr2[i3];
            double d41 = dArr2[i3 + 1];
            double d42 = d39 * 2.0d;
            double d43 = d40 - (d42 * d41);
            double d44 = (d42 * d40) - d41;
            double d45 = dArr[i2];
            int i4 = i2 + 2;
            double d46 = dArr[i4];
            double d47 = d45 + d46;
            int i5 = i2 + 1;
            double d48 = dArr[i5];
            int i6 = i2 + 3;
            double d49 = dArr[i6];
            double d50 = d48 + d49;
            double d51 = d45 - d46;
            double d52 = d48 - d49;
            int i7 = i2 + 4;
            double d53 = dArr[i7];
            int i8 = i2 + 6;
            double d54 = dArr[i8];
            double d55 = d53 + d54;
            int i9 = i2 + 5;
            double d56 = dArr[i9];
            int i10 = i2 + 7;
            double d57 = dArr[i10];
            double d58 = d56 + d57;
            double d59 = d53 - d54;
            double d60 = d56 - d57;
            dArr[i2] = d47 + d55;
            dArr[i5] = d50 + d58;
            double d61 = d47 - d55;
            double d62 = d50 - d58;
            dArr[i7] = (d38 * d61) - (d39 * d62);
            dArr[i9] = (d62 * d38) + (d61 * d39);
            double d63 = d51 - d60;
            double d64 = d52 + d59;
            dArr[i4] = (d40 * d63) - (d41 * d64);
            dArr[i6] = (d40 * d64) + (d41 * d63);
            double d65 = d51 + d60;
            double d66 = d52 - d59;
            dArr[i8] = (d43 * d65) - (d44 * d66);
            dArr[i10] = (d43 * d66) + (d44 * d65);
            double d67 = dArr2[i3 + 2];
            double d68 = dArr2[i3 + 3];
            double d69 = 2.0d * d38;
            double d70 = d67 - (d69 * d68);
            double d71 = (d69 * d67) - d68;
            int i11 = i2 + 8;
            double d72 = dArr[i11];
            int i12 = i2 + 10;
            double d73 = dArr[i12];
            double d74 = d72 + d73;
            int i13 = i2 + 9;
            double d75 = dArr[i13];
            int i14 = i2 + 11;
            double d76 = dArr[i14];
            double d77 = d75 + d76;
            double d78 = d72 - d73;
            double d79 = d75 - d76;
            int i15 = i2 + 12;
            double d80 = dArr[i15];
            int i16 = i2 + 14;
            double d81 = dArr[i16];
            double d82 = d80 + d81;
            int i17 = i2 + 13;
            double d83 = dArr[i17];
            int i18 = i2 + 15;
            double d84 = dArr[i18];
            double d85 = d83 + d84;
            double d86 = d80 - d81;
            double d87 = d83 - d84;
            dArr[i11] = d74 + d82;
            dArr[i13] = d77 + d85;
            double d88 = d74 - d82;
            double d89 = d77 - d85;
            double d90 = -d39;
            dArr[i15] = (d90 * d88) - (d38 * d89);
            dArr[i17] = (d90 * d89) + (d38 * d88);
            double d91 = d78 - d87;
            double d92 = d79 + d86;
            dArr[i12] = (d67 * d91) - (d68 * d92);
            dArr[i14] = (d67 * d92) + (d68 * d91);
            double d93 = d78 + d87;
            double d94 = d79 - d86;
            dArr[i16] = (d70 * d93) - (d71 * d94);
            dArr[i18] = (d70 * d94) + (d71 * d93);
        }
    }

    private void cftmdl(int i, double[] dArr) {
        FFT4g fFT4g = this;
        int i2 = i << 2;
        int i3 = 0;
        for (int i4 = 0; i4 < i; i4 += 2) {
            int i5 = i4 + i;
            int i6 = i5 + i;
            int i7 = i6 + i;
            double d = dArr[i4];
            double d2 = dArr[i5];
            double d3 = d + d2;
            int i8 = i4 + 1;
            double d4 = dArr[i8];
            int i9 = i5 + 1;
            double d5 = dArr[i9];
            double d6 = d4 + d5;
            double d7 = d - d2;
            double d8 = d4 - d5;
            double d9 = dArr[i6];
            double d10 = dArr[i7];
            double d11 = d9 + d10;
            int i10 = i6 + 1;
            double d12 = dArr[i10];
            int i11 = i7 + 1;
            double d13 = dArr[i11];
            double d14 = d12 + d13;
            double d15 = d9 - d10;
            double d16 = d12 - d13;
            dArr[i4] = d3 + d11;
            dArr[i8] = d6 + d14;
            dArr[i6] = d3 - d11;
            dArr[i10] = d6 - d14;
            dArr[i5] = d7 - d16;
            dArr[i9] = d8 + d15;
            dArr[i7] = d7 + d16;
            dArr[i11] = d8 - d15;
        }
        int i12 = 2;
        double d17 = fFT4g.w[2];
        for (int i13 = i2; i13 < i + i2; i13 += 2) {
            int i14 = i13 + i;
            int i15 = i14 + i;
            int i16 = i15 + i;
            double d18 = dArr[i13];
            double d19 = dArr[i14];
            double d20 = d18 + d19;
            int i17 = i13 + 1;
            double d21 = dArr[i17];
            int i18 = i14 + 1;
            double d22 = dArr[i18];
            double d23 = d21 + d22;
            double d24 = d18 - d19;
            double d25 = d21 - d22;
            double d26 = dArr[i15];
            double d27 = dArr[i16];
            double d28 = d26 + d27;
            int i19 = i15 + 1;
            double d29 = dArr[i19];
            int i20 = i16 + 1;
            double d30 = dArr[i20];
            double d31 = d29 + d30;
            double d32 = d26 - d27;
            double d33 = d29 - d30;
            dArr[i13] = d20 + d28;
            dArr[i17] = d23 + d31;
            dArr[i15] = d31 - d23;
            dArr[i19] = d20 - d28;
            double d34 = d24 - d33;
            double d35 = d25 + d32;
            dArr[i14] = (d34 - d35) * d17;
            dArr[i18] = (d34 + d35) * d17;
            double d36 = d33 + d24;
            double d37 = d32 - d25;
            dArr[i16] = (d37 - d36) * d17;
            dArr[i20] = (d37 + d36) * d17;
        }
        int i21 = i2 * 2;
        int i22 = i21;
        while (i22 < fFT4g.n) {
            i3 += i12;
            int i23 = i3 * 2;
            double[] dArr2 = fFT4g.w;
            double d38 = dArr2[i3];
            double d39 = dArr2[i3 + 1];
            double d40 = dArr2[i23];
            double d41 = dArr2[i23 + 1];
            double d42 = d39 * 2.0d;
            double d43 = d40 - (d42 * d41);
            double d44 = (d42 * d40) - d41;
            for (int i24 = i22; i24 < i + i22; i24 += 2) {
                int i25 = i24 + i;
                int i26 = i25 + i;
                int i27 = i26 + i;
                double d45 = dArr[i24];
                double d46 = dArr[i25];
                double d47 = d45 + d46;
                int i28 = i24 + 1;
                double d48 = dArr[i28];
                int i29 = i25 + 1;
                double d49 = dArr[i29];
                double d50 = d48 + d49;
                double d51 = d45 - d46;
                double d52 = d48 - d49;
                double d53 = dArr[i26];
                double d54 = dArr[i27];
                double d55 = d53 + d54;
                int i30 = i26 + 1;
                double d56 = dArr[i30];
                int i31 = i27 + 1;
                double d57 = dArr[i31];
                double d58 = d56 + d57;
                double d59 = d53 - d54;
                double d60 = d56 - d57;
                dArr[i24] = d47 + d55;
                dArr[i28] = d50 + d58;
                double d61 = d47 - d55;
                double d62 = d50 - d58;
                dArr[i26] = (d38 * d61) - (d39 * d62);
                dArr[i30] = (d62 * d38) + (d61 * d39);
                double d63 = d51 - d60;
                double d64 = d52 + d59;
                dArr[i25] = (d40 * d63) - (d41 * d64);
                dArr[i29] = (d64 * d40) + (d63 * d41);
                double d65 = d51 + d60;
                double d66 = d52 - d59;
                dArr[i27] = (d43 * d65) - (d44 * d66);
                dArr[i31] = (d66 * d43) + (d65 * d44);
            }
            double[] dArr3 = fFT4g.w;
            double d67 = dArr3[i23 + 2];
            double d68 = dArr3[i23 + 3];
            double d69 = 2.0d * d38;
            double d70 = d67 - (d69 * d68);
            double d71 = (d69 * d67) - d68;
            int i32 = i22 + i2;
            i2 = i2;
            for (int i33 = i32; i33 < i + i32; i33 += 2) {
                int i34 = i33 + i;
                int i35 = i34 + i;
                int i36 = i35 + i;
                double d72 = dArr[i33];
                double d73 = dArr[i34];
                double d74 = d72 + d73;
                int i37 = i33 + 1;
                double d75 = dArr[i37];
                int i38 = i34 + 1;
                double d76 = dArr[i38];
                double d77 = d75 + d76;
                double d78 = d72 - d73;
                double d79 = d75 - d76;
                double d80 = dArr[i35];
                double d81 = dArr[i36];
                double d82 = d80 + d81;
                int i39 = i35 + 1;
                double d83 = dArr[i39];
                int i40 = i36 + 1;
                double d84 = dArr[i40];
                double d85 = d83 + d84;
                double d86 = d80 - d81;
                double d87 = d83 - d84;
                dArr[i33] = d74 + d82;
                dArr[i37] = d77 + d85;
                double d88 = d74 - d82;
                double d89 = d77 - d85;
                i3 = i3;
                i21 = i21;
                double d90 = -d39;
                dArr[i35] = (d90 * d88) - (d38 * d89);
                dArr[i39] = (d90 * d89) + (d88 * d38);
                double d91 = d78 - d87;
                double d92 = d79 + d86;
                dArr[i34] = (d67 * d91) - (d68 * d92);
                dArr[i38] = (d92 * d67) + (d91 * d68);
                double d93 = d78 + d87;
                double d94 = d79 - d86;
                dArr[i36] = (d70 * d93) - (d71 * d94);
                dArr[i40] = (d94 * d70) + (d93 * d71);
            }
            i22 += i21;
            fFT4g = this;
            i12 = 2;
        }
    }
}
