package crystalminer.server;

import crystalminer.content.Content;
import crystalminer.symmetry.SymOp;
import crystalminer.symmetry.SymmetryRegion;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import net.minestom.server.coordinate.Vec;

/** A region in the running world: its content, its current symmetry, and how to draw its elements. */
public final class LiveRegion {
    /** A point to draw, with a colour that says which kind of element it belongs to. */
    public record Dot(Vec pos, int rgb) {}

    public static final int AXIS_2 = 0xFFD700;   // yellow
    public static final int AXIS_3 = 0x32CD32;   // green
    public static final int AXIS_4 = 0xFF3030;   // red
    public static final int ROTOINVERSION = 0xB040FF; // purple
    public static final int MIRROR = 0x40C0FF;   // light blue
    public static final int INVERSION = 0xFFFFFF; // white
    public static final int LATTICE = 0xE0E0E0; // light grey

    private final Content.Area area;
    private volatile SymmetryRegion region;
    private volatile String symbol;
    private volatile List<Dot> dots;

    public LiveRegion(Content.Area area) {
        this.area = area;
        setSymmetry(area.symbol(), area.generators());
    }

    public Content.Area area() {
        return area;
    }

    public SymmetryRegion region() {
        return region;
    }

    /** Symbol shown to players ("?" for the Mystery Lab). */
    public String symbol() {
        return symbol;
    }

    public List<Dot> dots() {
        return dots;
    }

    /** Replaces the region's symmetry (used by the Free Lab). */
    public void setSymmetry(String newSymbol, List<String> crystalGenerators) {
        SymmetryRegion r = area.buildRegion(crystalGenerators);
        this.region = r;
        this.symbol = newSymbol;
        this.dots = area.hidden() != null ? List.of() : computeDots(r);
    }

    public boolean contains(int x, int y, int z) {
        return region.contains(x, y, z);
    }

    /** True if the point is inside the region's box, grown by {@code margin} blocks. */
    public boolean near(double x, double y, double z, double margin) {
        int[] min = region.min(), size = region.size();
        return x >= min[0] - margin && x <= min[0] + size[0] + margin
                && y >= min[1] - margin - 2 && y <= min[1] + size[1] + margin
                && z >= min[2] - margin && z <= min[2] + size[2] + margin;
    }

    public Vec centre() {
        int[] min = region.min(), size = region.size();
        return new Vec(min[0] + size[0] / 2.0, min[1] + size[1] / 2.0, min[2] + size[2] / 2.0);
    }

    // ---------------------------------------------------------------- symmetry elements

    private static List<Dot> computeDots(SymmetryRegion r) {
        if (r.isPeriodic()) return latticeDots(r);
        double[] lo = {r.min()[0], r.min()[1], r.min()[2]};
        double[] hi = {lo[0] + r.size()[0], lo[1] + r.size()[1], lo[2] + r.size()[2]};
        int[] od = r.originDoubled();
        double[] o = {od[0] / 2.0, od[1] / 2.0, od[2] / 2.0};

        Map<List<Integer>, Integer> properAxes = new HashMap<>(); // direction -> highest fold
        Map<List<Integer>, Boolean> rotoinversionAxes = new HashMap<>();
        List<int[]> mirrorNormals = new ArrayList<>();
        boolean inversion = false;
        for (SymOp op : r.group().ops()) {
            String k = op.kind();
            switch (k) {
                case "2", "3", "4", "6" -> {
                    int[] v = fixedDirection(op, 1);
                    if (v != null) properAxes.merge(key(v), Integer.parseInt(k), Math::max);
                }
                case "-3", "-4", "-6" -> {
                    int[] v = fixedDirection(op, -1);
                    if (v != null) rotoinversionAxes.put(key(v), true);
                }
                case "m" -> {
                    int[] n = fixedDirection(op, -1);
                    if (n != null && mirrorNormals.stream().noneMatch(m -> key(m).equals(key(n)))) mirrorNormals.add(n);
                }
                case "-1" -> inversion = true;
                default -> {}
            }
        }

        List<Dot> dots = new ArrayList<>();
        properAxes.forEach((dir, fold) -> line(dots, o, dir, lo, hi,
                fold == 4 ? AXIS_4 : fold == 3 ? AXIS_3 : AXIS_2));
        rotoinversionAxes.keySet().stream()
                .filter(dir -> !properAxes.containsKey(dir) || properAxes.get(dir) == 2)
                .forEach(dir -> line(dots, o, dir, lo, hi, ROTOINVERSION));
        for (int[] n : mirrorNormals) planeOutline(dots, o, n, lo, hi);
        if (inversion) {
            for (int i = 0; i < 6; i++) dots.add(new Dot(new Vec(o[0], o[1], o[2]), INVERSION));
        }
        return List.copyOf(dots);
    }

    /** A small integer direction v with W·v = sign·v, or null. */
    private static int[] fixedDirection(SymOp op, int sign) {
        for (int a = -1; a <= 1; a++) {
            for (int b = -1; b <= 1; b++) {
                for (int c = -1; c <= 1; c++) {
                    if (a == 0 && b == 0 && c == 0) continue;
                    int[] v = {a, b, c};
                    int[] w = op.applyLinear(v);
                    if (w[0] == sign * a && w[1] == sign * b && w[2] == sign * c) return v;
                }
            }
        }
        return null;
    }

    /** Direction key with v and -v treated as the same line. */
    private static List<Integer> key(int[] v) {
        int s = 1;
        for (int x : v) {
            if (x != 0) {
                s = x > 0 ? 1 : -1;
                break;
            }
        }
        return List.of(s * v[0], s * v[1], s * v[2]);
    }

    private static void line(List<Dot> dots, double[] o, List<Integer> dir, double[] lo, double[] hi, int rgb) {
        double len = Math.sqrt(dir.get(0) * dir.get(0) + dir.get(1) * dir.get(1) + dir.get(2) * dir.get(2));
        for (double t = -30; t <= 30; t += 0.75) {
            double x = o[0] + t * dir.get(0) / len, y = o[1] + t * dir.get(1) / len, z = o[2] + t * dir.get(2) / len;
            if (x >= lo[0] && x <= hi[0] && y >= lo[1] && y <= hi[1] && z >= lo[2] && z <= hi[2]) {
                dots.add(new Dot(new Vec(x, y, z), rgb));
            }
        }
    }

    /** Where the mirror plane cuts the faces of the box: its outline. */
    private static void planeOutline(List<Dot> dots, double[] o, int[] n, double[] lo, double[] hi) {
        double step = 0.5;
        for (double x = lo[0]; x <= hi[0]; x += step) {
            for (double y = lo[1]; y <= hi[1]; y += step) {
                for (double z = lo[2]; z <= hi[2]; z += step) {
                    boolean onFace = x == lo[0] || x == hi[0] || y == lo[1] || y == hi[1] || z == lo[2] || z == hi[2];
                    if (!onFace) continue;
                    double d = n[0] * (x - o[0]) + n[1] * (y - o[1]) + n[2] * (z - o[2]);
                    if (Math.abs(d) < 1e-9) dots.add(new Dot(new Vec(x, y, z), MIRROR));
                }
            }
        }
    }

    private static List<Dot> latticeDots(SymmetryRegion r) {
        List<Dot> dots = new ArrayList<>();
        int[] min = r.min(), size = r.size(), cell = r.cell();
        for (int axis = 0; axis < 3; axis++) {
            int a1 = (axis + 1) % 3, a2 = (axis + 2) % 3;
            for (int i = 0; i <= size[a1]; i += cell[a1]) {
                for (int j = 0; j <= size[a2]; j += cell[a2]) {
                    for (double t = 0; t <= size[axis]; t += 1) {
                        double[] p = new double[3];
                        p[axis] = min[axis] + t;
                        p[a1] = min[a1] + i;
                        p[a2] = min[a2] + j;
                        dots.add(new Dot(new Vec(p[0], p[1], p[2]), LATTICE));
                    }
                }
            }
        }
        return List.copyOf(dots);
    }
}
