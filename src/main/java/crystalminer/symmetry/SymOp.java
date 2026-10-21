package crystalminer.symmetry;

import java.util.Arrays;

/**
 * An affine symmetry operation r' = W·r + t on integer coordinates.
 *
 * <p>Coordinates are "doubled": a block at integer position x has its centre at 2x+1, so mirror
 * planes and rotation axes can pass either through block centres (odd values) or between blocks
 * (even values) while every operation stays integer-valued.
 *
 * <p>W is stored row-major. For operations that map a cubic block grid onto itself, W is a signed
 * permutation matrix (one ±1 per row and column).
 */
public final class SymOp {
    public static final SymOp IDENTITY = new SymOp(new int[] {1, 0, 0, 0, 1, 0, 0, 0, 1}, new int[3]);

    private final int[] w; // 3x3, row-major
    private final int[] t; // translation

    public SymOp(int[] w, int[] t) {
        if (w.length != 9 || t.length != 3) throw new IllegalArgumentException("W must be 3x3 and t length 3");
        this.w = w.clone();
        this.t = t.clone();
    }

    /**
     * Parses Jones faithful notation, e.g. "-y,x,z" or "-x,-y,z+1/2".
     *
     * <p>Fractional translations are multiples of the given cell lengths (in doubled units). For
     * point operations pass {@code null}; any translation term is then rejected.
     */
    public static SymOp parse(String jones, int[] cellDoubled) {
        String[] parts = jones.replace(" ", "").toLowerCase().split(",");
        if (parts.length != 3) throw new IllegalArgumentException("Expected 3 components: " + jones);
        int[] w = new int[9];
        int[] t = new int[3];
        for (int row = 0; row < 3; row++) {
            String s = parts[row];
            int i = 0;
            while (i < s.length()) {
                int sign = 1;
                if (s.charAt(i) == '+' || s.charAt(i) == '-') {
                    sign = s.charAt(i) == '-' ? -1 : 1;
                    i++;
                }
                if (i >= s.length()) throw new IllegalArgumentException("Dangling sign in " + jones);
                char c = s.charAt(i);
                if (c == 'x' || c == 'y' || c == 'z') {
                    w[row * 3 + (c - 'x')] += sign;
                    i++;
                } else if (Character.isDigit(c)) {
                    int j = i;
                    while (j < s.length() && (Character.isDigit(s.charAt(j)) || s.charAt(j) == '/')) j++;
                    String frac = s.substring(i, j);
                    if (cellDoubled == null) {
                        throw new IllegalArgumentException("Translation not allowed in a point operation: " + jones);
                    }
                    String[] nd = frac.split("/");
                    int num = Integer.parseInt(nd[0]);
                    int den = nd.length > 1 ? Integer.parseInt(nd[1]) : 1;
                    int scaled = num * cellDoubled[row];
                    if (scaled % den != 0) {
                        throw new IllegalArgumentException(
                                "Translation " + frac + " of a cell of " + cellDoubled[row] / 2
                                        + " blocks does not land on a whole number of half-blocks");
                    }
                    t[row] += sign * scaled / den;
                    i = j;
                } else {
                    throw new IllegalArgumentException("Unexpected '" + c + "' in " + jones);
                }
            }
        }
        return new SymOp(w, t);
    }

    public static SymOp parse(String jones) {
        return parse(jones, null);
    }

    public int w(int row, int col) {
        return w[row * 3 + col];
    }

    public int t(int i) {
        return t[i];
    }

    public int[] apply(int[] r) {
        int[] out = new int[3];
        for (int i = 0; i < 3; i++) {
            out[i] = w[i * 3] * r[0] + w[i * 3 + 1] * r[1] + w[i * 3 + 2] * r[2] + t[i];
        }
        return out;
    }

    /** Applies only the linear part W (for directions such as a block's facing). */
    public int[] applyLinear(int[] v) {
        int[] out = new int[3];
        for (int i = 0; i < 3; i++) {
            out[i] = w[i * 3] * v[0] + w[i * 3 + 1] * v[1] + w[i * 3 + 2] * v[2];
        }
        return out;
    }

    /** Returns this ∘ other: first apply {@code other}, then this. */
    public SymOp compose(SymOp other) {
        int[] nw = new int[9];
        for (int i = 0; i < 3; i++) {
            for (int j = 0; j < 3; j++) {
                int s = 0;
                for (int k = 0; k < 3; k++) s += w[i * 3 + k] * other.w[k * 3 + j];
                nw[i * 3 + j] = s;
            }
        }
        int[] nt = applyLinear(other.t);
        for (int i = 0; i < 3; i++) nt[i] += t[i];
        return new SymOp(nw, nt);
    }

    /** Reduces the translation modulo the given periods (in doubled units). */
    public SymOp modulo(int[] periods) {
        int[] nt = new int[3];
        for (int i = 0; i < 3; i++) nt[i] = Math.floorMod(t[i], periods[i]);
        return new SymOp(w, nt);
    }

    /** Conjugates by a change of basis P (a signed permutation): returns P·this·P⁻¹. */
    public SymOp conjugate(SymOp p) {
        return p.compose(this).compose(p.inverseLinear());
    }

    /** Inverse of a signed permutation (its transpose); translation must be zero. */
    public SymOp inverseLinear() {
        if (!isPoint()) throw new IllegalStateException("inverseLinear requires a point operation");
        int[] nw = new int[9];
        for (int i = 0; i < 3; i++) for (int j = 0; j < 3; j++) nw[i * 3 + j] = w[j * 3 + i];
        return new SymOp(nw, new int[3]);
    }

    public boolean isPoint() {
        return t[0] == 0 && t[1] == 0 && t[2] == 0;
    }

    public SymOp linearPart() {
        return new SymOp(w, new int[3]);
    }

    public int det() {
        return w[0] * (w[4] * w[8] - w[5] * w[7])
                - w[1] * (w[3] * w[8] - w[5] * w[6])
                + w[2] * (w[3] * w[7] - w[4] * w[6]);
    }

    public int trace() {
        return w[0] + w[4] + w[8];
    }

    /** True if every row and column of W has exactly one entry ±1 and the rest 0. */
    public boolean isSignedPermutation() {
        for (int i = 0; i < 3; i++) {
            int rowNonZero = 0, colNonZero = 0;
            for (int j = 0; j < 3; j++) {
                int r = w[i * 3 + j], c = w[j * 3 + i];
                if (r != 0) {
                    if (Math.abs(r) != 1) return false;
                    rowNonZero++;
                }
                if (c != 0) colNonZero++;
            }
            if (rowNonZero != 1 || colNonZero != 1) return false;
        }
        return true;
    }

    /** The order of the linear part W (smallest n ≥ 1 with Wⁿ = I), or -1 if it exceeds 12. */
    public int linearOrder() {
        SymOp lin = linearPart();
        SymOp p = lin;
        for (int n = 1; n <= 12; n++) {
            if (p.equals(IDENTITY)) return n;
            p = p.compose(lin);
        }
        return -1;
    }

    /**
     * The crystallographic name of the linear part, from its determinant and trace:
     * 1, 2, 3, 4, 6 for rotations and -1, m, -3, -4, -6 for rotoinversions.
     */
    public String kind() {
        int d = det(), tr = trace();
        if (d == 1) {
            return switch (tr) {
                case 3 -> "1";
                case -1 -> "2";
                case 0 -> "3";
                case 1 -> "4";
                case 2 -> "6";
                default -> "?";
            };
        } else if (d == -1) {
            return switch (tr) {
                case -3 -> "-1";
                case 1 -> "m";
                case 0 -> "-3";
                case -1 -> "-4";
                case -2 -> "-6";
                default -> "?";
            };
        }
        return "?";
    }

    /** Jones-notation form of the linear part plus raw doubled translation. */
    @Override
    public String toString() {
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < 3; i++) {
            if (i > 0) sb.append(',');
            boolean first = true;
            for (int j = 0; j < 3; j++) {
                int c = w[i * 3 + j];
                if (c == 0) continue;
                if (c < 0) sb.append('-');
                else if (!first) sb.append('+');
                if (Math.abs(c) != 1) sb.append(Math.abs(c));
                sb.append((char) ('x' + j));
                first = false;
            }
            if (t[i] != 0) sb.append(t[i] > 0 ? "+" : "").append(t[i]).append("/2");
        }
        return sb.toString();
    }

    @Override
    public boolean equals(Object o) {
        return o instanceof SymOp s && Arrays.equals(w, s.w) && Arrays.equals(t, s.t);
    }

    @Override
    public int hashCode() {
        return 31 * Arrays.hashCode(w) + Arrays.hashCode(t);
    }
}
