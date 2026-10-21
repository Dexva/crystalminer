package crystalminer.server;

import crystalminer.content.Content;
import crystalminer.content.Progress;
import crystalminer.symmetry.PointGroups;
import crystalminer.symmetry.SymGroup;
import crystalminer.symmetry.SymmetryDetector;
import crystalminer.tutor.ClaudeTutor;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.function.BiConsumer;
import net.kyori.adventure.text.Component;
import net.kyori.adventure.text.format.NamedTextColor;
import net.minestom.server.MinecraftServer;
import net.minestom.server.command.CommandManager;
import net.minestom.server.command.builder.Command;
import net.minestom.server.command.builder.arguments.ArgumentType;
import net.minestom.server.coordinate.Pos;
import net.minestom.server.entity.Player;
import net.minestom.server.instance.block.Block;

/** Chat commands. */
public final class GameCommands {
    private final Game game;

    public GameCommands(Game game) {
        this.game = game;
    }

    public void registerAll() {
        CommandManager cm = MinecraftServer.getCommandManager();
        cm.register(simple("guide", (p, args) -> guide(p)));
        cm.register(simple("quiz", (p, args) -> game.showQuiz(p)));
        cm.register(simple("explain", (p, args) -> explainHere(p)));
        cm.register(simple("regions", (p, args) -> listRegions(p)));
        cm.register(simple("progress", (p, args) -> showProgress(p)));
        cm.register(simple("spawn", (p, args) -> p.teleport(Game.SPAWN)));
        cm.register(simple("whatsymmetry", (p, args) -> whatSymmetry(p)));
        cm.register(simple("challenge", (p, args) -> challenge(p)));
        cm.register(simple("clearlab", (p, args) -> clearLab(p)));

        Command answer = new Command("answer");
        var qid = ArgumentType.Word("question");
        var choice = ArgumentType.Integer("choice");
        answer.addSyntax((sender, ctx) -> {
            if (sender instanceof Player p) game.answer(p, ctx.get(qid), ctx.get(choice));
        }, qid, choice);
        cm.register(answer);

        Command go = new Command("goto");
        var region = ArgumentType.Word("region");
        go.addSyntax((sender, ctx) -> {
            if (sender instanceof Player p) teleport(p, ctx.get(region));
        }, region);
        cm.register(go);

        Command ask = new Command("ask");
        var question = ArgumentType.StringArray("question");
        ask.setDefaultExecutor((sender, ctx) -> sender.sendMessage(
                Component.text("Usage: /ask <your question>", NamedTextColor.GRAY)));
        ask.addSyntax((sender, ctx) -> {
            if (sender instanceof Player p) ask(p, String.join(" ", ctx.get(question)));
        }, question);
        cm.register(ask);

        Command symmetry = new Command("symmetry");
        var description = ArgumentType.StringArray("description");
        symmetry.setDefaultExecutor((sender, ctx) -> sender.sendMessage(
                Component.text("Usage: /symmetry <description>, e.g. /symmetry a fourfold axis with mirrors",
                        NamedTextColor.GRAY)));
        symmetry.addSyntax((sender, ctx) -> {
            if (sender instanceof Player p) setSymmetry(p, String.join(" ", ctx.get(description)));
        }, description);
        cm.register(symmetry);

        // For teachers and demos: jump straight to a tier.
        Command setTier = new Command("settier");
        var tier = ArgumentType.Integer("tier").between(0, game.content().maxTier());
        setTier.addSyntax((sender, ctx) -> {
            if (sender instanceof Player p) {
                game.progress(p).setTier(ctx.get(tier));
                p.sendMessage(Component.text("Tier set to " + ctx.get(tier) + ".", NamedTextColor.GREEN));
            }
        }, tier);
        cm.register(setTier);
    }

    private static Command simple(String name, BiConsumer<Player, String[]> action) {
        Command c = new Command(name);
        c.setDefaultExecutor((sender, ctx) -> {
            if (sender instanceof Player p) action.accept(p, new String[0]);
        });
        return c;
    }

    private void guide(Player p) {
        String[][] rows = {
                {"/quiz", "answer questions to unlock the next tier"},
                {"/explain", "repeat the explanation for the region you are in"},
                {"/regions", "list all regions and teleport to them"},
                {"/progress", "see your tier"},
                {"/ask <question>", "ask the tutor about symmetry"},
                {"/whatsymmetry", "work out the exact symmetry of what you built in a region"},
                {"/symmetry <description>", "give the Free Lab a symmetry (tier 4)"},
                {"/challenge", "get a build challenge for the Free Lab (tier 4)"},
                {"/clearlab", "empty the Free Lab"},
                {"/spawn", "go back to the start"}};
        p.sendMessage(Component.text("Commands", NamedTextColor.GOLD));
        for (String[] r : rows) {
            p.sendMessage(Component.text(r[0], NamedTextColor.AQUA).append(Component.text("  " + r[1], NamedTextColor.WHITE)));
        }
        p.sendMessage(Component.text("You are in creative mode: double-tap jump to fly.", NamedTextColor.GRAY));
    }

    private void explainHere(Player p) {
        Optional<LiveRegion> r = game.regionNear(p.getPosition());
        if (r.isPresent()) game.explain(p, r.get(), false);
        else game.welcome(p);
    }

    private void listRegions(Player p) {
        int tier = game.progress(p).tier();
        p.sendMessage(Component.text("Regions (you are tier " + tier + ")", NamedTextColor.GOLD));
        p.sendMessage(Game.button("  Symmetry Gate (tier 0)", "/goto " + game.content().gate().id(), "Teleport"));
        for (LiveRegion r : game.regions()) {
            Content.Area a = r.area();
            boolean open = tier >= a.tier();
            Component line = Game.button("  " + a.name() + " (" + r.symbol() + ", tier " + a.tier() + ")",
                    "/goto " + a.id(), "Teleport");
            if (!open) line = line.color(NamedTextColor.DARK_GRAY);
            p.sendMessage(line);
        }
    }

    private void teleport(Player p, String id) {
        if (id.equals(game.content().gate().id())) {
            p.teleport(Game.SPAWN);
            return;
        }
        Optional<LiveRegion> r = game.region(id);
        if (r.isEmpty()) {
            p.sendMessage(Component.text("No region called " + id, NamedTextColor.RED));
            return;
        }
        int[] min = r.get().region().min(), size = r.get().region().size();
        // Stand just south of the region, facing north into it.
        p.teleport(new Pos(min[0] + size[0] / 2.0, WorldBuilder.GROUND_Y + 1, min[2] + size[2] + 3, 180f, 10f));
    }

    private void showProgress(Player p) {
        Progress pr = game.progress(p);
        String name = game.content().tierNames().getOrDefault(pr.tier(), "");
        p.sendMessage(Component.text("Tier " + pr.tier() + ": " + name + ". "
                + pr.remaining(game.content()) + " question(s) left in this tier.", NamedTextColor.GOLD));
    }

    // ---------------------------------------------------------------- tutor

    private void ask(Player p, String question) {
        Optional<ClaudeTutor> tutor = game.tutor();
        if (tutor.isEmpty()) {
            p.sendMessage(Component.text("The tutor is not set up on this server (no ANTHROPIC_API_KEY).", NamedTextColor.GRAY));
            return;
        }
        if (game.waitingForTutor().putIfAbsent(p.getUuid(), true) != null) {
            p.sendMessage(Component.text("The tutor is still thinking about your last question.", NamedTextColor.GRAY));
            return;
        }
        p.sendMessage(Component.text("You asked: " + question, NamedTextColor.GRAY));
        String regionName = game.regionNear(p.getPosition()).map(r -> r.area().name()).orElse(null);
        tutor.get().ask(question, game.progress(p).tier(), regionName).whenComplete((answer, err) -> {
            game.waitingForTutor().remove(p.getUuid());
            String text = err != null ? "The tutor could not be reached." : answer;
            p.sendMessage(Component.text("Tutor: ", NamedTextColor.LIGHT_PURPLE).append(Component.text(text, NamedTextColor.WHITE)));
        });
    }

    // ---------------------------------------------------------------- symmetry analysis

    private void whatSymmetry(Player p) {
        Optional<LiveRegion> r = game.regionNear(p.getPosition());
        if (r.isEmpty()) {
            p.sendMessage(Component.text("Stand in or next to a region first.", NamedTextColor.GRAY));
            return;
        }
        int[] min = r.get().region().min(), size = r.get().region().size();
        Map<List<Integer>, String> blocks = new HashMap<>();
        for (int x = min[0]; x < min[0] + size[0]; x++) {
            for (int y = min[1]; y < min[1] + size[1]; y++) {
                for (int z = min[2]; z < min[2] + size[2]; z++) {
                    Block b = game.instance().getBlock(x, y, z);
                    if (!b.air()) blocks.put(List.of(2 * x + 1, 2 * y + 1, 2 * z + 1), b.name());
                }
            }
        }
        if (blocks.isEmpty()) {
            p.sendMessage(Component.text("Nothing built here yet.", NamedTextColor.GRAY));
            return;
        }
        SymmetryDetector.Result res = SymmetryDetector.detect(blocks);
        String symbol = res.pointGroup().map(PointGroups.Entry::symbol).orElse("?");
        p.sendMessage(Component.text("Your build has point symmetry " + symbol + " ("
                + res.group().order() + " operation" + (res.group().order() == 1 ? "" : "s") + ").", NamedTextColor.GOLD));
        p.sendMessage(Component.text(describe(res.group()), NamedTextColor.WHITE));
        p.sendMessage(Component.text("(Block types count; which way a block faces does not.)", NamedTextColor.GRAY));

        Progress pr = game.progress(p);
        List<Content.Challenge> challenges = r.get().area().challenges();
        if (!challenges.isEmpty() && pr.challenge() < challenges.size()) {
            Content.Challenge c = challenges.get(pr.challenge());
            if (c.target().equals(symbol)) {
                p.sendMessage(Component.text("Challenge complete: " + c.text(), NamedTextColor.GREEN));
                pr.nextChallenge();
                p.sendMessage(Game.button("[Next challenge]", "/challenge", "Get the next challenge"));
            } else {
                p.sendMessage(Component.text("Your challenge wants " + c.target() + ".", NamedTextColor.YELLOW));
            }
        }
    }

    /** Lists a group's operations by kind, e.g. "1 identity, 1 two-fold rotation, 2 mirrors". */
    static String describe(SymGroup g) {
        Map<String, Integer> sig = g.signature();
        String[][] names = {
                {"1", "identity", "identity"}, {"2", "two-fold rotation", "two-fold rotations"},
                {"3", "three-fold rotation", "three-fold rotations"}, {"4", "four-fold rotation", "four-fold rotations"},
                {"6", "six-fold rotation", "six-fold rotations"}, {"m", "mirror reflection", "mirror reflections"},
                {"-1", "inversion", "inversions"}, {"-3", "-3 rotoinversion", "-3 rotoinversions"},
                {"-4", "-4 rotoinversion", "-4 rotoinversions"}, {"-6", "-6 rotoinversion", "-6 rotoinversions"}};
        StringBuilder sb = new StringBuilder("Operations: ");
        boolean first = true;
        for (String[] n : names) {
            Integer c = sig.get(n[0]);
            if (c == null) continue;
            if (!first) sb.append(", ");
            sb.append(c).append(' ').append(c == 1 ? n[1] : n[2]);
            first = false;
        }
        return sb.append('.').toString();
    }

    private Optional<LiveRegion> freeLab(Player p) {
        Optional<LiveRegion> lab = game.regions().stream().filter(r -> r.area().free()).findFirst();
        if (lab.isEmpty()) return lab;
        if (game.progress(p).tier() < lab.get().area().tier()) {
            p.sendMessage(Component.text("The Free Lab unlocks at tier " + lab.get().area().tier() + ".", NamedTextColor.GRAY));
            return Optional.empty();
        }
        return lab;
    }

    private void setSymmetry(Player p, String description) {
        Optional<LiveRegion> lab = freeLab(p);
        if (lab.isEmpty()) return;
        Optional<ClaudeTutor> tutor = game.tutor();
        if (tutor.isEmpty()) {
            // Without the tutor, accept a symbol directly.
            applySymmetry(p, lab.get(), description.trim(), null);
            return;
        }
        if (game.waitingForTutor().putIfAbsent(p.getUuid(), true) != null) {
            p.sendMessage(Component.text("The tutor is still thinking.", NamedTextColor.GRAY));
            return;
        }
        p.sendMessage(Component.text("Working out which symmetry you mean...", NamedTextColor.GRAY));
        tutor.get().chooseSymmetry(description).whenComplete((choice, err) -> {
            game.waitingForTutor().remove(p.getUuid());
            if (err != null || choice == null || choice.isEmpty()) {
                p.sendMessage(Component.text("The tutor could not read that. Try a point-group symbol, like /symmetry 4mm.",
                        NamedTextColor.RED));
                return;
            }
            MinecraftServer.getSchedulerManager().scheduleNextTick(
                    () -> applySymmetry(p, lab.get(), choice.get().symbol(), choice.get().reason()));
        });
    }

    private void applySymmetry(Player p, LiveRegion lab, String symbol, String reason) {
        if (symbol.equalsIgnoreCase("none")) {
            p.sendMessage(Component.text("That does not match any of the 32 crystallographic point groups. "
                    + "Crystals can only have 1-, 2-, 3-, 4- and 6-fold rotation axes.", NamedTextColor.YELLOW));
            return;
        }
        Optional<PointGroups.Entry> entry = PointGroups.bySymbol(symbol);
        if (entry.isEmpty()) {
            p.sendMessage(Component.text("'" + symbol + "' is not a crystallographic point group.", NamedTextColor.RED));
            return;
        }
        PointGroups.Entry e = entry.get();
        if (reason != null) {
            p.sendMessage(Component.text("Tutor: ", NamedTextColor.LIGHT_PURPLE).append(Component.text(reason, NamedTextColor.WHITE)));
        }
        if (!e.group().fitsCubicGrid()) {
            p.sendMessage(Component.text(e.symbol() + " is a real crystal symmetry, but it cannot be built here: it needs a "
                    + (e.group().signature().containsKey("6") ? "6-fold" : "-6") + " axis, and turning a square grid by 60 degrees "
                    + "moves grid points off the grid. Hexagonal crystals need a hexagonal lattice.", NamedTextColor.YELLOW));
            return;
        }
        lab.setSymmetry(e.symbol(), e.generators());
        p.sendMessage(Component.text("The Free Lab now has symmetry " + e.symbol() + " (" + e.group().order()
                + " operations, " + e.system() + ").", NamedTextColor.GREEN));
        p.sendMessage(Component.text(describe(e.group()), NamedTextColor.WHITE));
        p.sendMessage(Component.text("Blocks already in the lab were not changed. ", NamedTextColor.GRAY)
                .append(Game.button("[Clear the lab]", "/clearlab", "Remove every block in the Free Lab")));
    }

    private void clearLab(Player p) {
        Optional<LiveRegion> lab = freeLab(p);
        if (lab.isEmpty()) return;
        int[] min = lab.get().region().min(), size = lab.get().region().size();
        for (int x = min[0]; x < min[0] + size[0]; x++) {
            for (int y = min[1]; y < min[1] + size[1]; y++) {
                for (int z = min[2]; z < min[2] + size[2]; z++) game.instance().setBlock(x, y, z, Block.AIR);
            }
        }
        p.sendMessage(Component.text("The Free Lab is empty.", NamedTextColor.GREEN));
    }

    private void challenge(Player p) {
        Optional<LiveRegion> lab = freeLab(p);
        if (lab.isEmpty()) return;
        List<Content.Challenge> cs = lab.get().area().challenges();
        int i = game.progress(p).challenge();
        if (i >= cs.size()) {
            p.sendMessage(Component.text("You have completed every challenge!", NamedTextColor.GREEN));
            return;
        }
        p.sendMessage(Component.text("Challenge " + (i + 1) + "/" + cs.size() + ": " + cs.get(i).text(), NamedTextColor.YELLOW));
        p.sendMessage(Component.text("Build it in the Free Lab (set its symmetry to 1 with /symmetry 1 to build freely), "
                + "then type /whatsymmetry.", NamedTextColor.GRAY));
    }
}
