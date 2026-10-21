package crystalminer.server;

import crystalminer.content.Content;
import crystalminer.content.Progress;
import crystalminer.symmetry.BlockStateTransform;
import crystalminer.symmetry.SymmetryRegion;
import crystalminer.tutor.ClaudeTutor;
import java.time.Duration;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;
import net.kyori.adventure.text.Component;
import net.kyori.adventure.text.event.ClickEvent;
import net.kyori.adventure.text.event.HoverEvent;
import net.kyori.adventure.text.format.NamedTextColor;
import net.kyori.adventure.text.format.TextDecoration;
import net.kyori.adventure.title.Title;
import net.minestom.server.coordinate.Pos;
import net.minestom.server.coordinate.Vec;
import net.minestom.server.entity.Player;
import net.minestom.server.event.player.PlayerBlockBreakEvent;
import net.minestom.server.event.player.PlayerBlockPlaceEvent;
import net.minestom.server.event.player.PlayerMoveEvent;
import net.minestom.server.instance.Instance;
import net.minestom.server.instance.block.Block;
import net.minestom.server.network.packet.server.play.ParticlePacket;
import net.minestom.server.particle.Particle;

/** The running game: regions, players' progress, and what happens when they build or answer. */
public final class Game {
    public static final Pos SPAWN = new Pos(0.5, 40, 5.5, 180f, 0f);

    private final Content content;
    private final Instance instance;
    private final List<LiveRegion> regions = new ArrayList<>();
    private final Optional<ClaudeTutor> tutor;
    private final Map<UUID, Progress> progress = new ConcurrentHashMap<>();
    private final Map<UUID, String> currentArea = new ConcurrentHashMap<>();
    private final Map<UUID, Boolean> waitingForTutor = new ConcurrentHashMap<>();

    public Game(Content content, Instance instance, Optional<ClaudeTutor> tutor) {
        this.content = content;
        this.instance = instance;
        this.tutor = tutor;
        for (Content.Area a : content.regions()) regions.add(new LiveRegion(a));
    }

    public Content content() {
        return content;
    }

    public Instance instance() {
        return instance;
    }

    public List<LiveRegion> regions() {
        return regions;
    }

    public Optional<ClaudeTutor> tutor() {
        return tutor;
    }

    public Progress progress(Player p) {
        return progress.computeIfAbsent(p.getUuid(), u -> new Progress());
    }

    public Map<UUID, Boolean> waitingForTutor() {
        return waitingForTutor;
    }

    public void buildWorld() {
        WorldBuilder.buildGate(instance, content.gate());
        for (LiveRegion r : regions) WorldBuilder.buildRegion(instance, r);
    }

    public Optional<LiveRegion> regionAt(int x, int y, int z) {
        return regions.stream().filter(r -> r.contains(x, y, z)).findFirst();
    }

    /** The region whose surroundings the player is standing in, if any. */
    public Optional<LiveRegion> regionNear(Pos pos) {
        return regions.stream().filter(r -> r.near(pos.x(), pos.y(), pos.z(), 2)).findFirst();
    }

    public Optional<LiveRegion> region(String id) {
        return regions.stream().filter(r -> r.area().id().equals(id)).findFirst();
    }

    // ---------------------------------------------------------------- building

    public void onPlace(PlayerBlockPlaceEvent event) {
        var pos = event.getBlockPosition();
        Optional<LiveRegion> r = regionAt(pos.blockX(), pos.blockY(), pos.blockZ());
        if (r.isEmpty()) return;
        if (!unlocked(event.getPlayer(), r.get())) {
            event.setCancelled(true);
            return;
        }
        Block placed = event.getBlock();
        for (SymmetryRegion.Image im : r.get().region().images(pos.blockX(), pos.blockY(), pos.blockZ())) {
            if (im.x() == pos.blockX() && im.y() == pos.blockY() && im.z() == pos.blockZ()) continue;
            instance.setBlock(im.x(), im.y(), im.z(), transformed(placed, im));
        }
    }

    public void onBreak(PlayerBlockBreakEvent event) {
        var pos = event.getBlockPosition();
        Optional<LiveRegion> r = regionAt(pos.blockX(), pos.blockY(), pos.blockZ());
        if (r.isEmpty()) return;
        if (!unlocked(event.getPlayer(), r.get())) {
            event.setCancelled(true);
            return;
        }
        for (SymmetryRegion.Image im : r.get().region().images(pos.blockX(), pos.blockY(), pos.blockZ())) {
            if (im.x() == pos.blockX() && im.y() == pos.blockY() && im.z() == pos.blockZ()) continue;
            instance.setBlock(im.x(), im.y(), im.z(), Block.AIR);
        }
    }

    /** Rotates or mirrors the block's orientation to match its image; falls back to the default state. */
    static Block transformed(Block block, SymmetryRegion.Image im) {
        return BlockStateTransform.transform(block.properties(), im.op())
                .map(props -> {
                    try {
                        Block b = block;
                        for (Map.Entry<String, String> e : props.entrySet()) b = b.withProperty(e.getKey(), e.getValue());
                        return b;
                    } catch (IllegalArgumentException ex) {
                        return block.defaultState();
                    }
                })
                .orElse(block.defaultState());
    }

    private boolean unlocked(Player p, LiveRegion r) {
        int tier = progress(p).tier();
        if (tier >= r.area().tier()) return true;
        p.sendActionBar(Component.text("Locked: reach tier " + r.area().tier() + " to build in "
                + r.area().name() + ". Type /quiz to progress.", NamedTextColor.RED));
        return false;
    }

    // ---------------------------------------------------------------- explanations

    public void onMove(PlayerMoveEvent event) {
        Player p = event.getPlayer();
        Pos pos = event.getNewPosition();
        String id = regionNear(pos).map(r -> r.area().id()).orElse(nearGate(pos) ? content.gate().id() : "");
        String before = currentArea.put(p.getUuid(), id);
        if (id.equals(before) || id.isEmpty()) return;
        if (id.equals(content.gate().id())) {
            p.sendActionBar(Component.text("Symmetry Gate: type /quiz to test yourself", NamedTextColor.AQUA));
        } else {
            region(id).ifPresent(r -> explain(p, r, true));
        }
    }

    private boolean nearGate(Pos pos) {
        int[] g = content.gate().at();
        return pos.x() >= g[0] - 3 && pos.x() <= g[0] + 55 && pos.z() >= g[2] - 6 && pos.z() <= g[2] + 5;
    }

    public void explain(Player p, LiveRegion r, boolean showTitle) {
        int tier = progress(p).tier();
        Content.Area a = r.area();
        if (showTitle) {
            p.showTitle(Title.title(
                    Component.text(a.name(), NamedTextColor.GOLD),
                    Component.text("Symmetry " + r.symbol() + (tier < a.tier() ? "  (locked: tier " + a.tier() + ")" : ""),
                            NamedTextColor.WHITE),
                    Title.Times.times(Duration.ofMillis(300), Duration.ofSeconds(2), Duration.ofMillis(500))));
        }
        p.sendMessage(Component.text("— " + a.name() + " (" + r.symbol() + ") —", NamedTextColor.GOLD));
        List<String> lines = a.explanationFor(Math.max(tier, 0));
        if (tier < a.tier()) {
            p.sendMessage(Component.text("You can look around, but building here unlocks at tier " + a.tier()
                    + ". Finish the quizzes of tier " + tier + " first (/quiz).", NamedTextColor.GRAY));
            return;
        }
        for (String l : lines) p.sendMessage(Component.text(l, NamedTextColor.WHITE));
        if (!r.dots().isEmpty()) {
            p.sendMessage(Component.text("Coloured dots show the symmetry elements: ", NamedTextColor.GRAY)
                    .append(Component.text("2-fold ", rgb(LiveRegion.AXIS_2)))
                    .append(Component.text("3-fold ", rgb(LiveRegion.AXIS_3)))
                    .append(Component.text("4-fold ", rgb(LiveRegion.AXIS_4)))
                    .append(Component.text("rotoinversion ", rgb(LiveRegion.ROTOINVERSION)))
                    .append(Component.text("mirror ", rgb(LiveRegion.MIRROR)))
                    .append(Component.text("inversion centre", rgb(LiveRegion.INVERSION))));
        }
        if (openQuestions(p, a) > 0) {
            p.sendMessage(button("[Take the quiz]", "/quiz", "Questions about this region"));
        }
    }

    private static net.kyori.adventure.text.format.TextColor rgb(int c) {
        return net.kyori.adventure.text.format.TextColor.color(c);
    }

    // ---------------------------------------------------------------- quizzes

    private int openQuestions(Player p, Content.Area a) {
        Progress pr = progress(p);
        int n = 0;
        for (Content.Question q : a.questions(pr.tier())) if (!pr.hasAnswered(q.id())) n++;
        return n;
    }

    /** Shows the next unanswered question here, or where to find the remaining ones. */
    public void showQuiz(Player p) {
        Progress pr = progress(p);
        String here = currentArea.getOrDefault(p.getUuid(), "");
        Optional<Content.Area> area = content.region(here);
        if (pr.tier() == 0) area = Optional.of(content.gate());
        if (area.isPresent()) {
            for (Content.Question q : area.get().questions(pr.tier())) {
                if (!pr.hasAnswered(q.id())) {
                    ask(p, q);
                    return;
                }
            }
        }
        List<Content.Area> open = new ArrayList<>();
        for (Content.Area a : content.regions()) if (openQuestions(p, a) > 0) open.add(a);
        if (open.isEmpty()) {
            p.sendMessage(Component.text("No questions left at your tier.", NamedTextColor.GREEN));
            return;
        }
        p.sendMessage(Component.text("Questions for tier " + pr.tier() + " are waiting in:", NamedTextColor.YELLOW));
        for (Content.Area a : open) {
            p.sendMessage(button("  " + a.name() + " (" + openQuestions(p, a) + ")", "/goto " + a.id(),
                    "Teleport to " + a.name()));
        }
    }

    private void ask(Player p, Content.Question q) {
        p.sendMessage(Component.text(q.text(), NamedTextColor.YELLOW, TextDecoration.BOLD));
        for (int i = 0; i < q.options().size(); i++) {
            p.sendMessage(button("  " + (char) ('A' + i) + ") " + q.options().get(i),
                    "/answer " + q.id() + " " + i, "Choose this answer"));
        }
    }

    public void answer(Player p, String questionId, int choice) {
        Optional<Content.Question> oq = content.question(questionId);
        if (oq.isEmpty()) {
            p.sendMessage(Component.text("Unknown question.", NamedTextColor.RED));
            return;
        }
        Content.Question q = oq.get();
        Progress pr = progress(p);
        if (pr.hasAnswered(q.id())) {
            p.sendMessage(Component.text("You already answered that one.", NamedTextColor.GRAY));
            return;
        }
        if (!content.questionsForTier(pr.tier()).containsKey(q.id())) {
            p.sendMessage(Component.text("That question is not part of your current tier.", NamedTextColor.GRAY));
            return;
        }
        if (choice != q.answer()) {
            p.sendMessage(Component.text("Not quite. Look at the copies again and try another option.", NamedTextColor.RED));
            ask(p, q);
            return;
        }
        p.sendMessage(Component.text("Correct! ", NamedTextColor.GREEN).append(Component.text(q.why(), NamedTextColor.WHITE)));
        int before = pr.tier();
        if (pr.recordCorrect(content, q.id())) {
            String name = content.tierNames().getOrDefault(pr.tier(), "");
            p.showTitle(Title.title(Component.text("Tier " + pr.tier() + " unlocked", NamedTextColor.GREEN),
                    Component.text(name, NamedTextColor.WHITE)));
            p.sendMessage(Component.text("You finished tier " + before + ". New regions are open: ", NamedTextColor.GREEN)
                    .append(button("[Show regions]", "/regions", "List all regions")));
        } else {
            int left = pr.remaining(content);
            p.sendMessage(Component.text(left + " question(s) left in tier " + pr.tier() + ". ", NamedTextColor.GRAY)
                    .append(button("[Next question]", "/quiz", "Show the next question")));
        }
    }

    // ---------------------------------------------------------------- visuals

    /** Draws the symmetry elements of the region each player is in or next to. Called every second. */
    public void drawElements() {
        for (Player p : instance.getPlayers()) {
            for (LiveRegion r : regions) {
                Pos pos = p.getPosition();
                if (r.dots().isEmpty() || !r.near(pos.x(), pos.y(), pos.z(), 6)) continue;
                if (progress(p).tier() < r.area().tier()) continue;
                for (LiveRegion.Dot d : r.dots()) {
                    Particle particle = Particle.DUST.withColor(rgb(d.rgb()));
                    p.sendPacket(new ParticlePacket(particle, d.pos(), Vec.ZERO, 0f, 1));
                }
            }
        }
    }

    // ---------------------------------------------------------------- helpers

    public static Component button(String text, String command, String hover) {
        return Component.text(text, NamedTextColor.AQUA)
                .clickEvent(ClickEvent.runCommand(command))
                .hoverEvent(HoverEvent.showText(Component.text(hover)));
    }

    public void welcome(Player p) {
        p.sendMessage(Component.text("crystalminer", NamedTextColor.AQUA, TextDecoration.BOLD));
        for (String l : content.intro()) p.sendMessage(Component.text(l, NamedTextColor.WHITE));
        p.sendMessage(button("[Start the gate quiz]", "/quiz", "Five questions about the displays")
                .append(Component.text("   "))
                .append(button("[All commands]", "/guide", "What you can do here")));
    }

    public String currentAreaId(Player p) {
        return currentArea.getOrDefault(p.getUuid(), "");
    }
}
