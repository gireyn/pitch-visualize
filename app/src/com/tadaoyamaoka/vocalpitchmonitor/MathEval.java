package com.tadaoyamaoka.vocalpitchmonitor;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;

/**
 * A small arithmetic expression evaluator that mirrors the JavaScript
 * {@code eval(...)} semantics used by musescore-xen-tuner's tuning-config
 * parser for cents/ratio values.
 *
 * Supported syntax:
 *  - numbers (integer, decimal, exponent), parentheses, unary minus
 *  - + - * / with JS precedence
 *  - exponentiation: Math.pow(a,b) and also ** / ^ (convenience)
 *  - Math.* / MATH.* function calls: pow, log, log2, log10, exp, sqrt, cbrt,
 *    abs, floor, ceil, round, trunc, sign, min, max, sin, cos, tan, asin,
 *    acos, atan, atan2, sinh, cosh, tanh, hypot
 *  - Math.* constants: PI, E, LN2, LN10, LOG2E, LOG10E, SQRT2, SQRT1_2
 *    (bare PI / E also accepted as a convenience)
 */
public class MathEval {

    public static final double NaN = Double.NaN;

    private interface Fn {
        double apply(double[] args);
    }

    private static final Map<String, Fn> FUNCS = new HashMap<String, Fn>();
    private static final Map<String, Double> CONSTS = new HashMap<String, Double>();

    static {
        FUNCS.put("pow", new Fn() { public double apply(double[] a) { return Math.pow(a[0], a[1]); } });
        FUNCS.put("log", new Fn() { public double apply(double[] a) { return Math.log(a[0]); } });
        FUNCS.put("log2", new Fn() { public double apply(double[] a) { return Math.log(a[0]) / Math.log(2.0); } });
        FUNCS.put("log10", new Fn() { public double apply(double[] a) { return Math.log10(a[0]); } });
        FUNCS.put("ln", new Fn() { public double apply(double[] a) { return Math.log(a[0]); } });
        FUNCS.put("exp", new Fn() { public double apply(double[] a) { return Math.exp(a[0]); } });
        FUNCS.put("sqrt", new Fn() { public double apply(double[] a) { return Math.sqrt(a[0]); } });
        FUNCS.put("cbrt", new Fn() { public double apply(double[] a) { return Math.cbrt(a[0]); } });
        FUNCS.put("abs", new Fn() { public double apply(double[] a) { return Math.abs(a[0]); } });
        FUNCS.put("floor", new Fn() { public double apply(double[] a) { return Math.floor(a[0]); } });
        FUNCS.put("ceil", new Fn() { public double apply(double[] a) { return Math.ceil(a[0]); } });
        FUNCS.put("round", new Fn() { public double apply(double[] a) { return Math.round(a[0]); } });
        FUNCS.put("trunc", new Fn() { public double apply(double[] a) { return a[0] < 0 ? Math.ceil(a[0]) : Math.floor(a[0]); } });
        FUNCS.put("sign", new Fn() { public double apply(double[] a) { return Math.signum(a[0]); } });
        FUNCS.put("min", new Fn() { public double apply(double[] a) { return Math.min(a[0], a[1]); } });
        FUNCS.put("max", new Fn() { public double apply(double[] a) { return Math.max(a[0], a[1]); } });
        FUNCS.put("sin", new Fn() { public double apply(double[] a) { return Math.sin(a[0]); } });
        FUNCS.put("cos", new Fn() { public double apply(double[] a) { return Math.cos(a[0]); } });
        FUNCS.put("tan", new Fn() { public double apply(double[] a) { return Math.tan(a[0]); } });
        FUNCS.put("asin", new Fn() { public double apply(double[] a) { return Math.asin(a[0]); } });
        FUNCS.put("acos", new Fn() { public double apply(double[] a) { return Math.acos(a[0]); } });
        FUNCS.put("atan", new Fn() { public double apply(double[] a) { return Math.atan(a[0]); } });
        FUNCS.put("atan2", new Fn() { public double apply(double[] a) { return Math.atan2(a[0], a[1]); } });
        FUNCS.put("sinh", new Fn() { public double apply(double[] a) { return Math.sinh(a[0]); } });
        FUNCS.put("cosh", new Fn() { public double apply(double[] a) { return Math.cosh(a[0]); } });
        FUNCS.put("tanh", new Fn() { public double apply(double[] a) { return Math.tanh(a[0]); } });
        FUNCS.put("hypot", new Fn() { public double apply(double[] a) { return Math.hypot(a[0], a[1]); } });

        CONSTS.put("PI", Math.PI);
        CONSTS.put("E", Math.E);
        CONSTS.put("LN2", Math.log(2.0));
        CONSTS.put("LN10", Math.log(10.0));
        CONSTS.put("LOG2E", 1.0 / Math.log(2.0));
        CONSTS.put("LOG10E", 1.0 / Math.log(10.0));
        CONSTS.put("SQRT2", Math.sqrt(2.0));
        CONSTS.put("SQRT1_2", 1.0 / Math.sqrt(2.0));
    }

    private String src;
    private int pos;

    private MathEval(String src) {
        this.src = src;
        this.pos = 0;
    }

    /**
     * Evaluate a JS-like arithmetic expression.
     * @return the numeric result, or NaN if the expression is invalid.
     */
    public static double eval(String expression) {
        if (expression == null) {
            return NaN;
        }
        String s = expression.trim();
        if (s.length() == 0) {
            return NaN;
        }
        try {
            MathEval p = new MathEval(s);
            double v = p.parseExpression();
            p.skipWs();
            if (p.pos < p.src.length()) {
                return NaN; // trailing garbage
            }
            return v;
        } catch (Exception e) {
            return NaN;
        }
    }

    private void skipWs() {
        while (pos < src.length()) {
            char c = src.charAt(pos);
            if (c == ' ' || c == '\t' || c == '\n' || c == '\r') {
                pos++;
            } else {
                break;
            }
        }
    }

    private double parseExpression() {
        double v = parseTerm();
        while (true) {
            skipWs();
            if (pos >= src.length()) {
                return v;
            }
            char c = src.charAt(pos);
            if (c == '+') {
                pos++;
                v = v + parseTerm();
            } else if (c == '-') {
                pos++;
                v = v - parseTerm();
            } else {
                return v;
            }
        }
    }

    private double parseTerm() {
        double v = parsePower();
        while (true) {
            skipWs();
            if (pos >= src.length()) {
                return v;
            }
            char c = src.charAt(pos);
            if (c == '*') {
                pos++;
                v = v * parsePower();
            } else if (c == '/') {
                pos++;
                v = v / parsePower();
            } else {
                return v;
            }
        }
    }

    /** power: unary ('**'|'^') power  (right associative) */
    private double parsePower() {
        double base = parseUnary();
        skipWs();
        if (pos < src.length()) {
            char c = src.charAt(pos);
            boolean isPow = false;
            if (c == '^') {
                isPow = true;
                pos++;
            } else if (c == '*') {
                if (pos + 1 < src.length() && src.charAt(pos + 1) == '*') {
                    isPow = true;
                    pos += 2;
                }
            }
            if (isPow) {
                double exp = parsePower();
                return Math.pow(base, exp);
            }
        }
        return base;
    }

    private double parseUnary() {
        skipWs();
        if (pos < src.length() && (src.charAt(pos) == '-' || src.charAt(pos) == '+')) {
            char c = src.charAt(pos);
            pos++;
            double v = parseUnary();
            return c == '-' ? -v : v;
        }
        return parsePrimary();
    }

    private double parsePrimary() {
        skipWs();
        if (pos >= src.length()) {
            return NaN;
        }
        char c = src.charAt(pos);
        if (c == '(') {
            pos++;
            double v = parseExpression();
            skipWs();
            if (pos < src.length() && src.charAt(pos) == ')') {
                pos++;
            } else {
                return NaN;
            }
            return v;
        }
        if (Character.isDigit(c) || c == '.') {
            return parseNumber();
        }
        if (Character.isLetter(c) || c == '_') {
            return parseIdent();
        }
        return NaN;
    }

    private double parseNumber() {
        int start = pos;
        boolean any = false;
        boolean exponent = false;
        boolean hasExpDigits = false;
        while (pos < src.length()) {
            char c = src.charAt(pos);
            if (Character.isDigit(c)) {
                any = true;
                if (exponent) {
                    hasExpDigits = true;
                }
                pos++;
            } else if (c == '.') {
                if (exponent) {
                    break;
                }
                any = true;
                pos++;
            } else if (c == 'e' || c == 'E') {
                if (exponent) {
                    break;
                }
                exponent = true;
                pos++;
                if (pos < src.length() && (src.charAt(pos) == '+' || src.charAt(pos) == '-')) {
                    pos++;
                }
            } else {
                break;
            }
        }
        if (!any) {
            return NaN;
        }
        String num = src.substring(start, pos);
        try {
            return Double.parseDouble(num);
        } catch (NumberFormatException e) {
            return NaN;
        }
    }

    private double parseIdent() {
        int start = pos;
        // consume a (possibly dotted) identifier: Math.pow, Math.LN2, log2, ...
        while (pos < src.length()) {
            char c = src.charAt(pos);
            if (Character.isLetterOrDigit(c) || c == '_' || c == '.') {
                pos++;
            } else {
                break;
            }
        }
        String ident = src.substring(start, pos);
        skipWs();
        if (pos < src.length() && src.charAt(pos) == '(') {
            // function call, possibly Math.func / MATH.func
            String fnName = ident;
            if (ident.indexOf('.') >= 0) {
                int dot = ident.lastIndexOf('.');
                fnName = ident.substring(dot + 1);
            }
            pos++; // consume '('
            List<Double> args = new ArrayList<Double>();
            skipWs();
            if (pos < src.length() && src.charAt(pos) == ')') {
                pos++;
            } else {
                while (true) {
                    double a = parseExpression();
                    if (Double.isNaN(a)) {
                        return NaN;
                    }
                    args.add(Double.valueOf(a));
                    skipWs();
                    if (pos < src.length() && src.charAt(pos) == ',') {
                        pos++;
                    } else {
                        break;
                    }
                }
                skipWs();
                if (pos < src.length() && src.charAt(pos) == ')') {
                    pos++;
                } else {
                    return NaN;
                }
            }
            Fn fn = FUNCS.get(fnName.toLowerCase(Locale.US));
            if (fn == null) {
                return NaN;
            }
            double[] arr = new double[args.size()];
            for (int i = 0; i < arr.length; i++) {
                arr[i] = args.get(i).doubleValue();
            }
            try {
                return fn.apply(arr);
            } catch (Exception e) {
                return NaN;
            }
        }
        // constant
        String constName = ident;
        if (ident.indexOf('.') >= 0) {
            int dot = ident.lastIndexOf('.');
            constName = ident.substring(dot + 1);
        }
        Double cv = CONSTS.get(constName.toUpperCase(Locale.US));
        if (cv != null) {
            return cv.doubleValue();
        }
        return NaN;
    }
}
