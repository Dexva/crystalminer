package crystalminer.server;

import crystalminer.content.Content;
import crystalminer.symmetry.SymOp;
import java.util.List;
import net.kyori.adventure.text.Component;
import net.kyori.adventure.text.format.NamedTextColor;
import net.kyori.adventure.text.format.TextDecoration;
import net.minestom.server.coordinate.Pos;
import net.minestom.server.entity.Entity;
import net.minestom.server.entity.EntityType;
import net.minestom.server.entity.metadata.display.AbstractDisplayMeta;
import net.minestom.server.entity.metadata.display.TextDisplayMeta;
import net.minestom.server.instance.Instance;
import net.minestom.server.instance.block.Block;

/** Builds the fixed parts of the world: region borders, labels, and the Symmetry Gate displays. */
public final class WorldBuilder {
    public static final int GROUND_Y = 39; // top layer of the ground; players stand at y = 40

    private static final Block[] TIER_BORDER = {
            Block.WHITE_CONCRETE, Block.LIGHT_BLUE_CONCRETE, Block.LIME_CONCRETE,
            Block.ORANGE_CONCRETE, Block.MAGENTA_CONCRETE};

    /** A chiral motif: an L on the ground with a post at one end. Offsets from its anchor block. */
    static final List<int[]> MOTIF = List.of(
            new int[] {0, 0, 0}, new int[] {1, 0, 0}, new int[] {2, 0, 0}, new int[] {2, 0, 1},
            new int[] {0, 1, 0}, new int[] {0, 2, 0});

    private WorldBuilder() {}

    public static void buildRegion(Instance instance, LiveRegion live) {
        int[] min = live.region().min(), size = live.region().size();
        int tier = live.area().tier();
        Block border = TIER_BORDER[Math.min(tier, TIER_BORDER.length - 1)];
        // Floor under the box, with a coloured border around it.
        for (int x = min[0] - 1; x <= min[0] + size[0]; x++) {
            for (int z = min[2] - 1; z <= min[2] + size[2]; z++) {
                boolean edge = x == min[0] - 1 || x == min[0] + size[0] || z == min[2] - 1 || z == min[2] + size[2];
                instance.setBlock(x, GROUND_Y, z, edge ? border : Block.SMOOTH_QUARTZ);
            }
        }
        // Floating regions: glass along the edges of the box, just outside it.
        if (min[1] > GROUND_Y + 1) {
            int x0 = min[0] - 1, x1 = min[0] + size[0], y0 = min[1] - 1, y1 = min[1] + size[1];
            int z0 = min[2] - 1, z1 = min[2] + size[2];
            for (int x = x0; x <= x1; x++) {
                for (int y = y0; y <= y1; y++) {
                    for (int z = z0; z <= z1; z++) {
                        int onEdge = (x == x0 || x == x1 ? 1 : 0) + (y == y0 || y == y1 ? 1 : 0) + (z == z0 || z == z1 ? 1 : 0);
                        if (onEdge >= 2) instance.setBlock(x, y, z, Block.GLASS);
                    }
                }
            }
        }
        Component label = Component.text(live.area().name(), NamedTextColor.GOLD, TextDecoration.BOLD)
                .append(Component.newline())
                .append(Component.text("Symmetry " + live.symbol(), NamedTextColor.WHITE))
                .append(Component.newline())
                .append(Component.text("Tier " + tier, NamedTextColor.GRAY));
        spawnLabel(instance, new Pos(min[0] + size[0] / 2.0, min[1] + size[1] + 1.5, min[2] + size[2] / 2.0), label);
    }

    /**
     * Four displays of the same chiral motif and its copy under one operation: A reflection,
     * B 2-fold rotation, C translation, D inversion. The quiz asks which is which.
     */
    public static void buildGate(Instance instance, Content.Area gate) {
        int gx = gate.at()[0], gy = gate.at()[1], gz = gate.at()[2];
        String[] letters = {"A", "B", "C", "D"};
        Block[] colours = {Block.BLUE_CONCRETE, Block.RED_CONCRETE, Block.GREEN_CONCRETE, Block.YELLOW_CONCRETE};
        for (int i = 0; i < 4; i++) {
            int ax = gx + 14 * i;
            // Operations in doubled coordinates about a centre between the motif and its copy.
            int cx = 2 * ax + 9, cy = 2 * (gy + 3), cz = 2 * gz + 1;
            SymOp op = switch (i) {
                case 0 -> new SymOp(new int[] {-1, 0, 0, 0, 1, 0, 0, 0, 1}, new int[] {2 * cx, 0, 0});
                case 1 -> new SymOp(new int[] {-1, 0, 0, 0, 1, 0, 0, 0, -1}, new int[] {2 * cx, 0, 2 * cz});
                case 2 -> new SymOp(new int[] {1, 0, 0, 0, 1, 0, 0, 0, 1}, new int[] {12, 0, 0});
                default -> new SymOp(new int[] {-1, 0, 0, 0, -1, 0, 0, 0, -1}, new int[] {2 * cx, 2 * cy, 2 * cz});
            };
            for (int x = ax - 2; x <= ax + 10; x++) {
                for (int z = gz - 4; z <= gz + 3; z++) instance.setBlock(x, GROUND_Y, z, Block.POLISHED_ANDESITE);
            }
            for (int[] m : MOTIF) {
                int bx = ax + m[0], by = gy + m[1], bz = gz + m[2];
                instance.setBlock(bx, by, bz, colours[i]);
                int[] img = op.apply(new int[] {2 * bx + 1, 2 * by + 1, 2 * bz + 1});
                instance.setBlock((img[0] - 1) / 2, (img[1] - 1) / 2, (img[2] - 1) / 2, colours[i]);
            }
            spawnLabel(instance, new Pos(ax + 4.5, gy + 7.5, gz + 0.5),
                    Component.text("Display " + letters[i], NamedTextColor.GOLD, TextDecoration.BOLD));
        }
        spawnLabel(instance, new Pos(gx + 25, gy + 10, gz + 0.5),
                Component.text("Symmetry Gate", NamedTextColor.AQUA, TextDecoration.BOLD)
                        .append(Component.newline())
                        .append(Component.text("Type /quiz to begin", NamedTextColor.WHITE)));
    }

    public static void spawnLabel(Instance instance, Pos pos, Component text) {
        Entity e = new Entity(EntityType.TEXT_DISPLAY);
        TextDisplayMeta meta = (TextDisplayMeta) e.getEntityMeta();
        meta.setText(text);
        meta.setBillboardRenderConstraints(AbstractDisplayMeta.BillboardConstraints.CENTER);
        meta.setScale(new net.minestom.server.coordinate.Vec(1.5, 1.5, 1.5));
        meta.setViewRange(2f);
        e.setNoGravity(true);
        e.setInstance(instance, pos);
    }
}
