package crystalminer.server;

import crystalminer.content.Content;
import crystalminer.tutor.ClaudeTutor;
import java.util.Optional;
import net.minestom.server.Auth;
import net.minestom.server.MinecraftServer;
import net.minestom.server.entity.GameMode;
import net.minestom.server.entity.Player;
import net.minestom.server.event.GlobalEventHandler;
import net.minestom.server.event.player.AsyncPlayerConfigurationEvent;
import net.minestom.server.event.player.PlayerBlockBreakEvent;
import net.minestom.server.event.player.PlayerBlockPlaceEvent;
import net.minestom.server.event.player.PlayerMoveEvent;
import net.minestom.server.event.player.PlayerSpawnEvent;
import net.minestom.server.instance.InstanceContainer;
import net.minestom.server.instance.LightingChunk;
import net.minestom.server.instance.block.Block;
import net.minestom.server.timer.TaskSchedule;

/**
 * Starts the crystalminer server.
 *
 * <p>Environment variables: {@code PORT} (default 25565), {@code CRYSTALMINER_OFFLINE=true} to let
 * players join without Mojang authentication (for a classroom LAN), {@code ANTHROPIC_API_KEY} to
 * enable the tutor.
 */
public final class CrystalMinerServer {
    private CrystalMinerServer() {}

    public static void main(String[] args) {
        boolean offline = Boolean.parseBoolean(System.getenv().getOrDefault("CRYSTALMINER_OFFLINE", "false"));
        int port = Integer.parseInt(System.getenv().getOrDefault("PORT", "25565"));
        MinecraftServer server = MinecraftServer.init(offline ? new Auth.Offline() : new Auth.Online());

        Content content = Content.load();
        Optional<ClaudeTutor> tutor = ClaudeTutor.fromEnv(content);
        Game game = start(content, tutor);

        System.out.printf("crystalminer for Minecraft %s on port %d (%s mode, tutor %s)%n",
                MinecraftServer.VERSION_NAME, port, offline ? "offline" : "online", tutor.isPresent() ? "on" : "off");
        server.start("0.0.0.0", port);
    }

    /** Creates the world and wires up events and commands. Separated from main for tests. */
    public static Game start(Content content, Optional<ClaudeTutor> tutor) {
        InstanceContainer instance = MinecraftServer.getInstanceManager().createInstanceContainer();
        instance.setChunkSupplier(LightingChunk::new);
        instance.setGenerator(unit -> unit.modifier().fillHeight(0, WorldBuilder.GROUND_Y + 1, Block.GRASS_BLOCK));
        // Load the area the world uses so it can be built before anyone joins.
        for (int cx = -8; cx <= 4; cx++) {
            for (int cz = -3; cz <= 12; cz++) instance.loadChunk(cx, cz).join();
        }

        Game game = new Game(content, instance, tutor);
        game.buildWorld();

        GlobalEventHandler events = MinecraftServer.getGlobalEventHandler();
        events.addListener(AsyncPlayerConfigurationEvent.class, e -> {
            e.setSpawningInstance(instance);
            e.getPlayer().setRespawnPoint(Game.SPAWN);
        });
        events.addListener(PlayerSpawnEvent.class, e -> {
            if (!e.isFirstSpawn()) return;
            Player p = e.getPlayer();
            p.setGameMode(GameMode.CREATIVE);
            p.setAllowFlying(true);
            game.welcome(p);
        });
        events.addListener(PlayerBlockPlaceEvent.class, game::onPlace);
        events.addListener(PlayerBlockBreakEvent.class, game::onBreak);
        events.addListener(PlayerMoveEvent.class, game::onMove);

        new GameCommands(game).registerAll();
        MinecraftServer.getSchedulerManager().buildTask(game::drawElements).repeat(TaskSchedule.tick(20)).schedule();
        return game;
    }
}
