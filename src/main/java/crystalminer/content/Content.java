package crystalminer.content;

import crystalminer.symmetry.SymmetryRegion;
import java.io.IOException;
import java.io.InputStream;
import java.io.UncheckedIOException;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.TreeMap;
import org.yaml.snakeyaml.LoaderOptions;
import org.yaml.snakeyaml.Yaml;
import org.yaml.snakeyaml.constructor.SafeConstructor;

/** All learning content, loaded from {@code content.yaml}. */
public record Content(
        Map<Integer, String> tierNames,
        List<String> intro,
        List<String> glossary,
        Area gate,
        List<Area> regions) {

    public record Question(String id, String text, List<String> options, int answer, String why) {}

    public record Challenge(String target, String text) {}

    /** A place in the world: the gate or a symmetry region. */
    public record Area(
            String id,
            String name,
            int tier,
            String symbol,
            List<String> generators,
            String anchor,
            int[] at,
            int[] size,
            int[] cell,
            int[] counts,
            String hidden,
            boolean free,
            Map<Integer, List<String>> explain,
            Map<Integer, List<Question>> quiz,
            List<Challenge> challenges) {

        public boolean isPeriodic() {
            return cell != null;
        }

        /** Size of the whole region in blocks. */
        public int[] extent() {
            return isPeriodic() ? new int[] {cell[0] * counts[0], cell[1] * counts[1], cell[2] * counts[2]} : size;
        }

        public SymmetryRegion buildRegion() {
            return buildRegion(generators);
        }

        public SymmetryRegion buildRegion(List<String> gens) {
            if (isPeriodic()) return SymmetryRegion.periodic(at, cell, counts, gens);
            return SymmetryRegion.point(at, size,
                    "floor".equals(anchor) ? SymmetryRegion.Anchor.FLOOR : SymmetryRegion.Anchor.CENTRE, gens);
        }

        /** The explanation for the highest tier the player has reached, plus all lower ones. */
        public List<String> explanationFor(int playerTier) {
            List<String> out = new ArrayList<>();
            explain.forEach((t, lines) -> {
                if (t <= playerTier) out.addAll(lines);
            });
            return out;
        }

        public List<Question> questions(int tier) {
            return quiz.getOrDefault(tier, List.of());
        }
    }

    public static Content load() {
        try (InputStream in = Content.class.getResourceAsStream("/content.yaml")) {
            if (in == null) throw new IllegalStateException("content.yaml not found on classpath");
            return parse(in);
        } catch (IOException e) {
            throw new UncheckedIOException(e);
        }
    }

    @SuppressWarnings("unchecked")
    static Content parse(InputStream in) {
        Map<String, Object> root = new Yaml(new SafeConstructor(new LoaderOptions())).load(in);
        Map<Integer, String> tiers = new TreeMap<>();
        ((Map<Object, Object>) root.get("tiers")).forEach((k, v) -> tiers.put(toInt(k), (String) v));
        List<Area> regions = new ArrayList<>();
        for (Object o : (List<Object>) root.get("regions")) regions.add(area((Map<String, Object>) o, -1));
        return new Content(tiers,
                (List<String>) root.get("intro"),
                (List<String>) root.get("glossary"),
                area((Map<String, Object>) root.get("gate"), 0),
                List.copyOf(regions));
    }

    @SuppressWarnings("unchecked")
    private static Area area(Map<String, Object> m, int defaultTier) {
        String id = (String) m.get("id");
        int tier = m.containsKey("tier") ? toInt(m.get("tier")) : defaultTier;
        Map<String, Object> periodic = (Map<String, Object>) m.get("periodic");

        Map<Integer, List<String>> explain = new TreeMap<>();
        Map<Object, Object> ex = (Map<Object, Object>) m.getOrDefault("explain", Map.of());
        ex.forEach((k, v) -> explain.put(toInt(k), List.copyOf((List<String>) v)));

        Map<Integer, List<Question>> quiz = new TreeMap<>();
        Map<Object, Object> qz = (Map<Object, Object>) m.getOrDefault("quiz", Map.of());
        qz.forEach((k, v) -> {
            int t = toInt(k);
            List<Question> qs = new ArrayList<>();
            List<Map<String, Object>> raw = (List<Map<String, Object>>) v;
            for (int i = 0; i < raw.size(); i++) {
                Map<String, Object> q = raw.get(i);
                List<String> options = ((List<Object>) q.get("options")).stream().map(String::valueOf).toList();
                qs.add(new Question(id + "." + t + "." + i, (String) q.get("q"), options,
                        toInt(q.get("answer")), (String) q.get("why")));
            }
            quiz.put(t, List.copyOf(qs));
        });

        List<Challenge> challenges = new ArrayList<>();
        for (Object o : (List<Object>) m.getOrDefault("challenges", List.of())) {
            Map<String, Object> c = (Map<String, Object>) o;
            challenges.add(new Challenge(String.valueOf(c.get("target")), (String) c.get("text")));
        }

        return new Area(id, (String) m.get("name"), tier,
                m.containsKey("symbol") ? String.valueOf(m.get("symbol")) : "",
                ((List<Object>) m.getOrDefault("generators", List.of())).stream().map(String::valueOf).toList(),
                (String) m.getOrDefault("anchor", "centre"),
                ints(m.get("at")),
                m.containsKey("size") ? ints(m.get("size")) : null,
                periodic == null ? null : ints(periodic.get("cell")),
                periodic == null ? null : ints(periodic.get("counts")),
                (String) m.get("hidden"),
                Boolean.TRUE.equals(m.get("free")),
                explain, quiz, List.copyOf(challenges));
    }

    public Optional<Area> region(String id) {
        if (gate.id().equals(id)) return Optional.of(gate);
        return regions.stream().filter(r -> r.id().equals(id)).findFirst();
    }

    /** Every quiz question that must be answered to complete a tier, keyed by id. */
    public Map<String, Question> questionsForTier(int tier) {
        Map<String, Question> out = new LinkedHashMap<>();
        for (Question q : gate.questions(tier)) out.put(q.id(), q);
        for (Area a : regions) for (Question q : a.questions(tier)) out.put(q.id(), q);
        return out;
    }

    public Optional<Question> question(String id) {
        for (int t : tierNames.keySet()) {
            Question q = questionsForTier(t).get(id);
            if (q != null) return Optional.of(q);
        }
        return Optional.empty();
    }

    public int maxTier() {
        return tierNames.keySet().stream().mapToInt(Integer::intValue).max().orElse(0);
    }

    private static int toInt(Object o) {
        return o instanceof Number n ? n.intValue() : Integer.parseInt(String.valueOf(o));
    }

    @SuppressWarnings("unchecked")
    private static int[] ints(Object o) {
        if (o == null) return null;
        return ((List<Object>) o).stream().mapToInt(Content::toInt).toArray();
    }
}
