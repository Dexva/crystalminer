package crystalminer.symmetry;

import java.util.HashMap;
import java.util.Map;
import java.util.Optional;

/**
 * Transforms Minecraft block-state properties (facing, axis, half, connections, stair shape) by
 * the linear part of a symmetry operation given in Minecraft coordinates (X east, Y up, Z south).
 *
 * <p>Returns empty when the result cannot be expressed as a block state (for example a stair whose
 * facing would point up); the caller then places the block in its default orientation.
 */
public final class BlockStateTransform {
    private static final Map<String, int[]> DIRS = Map.of(
            "east", new int[] {1, 0, 0},
            "west", new int[] {-1, 0, 0},
            "up", new int[] {0, 1, 0},
            "down", new int[] {0, -1, 0},
            "south", new int[] {0, 0, 1},
            "north", new int[] {0, 0, -1});
    private static final String[] AXES = {"x", "y", "z"};

    private BlockStateTransform() {}

    public static Optional<Map<String, String>> transform(Map<String, String> props, SymOp op) {
        if (props.isEmpty()) return Optional.of(props);
        Map<String, String> out = new HashMap<>(props);
        boolean yKept = Math.abs(op.w(1, 1)) == 1;
        boolean yFlipped = op.w(1, 1) == -1;

        String facing = props.get("facing");
        if (facing != null) {
            String nf = dirName(op.applyLinear(DIRS.get(facing)));
            if (nf == null) return Optional.empty();
            out.put("facing", nf);
        }

        String axis = props.get("axis");
        if (axis != null) {
            int a = indexOf(axis);
            if (a < 0) return Optional.empty();
            int[] v = new int[3];
            v[a] = 1;
            int[] nv = op.applyLinear(v);
            for (int i = 0; i < 3; i++) if (nv[i] != 0) out.put("axis", AXES[i]);
        }

        // Connection flags such as fences, walls and panes ("north": "true", "up": "tall", ...).
        Map<String, String> moved = new HashMap<>();
        for (Map.Entry<String, int[]> d : DIRS.entrySet()) {
            if (props.containsKey(d.getKey())) {
                moved.put(dirName(op.applyLinear(d.getValue())), props.get(d.getKey()));
            }
        }
        for (String k : moved.keySet()) {
            // The block must have a property for every new direction (a fence has no "up").
            if (!props.containsKey(k)) return Optional.empty();
        }
        out.putAll(moved);

        if (yFlipped) {
            flip(out, "half", "top", "bottom");
            flip(out, "type", "top", "bottom");
        }

        String shape = props.get("shape");
        if (shape != null && (shape.endsWith("_left") || shape.endsWith("_right"))) {
            if (!yKept) return Optional.empty();
            // Stair shapes are left- or right-handed when seen from above; a mirror in the
            // horizontal plane swaps them.
            int horizontalDet = op.w(0, 0) * op.w(2, 2) - op.w(0, 2) * op.w(2, 0);
            if (horizontalDet < 0) {
                out.put("shape", shape.endsWith("_left")
                        ? shape.replace("_left", "_right")
                        : shape.replace("_right", "_left"));
            }
        }

        if (props.containsKey("rotation")) return Optional.empty(); // 16-step rotation (signs, banners): not handled
        return Optional.of(out);
    }

    private static void flip(Map<String, String> props, String key, String a, String b) {
        String v = props.get(key);
        if (a.equals(v)) props.put(key, b);
        else if (b.equals(v)) props.put(key, a);
    }

    private static int indexOf(String axis) {
        for (int i = 0; i < 3; i++) if (AXES[i].equals(axis)) return i;
        return -1;
    }

    private static String dirName(int[] v) {
        for (Map.Entry<String, int[]> e : DIRS.entrySet()) {
            int[] d = e.getValue();
            if (d[0] == v[0] && d[1] == v[1] && d[2] == v[2]) return e.getKey();
        }
        return null;
    }
}
