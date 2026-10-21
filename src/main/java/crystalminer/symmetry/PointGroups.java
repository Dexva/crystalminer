package crystalminer.symmetry;

import java.util.Collection;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

/**
 * The 32 crystallographic point groups, each given by generators in Jones notation.
 *
 * <p>Crystal axes: z is the main (vertical) axis. The 25 groups that fit a cubic grid use an
 * orthonormal basis, with trigonal 3-fold axes along the cube diagonal [111]. The 7 hexagonal
 * groups need a 6-fold or -6 operation, which only exists in a hexagonal basis (a and b at 120°);
 * they are listed in that basis so tests can show that none of them fits the block grid.
 */
public final class PointGroups {
    public record Entry(String symbol, String system, List<String> generators, boolean hexagonalBasis) {
        public SymGroup group() {
            return SymGroup.pointGroup(generators.stream().map(SymOp::parse).toList());
        }
    }

    private static final Map<String, Entry> CATALOG = new LinkedHashMap<>();

    private static void add(String symbol, String system, String... generators) {
        CATALOG.put(symbol, new Entry(symbol, system, List.of(generators), false));
    }

    private static void addHex(String symbol, String... generators) {
        CATALOG.put(symbol, new Entry(symbol, "hexagonal", List.of(generators), true));
    }

    static {
        add("1", "triclinic");
        add("-1", "triclinic", "-x,-y,-z");
        add("2", "monoclinic", "-x,-y,z");
        add("m", "monoclinic", "x,-y,z");
        add("2/m", "monoclinic", "-x,-y,z", "x,y,-z");
        add("222", "orthorhombic", "-x,-y,z", "-x,y,-z");
        add("mm2", "orthorhombic", "x,-y,z", "-x,y,z");
        add("mmm", "orthorhombic", "-x,y,z", "x,-y,z", "x,y,-z");
        add("4", "tetragonal", "-y,x,z");
        add("-4", "tetragonal", "y,-x,-z");
        add("4/m", "tetragonal", "-y,x,z", "x,y,-z");
        add("422", "tetragonal", "-y,x,z", "-x,y,-z");
        add("4mm", "tetragonal", "-y,x,z", "x,-y,z");
        add("-42m", "tetragonal", "y,-x,-z", "-x,y,-z");
        add("4/mmm", "tetragonal", "-y,x,z", "x,-y,z", "x,y,-z");
        add("3", "trigonal", "z,x,y");
        add("-3", "trigonal", "-z,-x,-y");
        add("32", "trigonal", "z,x,y", "-y,-x,-z");
        add("3m", "trigonal", "z,x,y", "y,x,z");
        add("-3m", "trigonal", "-z,-x,-y", "y,x,z");
        add("23", "cubic", "z,x,y", "-x,-y,z");
        add("m-3", "cubic", "z,x,y", "-x,-y,z", "-x,-y,-z");
        add("432", "cubic", "z,x,y", "-y,x,z");
        add("-43m", "cubic", "z,x,y", "y,-x,-z");
        add("m-3m", "cubic", "z,x,y", "-y,x,z", "-x,-y,-z");
        addHex("6", "x-y,x,z");
        addHex("-6", "-y,x-y,z", "x,y,-z");
        addHex("6/m", "x-y,x,z", "x,y,-z");
        addHex("622", "x-y,x,z", "y,x,-z");
        addHex("6mm", "x-y,x,z", "-y,-x,z");
        addHex("-62m", "-y,x-y,z", "x,y,-z", "-y,-x,z");
        addHex("6/mmm", "x-y,x,z", "y,x,-z", "x,y,-z");
    }

    private PointGroups() {}

    public static Collection<Entry> all() {
        return CATALOG.values();
    }

    public static Optional<Entry> bySymbol(String symbol) {
        return Optional.ofNullable(CATALOG.get(normalize(symbol)));
    }

    /** Names a point group from its operation-kind signature, whatever its orientation. */
    public static Optional<Entry> identify(SymGroup group) {
        Map<String, Integer> sig = group.linearParts().signature();
        return CATALOG.values().stream().filter(e -> e.group().signature().equals(sig)).findFirst();
    }

    /** Accepts common spellings: "m3m" or "m-3m", "4/mmm", "-4 2 m" and so on. */
    public static String normalize(String symbol) {
        String s = symbol.trim().replace(" ", "").replace("‾", "-").replace("−", "-");
        if (CATALOG.containsKey(s)) return s;
        for (String key : CATALOG.keySet()) {
            if (key.replace("-", "").equals(s.replace("-", ""))) return key;
        }
        return s;
    }
}
