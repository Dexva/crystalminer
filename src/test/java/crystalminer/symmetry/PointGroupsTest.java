package crystalminer.symmetry;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import org.junit.jupiter.api.Test;

class PointGroupsTest {
    /** Orders of the 32 crystallographic point groups (International Tables for Crystallography, Vol. A). */
    private static final Map<String, Integer> ORDERS = Map.ofEntries(
            Map.entry("1", 1), Map.entry("-1", 2),
            Map.entry("2", 2), Map.entry("m", 2), Map.entry("2/m", 4),
            Map.entry("222", 4), Map.entry("mm2", 4), Map.entry("mmm", 8),
            Map.entry("4", 4), Map.entry("-4", 4), Map.entry("4/m", 8), Map.entry("422", 8),
            Map.entry("4mm", 8), Map.entry("-42m", 8), Map.entry("4/mmm", 16),
            Map.entry("3", 3), Map.entry("-3", 6), Map.entry("32", 6), Map.entry("3m", 6), Map.entry("-3m", 12),
            Map.entry("6", 6), Map.entry("-6", 6), Map.entry("6/m", 12), Map.entry("622", 12),
            Map.entry("6mm", 12), Map.entry("-62m", 12), Map.entry("6/mmm", 24),
            Map.entry("23", 12), Map.entry("m-3", 24), Map.entry("432", 24), Map.entry("-43m", 24),
            Map.entry("m-3m", 48));

    @Test
    void catalogHasAll32GroupsWithCorrectOrders() {
        assertEquals(32, PointGroups.all().size());
        for (PointGroups.Entry e : PointGroups.all()) {
            assertEquals(ORDERS.get(e.symbol()), e.group().order(), "order of " + e.symbol());
        }
    }

    @Test
    void signaturesTellAll32GroupsApart() {
        Set<Map<String, Integer>> seen = new HashSet<>();
        for (PointGroups.Entry e : PointGroups.all()) {
            assertTrue(seen.add(e.group().signature()), "duplicate signature for " + e.symbol());
        }
    }

    @Test
    void exactly25GroupsFitTheBlockGrid() {
        long fit = PointGroups.all().stream().filter(e -> e.group().fitsCubicGrid()).count();
        assertEquals(25, fit);
        for (PointGroups.Entry e : PointGroups.all()) {
            assertEquals(!e.hexagonalBasis(), e.group().fitsCubicGrid(), e.symbol());
        }
    }

    /**
     * The hexagonal groups cannot fit the grid in any orientation, not just in the basis listed:
     * every one of them contains a 6 or -6 operation, and no grid operation (signed permutation
     * matrix) is a 6 or -6, because determinant and trace do not depend on orientation.
     */
    @Test
    void noGridOperationIsSixfold() {
        List<SymOp> cubic = PointGroups.bySymbol("m-3m").orElseThrow().group().ops();
        assertEquals(48, cubic.size());
        for (SymOp op : cubic) {
            assertTrue(op.isSignedPermutation());
            assertFalse(op.kind().equals("6") || op.kind().equals("-6"), op.toString());
        }
        for (PointGroups.Entry e : PointGroups.all()) {
            if (!e.hexagonalBasis()) continue;
            Map<String, Integer> sig = e.group().signature();
            assertTrue(sig.containsKey("6") || sig.containsKey("-6"), e.symbol());
        }
    }

    @Test
    void every25GroupIsASubgroupOfCubic() {
        Set<SymOp> cubic = new HashSet<>(PointGroups.bySymbol("m-3m").orElseThrow().group().ops());
        for (PointGroups.Entry e : PointGroups.all()) {
            if (e.hexagonalBasis()) continue;
            assertTrue(cubic.containsAll(e.group().ops()), e.symbol());
        }
    }

    @Test
    void combiningOperationsProducesNewOnes() {
        // Two perpendicular mirrors give a 2-fold axis along the line where they meet.
        SymGroup mm2 = PointGroups.bySymbol("mm2").orElseThrow().group();
        assertTrue(mm2.contains(SymOp.parse("-x,-y,z")));
        // A 2-fold axis plus a mirror perpendicular to it gives an inversion centre.
        SymGroup twoOverM = PointGroups.bySymbol("2/m").orElseThrow().group();
        assertTrue(twoOverM.contains(SymOp.parse("-x,-y,-z")));
        // -4 contains a 2-fold axis but neither a 4-fold axis nor an inversion centre.
        SymGroup minus4 = PointGroups.bySymbol("-4").orElseThrow().group();
        assertTrue(minus4.contains(SymOp.parse("-x,-y,z")));
        assertFalse(minus4.signature().containsKey("4"));
        assertFalse(minus4.contains(SymOp.parse("-x,-y,-z")));
    }

    @Test
    void identifyWorksInAnyOrientation() {
        // A mirror perpendicular to x instead of y is still point group m.
        SymGroup g = SymGroup.pointGroup(List.of(SymOp.parse("-x,y,z")));
        assertEquals("m", PointGroups.identify(g).orElseThrow().symbol());
        // 4mm with the 4-fold axis along x.
        SymGroup g2 = SymGroup.pointGroup(List.of(SymOp.parse("x,-z,y"), SymOp.parse("x,-y,z")));
        assertEquals("4mm", PointGroups.identify(g2).orElseThrow().symbol());
    }

    @Test
    void normalizeAcceptsCommonSpellings() {
        assertEquals("m-3m", PointGroups.normalize("m3m"));
        assertEquals("-43m", PointGroups.normalize("43m"));
        assertEquals("4", PointGroups.normalize("4"));
        assertEquals("-4", PointGroups.normalize("-4"));
        assertEquals("2/m", PointGroups.normalize(" 2 / m "));
    }
}
