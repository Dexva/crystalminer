package crystalminer.server;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import crystalminer.content.Content;
import java.util.List;
import java.util.Optional;
import net.minestom.server.coordinate.BlockVec;
import net.minestom.server.coordinate.Vec;
import net.minestom.server.entity.Player;
import net.minestom.server.entity.PlayerHand;
import net.minestom.server.event.EventDispatcher;
import net.minestom.server.event.player.PlayerBlockBreakEvent;
import net.minestom.server.event.player.PlayerBlockPlaceEvent;
import net.minestom.server.instance.Instance;
import net.minestom.server.instance.block.Block;
import net.minestom.server.instance.block.BlockFace;
import net.minestom.testing.Env;
import net.minestom.testing.EnvTest;
import org.junit.jupiter.api.Test;

/** Runs the real game in Minestom's test environment and simulates players building. */
@EnvTest
class GameIntegrationTest {

    private static PlayerBlockPlaceEvent place(Player p, Instance in, Block b, int x, int y, int z) {
        PlayerBlockPlaceEvent e = new PlayerBlockPlaceEvent(p, in, b, BlockFace.TOP, new BlockVec(x, y, z),
                new Vec(0.5, 1, 0.5), PlayerHand.MAIN);
        EventDispatcher.call(e);
        if (!e.isCancelled()) in.setBlock(x, y, z, e.getBlock());
        return e;
    }

    private static int[] at(Game game, String id) {
        return game.region(id).orElseThrow().region().min();
    }

    @Test
    void mirrorPlazaCopiesBlocksAcrossThePlane(Env env) {
        Game game = CrystalMinerServer.start(Content.load(), Optional.empty());
        Instance in = game.instance();
        Player p = env.createPlayer(in, Game.SPAWN);
        game.progress(p).setTier(1);

        int[] m = at(game, "mirror_plaza"); // 15 wide, mirror at x = m[0] + 7
        place(p, in, Block.STONE, m[0] + 2, m[1], m[2] + 5);
        assertEquals(Block.STONE, in.getBlock(m[0] + 12, m[1], m[2] + 5));

        // Stairs facing east are mirrored to face west.
        place(p, in, Block.OAK_STAIRS.withProperty("facing", "east"), m[0] + 3, m[1], m[2] + 6);
        assertEquals("west", in.getBlock(m[0] + 11, m[1], m[2] + 6).getProperty("facing"));

        // Breaking a block removes its image too.
        PlayerBlockBreakEvent br = new PlayerBlockBreakEvent(p, in, Block.STONE, Block.AIR,
                new BlockVec(m[0] + 2, m[1], m[2] + 5), BlockFace.TOP);
        EventDispatcher.call(br);
        assertTrue(in.getBlock(m[0] + 12, m[1], m[2] + 5).air());
    }

    @Test
    void kaleidoscopeMakes48Copies(Env env) {
        Game game = CrystalMinerServer.start(Content.load(), Optional.empty());
        Instance in = game.instance();
        Player p = env.createPlayer(in, Game.SPAWN);
        game.progress(p).setTier(3);

        int[] k = at(game, "kaleidoscope"); // 15^3 cube, centre at k + 7
        place(p, in, Block.GOLD_BLOCK, k[0] + 8, k[1] + 9, k[2] + 10);
        int count = 0;
        for (int x = 0; x < 15; x++) {
            for (int y = 0; y < 15; y++) {
                for (int z = 0; z < 15; z++) {
                    if (in.getBlock(k[0] + x, k[1] + y, k[2] + z).compare(Block.GOLD_BLOCK)) count++;
                }
            }
        }
        assertEquals(48, count);
    }

    @Test
    void lockedRegionRefusesBlocks(Env env) {
        Game game = CrystalMinerServer.start(Content.load(), Optional.empty());
        Instance in = game.instance();
        Player p = env.createPlayer(in, Game.SPAWN);
        // A new player is tier 0; Mirror Plaza is tier 1.
        int[] m = at(game, "mirror_plaza");
        assertTrue(place(p, in, Block.STONE, m[0] + 2, m[1], m[2] + 5).isCancelled());
        assertTrue(in.getBlock(m[0] + 12, m[1], m[2] + 5).air());
    }

    @Test
    void answeringTheGateQuizUnlocksTier1(Env env) {
        Content content = Content.load();
        Game game = CrystalMinerServer.start(content, Optional.empty());
        Player p = env.createPlayer(game.instance(), Game.SPAWN);
        List<Content.Question> gate = content.gate().questions(0);
        // A wrong answer does not count.
        game.answer(p, gate.get(0).id(), (gate.get(0).answer() + 1) % gate.get(0).options().size());
        assertFalse(game.progress(p).hasAnswered(gate.get(0).id()));
        for (Content.Question q : gate) game.answer(p, q.id(), q.answer());
        assertEquals(1, game.progress(p).tier());
    }

    @Test
    void gateDisplaysShowTheMotifAndItsCopies(Env env) {
        Content content = Content.load();
        Game game = CrystalMinerServer.start(content, Optional.empty());
        Instance in = game.instance();
        int[] g = content.gate().at();
        // Display C (translation): motif at x = g + 28, copy 6 blocks east.
        int ax = g[0] + 28;
        for (int[] o : WorldBuilder.MOTIF) {
            assertFalse(in.getBlock(ax + o[0], g[1] + o[1], g[2] + o[2]).air());
            assertFalse(in.getBlock(ax + 6 + o[0], g[1] + o[1], g[2] + o[2]).air());
        }
        // Display D (inversion): the copy floats above, upside down.
        int dx = g[0] + 42;
        assertFalse(in.getBlock(dx + 8, g[1] + 5, g[2]).air()); // image of the motif's corner block
        assertFalse(in.getBlock(dx + 8, g[1] + 3, g[2]).air()); // image of the top of the post
    }
}
