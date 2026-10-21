package crystalminer.symmetry;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.Map;
import org.junit.jupiter.api.Test;

class BlockStateTransformTest {
    private static SymOp mc(String crystalJones) {
        return SymOp.parse(crystalJones).conjugate(SymmetryRegion.CRYSTAL_TO_MC);
    }

    @Test
    void mirrorPerpendicularToXSwapsEastAndWest() {
        SymOp m = mc("-x,y,z");
        assertEquals("west", BlockStateTransform.transform(Map.of("facing", "east"), m).orElseThrow().get("facing"));
        assertEquals("north", BlockStateTransform.transform(Map.of("facing", "north"), m).orElseThrow().get("facing"));
    }

    @Test
    void mirrorSwapsStairHandedness() {
        Map<String, String> stair = Map.of("facing", "north", "half", "bottom", "shape", "inner_left");
        Map<String, String> out = BlockStateTransform.transform(stair, mc("-x,y,z")).orElseThrow();
        assertEquals("inner_right", out.get("shape"));
        // A rotation keeps handedness.
        assertEquals("inner_left", BlockStateTransform.transform(stair, mc("-y,x,z")).orElseThrow().get("shape"));
    }

    @Test
    void fourfoldRotationTurnsFacingAndLogAxis() {
        SymOp four = mc("-y,x,z");
        String f = BlockStateTransform.transform(Map.of("facing", "east"), four).orElseThrow().get("facing");
        assertTrue(f.equals("north") || f.equals("south"));
        assertEquals("z", BlockStateTransform.transform(Map.of("axis", "x"), four).orElseThrow().get("axis"));
    }

    @Test
    void inversionFlipsSlabHalves() {
        Map<String, String> out = BlockStateTransform.transform(Map.of("type", "bottom"), mc("-x,-y,-z")).orElseThrow();
        assertEquals("top", out.get("type"));
    }

    @Test
    void fenceConnectionsMoveWithTheBlock() {
        Map<String, String> fence = Map.of("north", "true", "east", "false", "south", "false", "west", "false");
        Map<String, String> out = BlockStateTransform.transform(fence, mc("x,-y,z")).orElseThrow();
        assertEquals("true", out.get("south"));
        assertEquals("false", out.get("north"));
    }
}
