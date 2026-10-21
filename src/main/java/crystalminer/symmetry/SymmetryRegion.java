package crystalminer.symmetry;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * A box of blocks in which every placed or broken block is repeated by a symmetry group.
 *
 * <p>Generators are written in crystal axes (z up) and converted to Minecraft axes
 * (X east, Y up, Z south) with x→X, y→−Z, z→Y, which keeps the axes right-handed.
 *
 * <ul>
 *   <li>{@link Anchor#CENTRE}: symmetry elements pass through the centre of the box.
 *   <li>{@link Anchor#FLOOR}: elements pass through the centre of the bottom layer; only operations
 *       that keep "up" pointing up are allowed, so players can build on the ground.
 *   <li>Periodic regions repeat a unit cell; operations act within the cell modulo lattice
 *       translations, and every image is copied into every cell.
 * </ul>
 */
public final class SymmetryRegion {
    public enum Anchor { CENTRE, FLOOR }

    /** Crystal (x, y, z) → Minecraft (X, Y, Z) = (x, z, −y). */
    public static final SymOp CRYSTAL_TO_MC = SymOp.parse("x,z,-y");

    /** One image of a placed block: its position and the operation that produced it. */
    public record Image(int x, int y, int z, SymOp op) {}

    private final int[] min;   // minimum block corner
    private final int[] size;  // in blocks
    private final SymGroup group; // in Minecraft axes, doubled coordinates
    private final int[] origin;   // doubled coordinates
    private final int[] cell;     // in blocks; null if not periodic
    private final String description;

    private SymmetryRegion(int[] min, int[] size, SymGroup group, int[] origin, int[] cell, String description) {
        this.min = min.clone();
        this.size = size.clone();
        this.group = group;
        this.origin = origin;
        this.cell = cell == null ? null : cell.clone();
        this.description = description;
    }

    /** A point-group region (no lattice translations). */
    public static SymmetryRegion point(int[] min, int[] size, Anchor anchor, List<String> crystalGenerators) {
        List<SymOp> gens = crystalGenerators.stream()
                .map(SymOp::parse)
                .map(op -> op.conjugate(CRYSTAL_TO_MC))
                .toList();
        SymGroup g = SymGroup.pointGroup(gens);
        int[] origin = new int[3];
        for (int i = 0; i < 3; i++) origin[i] = 2 * min[i] + size[i];
        if (anchor == Anchor.FLOOR) origin[1] = 2 * min[1] + 1;
        SymmetryRegion r = new SymmetryRegion(min, size, g, origin, null, String.join("; ", crystalGenerators));
        r.validate(anchor);
        return r;
    }

    /**
     * A periodic region of {@code counts} unit cells, each {@code cell} blocks in Minecraft axes.
     * Fractional translations in the generators are fractions of the cell.
     */
    public static SymmetryRegion periodic(int[] min, int[] cell, int[] counts, List<String> crystalGenerators) {
        // Cell lengths along crystal x, y, z = Minecraft X, Z, Y.
        int[] crystalCellDoubled = {2 * cell[0], 2 * cell[2], 2 * cell[1]};
        int[] mcCellDoubled = {2 * cell[0], 2 * cell[1], 2 * cell[2]};
        List<SymOp> gens = crystalGenerators.stream()
                .map(s -> SymOp.parse(s, crystalCellDoubled))
                .map(op -> op.conjugate(CRYSTAL_TO_MC).modulo(mcCellDoubled))
                .toList();
        for (SymOp op : gens) {
            for (int i = 0; i < 3; i++) {
                if (op.t(i) % 2 != 0) {
                    throw new IllegalArgumentException("Translation of " + op
                            + " is not a whole number of blocks; use a cell with an even length for 1/2");
                }
            }
        }
        SymGroup g = SymGroup.periodic(gens, mcCellDoubled);
        int[] size = {cell[0] * counts[0], cell[1] * counts[1], cell[2] * counts[2]};
        int[] origin = {2 * min[0], 2 * min[1], 2 * min[2]};
        SymmetryRegion r = new SymmetryRegion(min, size, g, origin, cell, String.join("; ", crystalGenerators));
        r.validate(Anchor.CENTRE);
        return r;
    }

    private void validate(Anchor anchor) {
        if (!group.fitsCubicGrid()) {
            throw new IllegalArgumentException("Group does not fit the block grid: " + description);
        }
        if (anchor == Anchor.FLOOR) {
            for (SymOp op : group.ops()) {
                if (op.w(1, 1) != 1) {
                    throw new IllegalArgumentException(
                            "A floor region needs operations that keep up pointing up: " + op);
                }
            }
        }
        // Every image of every block must land on a block inside the box, so no copy is ever lost.
        for (int x = 0; x < size[0]; x++) {
            for (int y = 0; y < size[1]; y++) {
                for (int z = 0; z < size[2]; z++) {
                    for (Image im : images(min[0] + x, min[1] + y, min[2] + z)) {
                        if (!contains(im.x(), im.y(), im.z())) {
                            throw new IllegalArgumentException("Image falls outside the region: " + im
                                    + " (box size must match the symmetry, e.g. a cube for 3-fold axes)");
                        }
                    }
                }
            }
        }
    }

    public boolean contains(int x, int y, int z) {
        return x >= min[0] && x < min[0] + size[0]
                && y >= min[1] && y < min[1] + size[1]
                && z >= min[2] && z < min[2] + size[2];
    }

    /** All distinct images of the block at (x, y, z), including the block itself. */
    public List<Image> images(int x, int y, int z) {
        int[] c = {2 * x + 1 - origin[0], 2 * y + 1 - origin[1], 2 * z + 1 - origin[2]};
        Map<List<Integer>, Image> out = new LinkedHashMap<>();
        if (cell == null) {
            for (SymOp op : group.ops()) {
                int[] r = op.apply(c);
                addImage(out, r, new int[3], op);
            }
        } else {
            int[] cd = {2 * cell[0], 2 * cell[1], 2 * cell[2]};
            int[] local = {Math.floorMod(c[0], cd[0]), Math.floorMod(c[1], cd[1]), Math.floorMod(c[2], cd[2])};
            int[] counts = {size[0] / cell[0], size[1] / cell[1], size[2] / cell[2]};
            for (SymOp op : group.ops()) {
                int[] r = op.apply(local);
                for (int i = 0; i < 3; i++) r[i] = Math.floorMod(r[i], cd[i]);
                for (int a = 0; a < counts[0]; a++) {
                    for (int b = 0; b < counts[1]; b++) {
                        for (int k = 0; k < counts[2]; k++) {
                            addImage(out, r, new int[] {a * cd[0], b * cd[1], k * cd[2]}, op);
                        }
                    }
                }
            }
        }
        return new ArrayList<>(out.values());
    }

    private void addImage(Map<List<Integer>, Image> out, int[] r, int[] shift, SymOp op) {
        int[] d = new int[3];
        for (int i = 0; i < 3; i++) {
            d[i] = r[i] + shift[i] + origin[i];
            if (Math.floorMod(d[i], 2) != 1) {
                throw new IllegalStateException("Image is not on a block centre; check region size parity");
            }
        }
        int bx = (d[0] - 1) / 2, by = (d[1] - 1) / 2, bz = (d[2] - 1) / 2;
        out.putIfAbsent(List.of(bx, by, bz), new Image(bx, by, bz, op));
    }

    public SymGroup group() {
        return group;
    }

    public int[] min() {
        return min.clone();
    }

    public int[] size() {
        return size.clone();
    }

    /** Origin of the symmetry elements, in doubled coordinates (divide by 2 for world position). */
    public int[] originDoubled() {
        return origin.clone();
    }

    public boolean isPeriodic() {
        return cell != null;
    }

    public int[] cell() {
        return cell == null ? null : cell.clone();
    }
}
