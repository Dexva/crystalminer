package crystalminer.symmetry;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

/**
 * Finds the exact point symmetry of a build: every one of the 48 cubic-grid operations (about the
 * centre of the build's bounding box) that maps each block onto a block of the same type.
 *
 * <p>The bounding-box centre is the only candidate centre: any grid symmetry of the build maps its
 * bounding box onto itself, so it fixes the box centre.
 */
public final class SymmetryDetector {
    public record Result(SymGroup group, Optional<PointGroups.Entry> pointGroup, int[] centreDoubled) {}

    private static final List<SymOp> CUBIC_OPS = PointGroups.bySymbol("m-3m").orElseThrow().group().ops();

    private SymmetryDetector() {}

    /**
     * @param blocks block positions (doubled coordinates, i.e. 2x+1) mapped to a block-type key
     */
    public static Result detect(Map<List<Integer>, String> blocks) {
        if (blocks.isEmpty()) throw new IllegalArgumentException("Nothing to analyse");
        int[] min = {Integer.MAX_VALUE, Integer.MAX_VALUE, Integer.MAX_VALUE};
        int[] max = {Integer.MIN_VALUE, Integer.MIN_VALUE, Integer.MIN_VALUE};
        for (List<Integer> p : blocks.keySet()) {
            for (int i = 0; i < 3; i++) {
                min[i] = Math.min(min[i], p.get(i));
                max[i] = Math.max(max[i], p.get(i));
            }
        }
        // Block centres are odd in doubled coordinates, so min+max is even and the centre is an integer.
        int[] centre = new int[3];
        for (int i = 0; i < 3; i++) centre[i] = (min[i] + max[i]) / 2;

        Map<List<Integer>, String> relative = new HashMap<>();
        blocks.forEach((p, type) -> relative.put(
                List.of(p.get(0) - centre[0], p.get(1) - centre[1], p.get(2) - centre[2]), type));

        List<SymOp> found = new ArrayList<>();
        for (SymOp op : CUBIC_OPS) {
            boolean ok = true;
            for (Map.Entry<List<Integer>, String> e : relative.entrySet()) {
                int[] r = op.apply(new int[] {e.getKey().get(0), e.getKey().get(1), e.getKey().get(2)});
                if (!e.getValue().equals(relative.get(List.of(r[0], r[1], r[2])))) {
                    ok = false;
                    break;
                }
            }
            if (ok) found.add(op);
        }
        SymGroup group = SymGroup.pointGroup(found);
        return new Result(group, PointGroups.identify(group), centre);
    }
}
