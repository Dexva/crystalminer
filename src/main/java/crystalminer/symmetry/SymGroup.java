package crystalminer.symmetry;

import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Deque;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.TreeMap;

/**
 * A finite group of symmetry operations, built by multiplying generators until the set closes.
 *
 * <p>For a point group the translations are all zero. For a space-group-like region, translations
 * are reduced modulo the cell (given in doubled units) so the group stays finite: it is the group
 * of operations "modulo lattice translations".
 */
public final class SymGroup {
    /** Safety cap; the largest crystallographic point group (m-3m) has order 48. */
    public static final int MAX_ORDER = 192;

    private final List<SymOp> ops;
    private final int[] periods; // null for a point group

    private SymGroup(List<SymOp> ops, int[] periods) {
        this.ops = List.copyOf(ops);
        this.periods = periods == null ? null : periods.clone();
    }

    public static SymGroup pointGroup(List<SymOp> generators) {
        for (SymOp g : generators) {
            if (!g.isPoint()) throw new IllegalArgumentException("Point-group generator has a translation: " + g);
        }
        return close(generators, null);
    }

    public static SymGroup periodic(List<SymOp> generators, int[] cellDoubled) {
        return close(generators, cellDoubled);
    }

    private static SymGroup close(List<SymOp> generators, int[] periods) {
        Set<SymOp> elements = new LinkedHashSet<>();
        Deque<SymOp> queue = new ArrayDeque<>();
        elements.add(SymOp.IDENTITY);
        queue.add(SymOp.IDENTITY);
        while (!queue.isEmpty()) {
            SymOp a = queue.poll();
            for (SymOp g : generators) {
                SymOp p = g.compose(a);
                if (periods != null) p = p.modulo(periods);
                if (elements.add(p)) {
                    if (elements.size() > MAX_ORDER) {
                        throw new IllegalArgumentException("Generators do not close into a finite group (order > "
                                + MAX_ORDER + ")");
                    }
                    queue.add(p);
                }
            }
        }
        return new SymGroup(new ArrayList<>(elements), periods);
    }

    public List<SymOp> ops() {
        return ops;
    }

    public int order() {
        return ops.size();
    }

    public boolean isPeriodic() {
        return periods != null;
    }

    public boolean contains(SymOp op) {
        return ops.contains(periods == null ? op : op.modulo(periods));
    }

    /** True if every operation maps the cubic grid onto itself (signed-permutation W). */
    public boolean fitsCubicGrid() {
        return ops.stream().allMatch(SymOp::isSignedPermutation);
    }

    /**
     * How many operations of each kind (1, 2, 3, 4, 6, -1, m, -3, -4, -6) the group has. Determinant
     * and trace are unchanged by a change of basis, so this signature does not depend on how the group
     * is oriented. {@code PointGroupsTest} checks that it tells all 32 crystallographic point groups
     * apart.
     */
    public Map<String, Integer> signature() {
        Map<String, Integer> sig = new TreeMap<>();
        for (SymOp op : ops) sig.merge(op.kind(), 1, Integer::sum);
        return Collections.unmodifiableMap(sig);
    }

    /** Point group of the linear parts (for a periodic group: its crystal class). */
    public SymGroup linearParts() {
        Set<SymOp> lin = new LinkedHashSet<>();
        for (SymOp op : ops) lin.add(op.linearPart());
        return new SymGroup(new ArrayList<>(lin), null);
    }
}
