package crystalminer.symmetry;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import org.junit.jupiter.api.Test;

class SymmetryRegionTest {
    private static Set<List<Integer>> positions(List<SymmetryRegion.Image> images) {
        Set<List<Integer>> s = new HashSet<>();
        for (SymmetryRegion.Image im : images) s.add(List.of(im.x(), im.y(), im.z()));
        return s;
    }

    @Test
    void mirrorPerpendicularToXReflectsEastWest() {
        // Box x 0..14, centre column x = 7.
        SymmetryRegion r = SymmetryRegion.point(new int[] {0, 40, 0}, new int[] {15, 12, 15},
                SymmetryRegion.Anchor.FLOOR, List.of("-x,y,z"));
        assertEquals(Set.of(List.of(2, 41, 5), List.of(12, 41, 5)), positions(r.images(2, 41, 5)));
        // A block on the mirror plane is its own image.
        assertEquals(1, r.images(7, 41, 5).size());
    }

    @Test
    void fourfoldAxisMakesFourCopiesOffAxisAndOneOnAxis() {
        SymmetryRegion r = SymmetryRegion.point(new int[] {0, 40, 0}, new int[] {15, 12, 15},
                SymmetryRegion.Anchor.FLOOR, List.of("-y,x,z"));
        assertEquals(4, r.images(2, 45, 4).size());
        assertEquals(1, r.images(7, 45, 7).size());
        // Heights are unchanged by a vertical axis.
        r.images(2, 45, 4).forEach(im -> assertEquals(45, im.y()));
    }

    @Test
    void inversionMapsThroughTheCentre() {
        SymmetryRegion r = SymmetryRegion.point(new int[] {0, 41, 0}, new int[] {15, 15, 15},
                SymmetryRegion.Anchor.CENTRE, List.of("-x,-y,-z"));
        // Centre block is (7, 48, 7); (1, 42, 3) maps to (13, 54, 11).
        assertEquals(Set.of(List.of(1, 42, 3), List.of(13, 54, 11)), positions(r.images(1, 42, 3)));
    }

    @Test
    void kaleidoscopeMakes48CopiesOfAGeneralBlock() {
        SymmetryRegion r = SymmetryRegion.point(new int[] {0, 41, 0}, new int[] {15, 15, 15},
                SymmetryRegion.Anchor.CENTRE, PointGroups.bySymbol("m-3m").orElseThrow().generators());
        assertEquals(48, r.group().order());
        // Offsets from the centre (7, 48, 7) of (1, 2, 3): all different and non-zero, so a general position.
        assertEquals(48, r.images(8, 50, 10).size());
    }

    @Test
    void floorRegionRejectsOperationsThatFlipUpAndDown() {
        assertThrows(IllegalArgumentException.class, () -> SymmetryRegion.point(new int[] {0, 40, 0},
                new int[] {15, 12, 15}, SymmetryRegion.Anchor.FLOOR, List.of("-x,-y,-z")));
    }

    @Test
    void threefoldAxisNeedsACube() {
        assertThrows(IllegalArgumentException.class, () -> SymmetryRegion.point(new int[] {0, 41, 0},
                new int[] {15, 13, 15}, SymmetryRegion.Anchor.CENTRE, List.of("z,x,y")));
        SymmetryRegion r = SymmetryRegion.point(new int[] {0, 41, 0}, new int[] {15, 15, 15},
                SymmetryRegion.Anchor.CENTRE, List.of("z,x,y"));
        assertEquals(3, r.images(8, 50, 10).size());
    }

    @Test
    void hexagonalGroupCannotBeARegion() {
        assertThrows(IllegalArgumentException.class, () -> SymmetryRegion.point(new int[] {0, 41, 0},
                new int[] {15, 15, 15}, SymmetryRegion.Anchor.CENTRE, List.of("x-y,x,z")));
    }

    @Test
    void latticeRepeatsTheBlockInEveryCell() {
        SymmetryRegion r = SymmetryRegion.periodic(new int[] {0, 41, 0}, new int[] {6, 6, 6},
                new int[] {3, 3, 3}, List.of());
        List<SymmetryRegion.Image> images = r.images(1, 42, 2);
        assertEquals(27, images.size());
        assertTrue(positions(images).contains(List.of(13, 54, 14)));
    }

    @Test
    void screwAxisRotatesAndShiftsHalfACell() {
        // 2_1 along the vertical axis: rotate 180° about a vertical line through the cell corner,
        // then move up half a cell (3 blocks).
        SymmetryRegion r = SymmetryRegion.periodic(new int[] {0, 41, 0}, new int[] {6, 6, 6},
                new int[] {1, 2, 1}, List.of("-x,-y,z+1/2"));
        assertEquals(2, r.group().order());
        Set<List<Integer>> p = positions(r.images(1, 41, 2));
        // Original (1, 41, 2) in cells at y = 41 and 47; rotated (4, 44, 3) in the same two cells.
        assertEquals(Set.of(List.of(1, 41, 2), List.of(1, 47, 2), List.of(4, 44, 3), List.of(4, 50, 3)), p);
    }

    @Test
    void halfCellTranslationNeedsAnEvenCell() {
        assertThrows(IllegalArgumentException.class, () -> SymmetryRegion.periodic(new int[] {0, 41, 0},
                new int[] {5, 5, 5}, new int[] {2, 2, 2}, List.of("-x,-y,z+1/2")));
    }

    @Test
    void detectorFindsTheSymmetryOfABuild() {
        // Build inside the 4mm region, then check that the detector recovers 4mm.
        SymmetryRegion r = SymmetryRegion.point(new int[] {0, 40, 0}, new int[] {15, 12, 15},
                SymmetryRegion.Anchor.FLOOR, List.of("-y,x,z", "x,-y,z"));
        Map<List<Integer>, String> build = new HashMap<>();
        for (int[] b : new int[][] {{2, 40, 5}, {3, 41, 5}, {9, 42, 13}}) {
            for (SymmetryRegion.Image im : r.images(b[0], b[1], b[2])) {
                build.put(List.of(2 * im.x() + 1, 2 * im.y() + 1, 2 * im.z() + 1), "stone");
            }
        }
        SymmetryDetector.Result res = SymmetryDetector.detect(build);
        assertEquals("4mm", res.pointGroup().orElseThrow().symbol());
    }

    @Test
    void detectorDistinguishesBlockTypes() {
        Map<List<Integer>, String> build = new HashMap<>();
        build.put(List.of(1, 1, 1), "stone");
        build.put(List.of(5, 1, 1), "stone");
        // Two equal blocks in a row: a 4-fold axis along the row, mirrors, and an inversion centre.
        assertEquals("4/mmm", SymmetryDetector.detect(build).pointGroup().orElseThrow().symbol());
        build.put(List.of(5, 1, 1), "gold");
        // Two different blocks: only the operations that fix each block survive.
        assertEquals("4mm", SymmetryDetector.detect(build).pointGroup().orElseThrow().symbol());
    }
}
