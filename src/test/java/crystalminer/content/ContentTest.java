package crystalminer.content;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import crystalminer.symmetry.PointGroups;
import crystalminer.symmetry.SymmetryRegion;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.Test;

/** Checks that the hand-written content agrees with the symmetry engine. */
class ContentTest {
    private final Content content = Content.load();

    /** Crystal class (point group of the linear parts) of each space-group region. */
    private static final Map<String, String> SPACE_GROUP_CLASS = Map.of("P1", "1", "P2_1", "2", "Pa", "m");

    @Test
    void everyRegionBuildsAndHasTheSymmetryItsNameClaims() {
        for (Content.Area a : content.regions()) {
            SymmetryRegion r = a.buildRegion();
            String identified = PointGroups.identify(r.group().linearParts()).orElseThrow().symbol();
            String expected = a.hidden() != null ? a.hidden()
                    : a.isPeriodic() ? SPACE_GROUP_CLASS.get(a.symbol())
                    : a.symbol();
            assertEquals(expected, identified, a.id());
        }
    }

    @Test
    void groupOrdersStatedInQuizzesMatchTheEngine() {
        // Answers that are group orders ("how many blocks appear"), checked against the engine.
        assertEquals(2, order("mirror_plaza"));
        assertEquals(2, order("twofold_yard"));
        assertEquals(4, order("fourfold_tower"));
        assertEquals(4, order("twin_mirrors"));
        assertEquals(4, order("monoclinic_cube"));
        assertEquals(8, order("square_court"));
        assertEquals(8, order("orthorhombic_cube"));
        assertEquals(3, order("diagonal_cube"));
        assertEquals(48, order("kaleidoscope"));
        Content.Area hall = content.region("translation_hall").orElseThrow();
        assertEquals(27, hall.buildRegion().images(hall.at()[0], hall.at()[1], hall.at()[2]).size());
    }

    private int order(String id) {
        return content.region(id).orElseThrow().buildRegion().group().order();
    }

    @Test
    void quizAnswersPointAtAnOption() {
        for (int t = 0; t <= content.maxTier(); t++) {
            for (Content.Question q : content.questionsForTier(t).values()) {
                assertTrue(q.answer() >= 0 && q.answer() < q.options().size(), q.id());
                assertFalse(q.why() == null || q.why().isBlank(), q.id());
            }
        }
    }

    @Test
    void everyTierBelowTheTopHasQuestions() {
        for (int t = 0; t < content.maxTier(); t++) {
            assertFalse(content.questionsForTier(t).isEmpty(), "tier " + t);
        }
    }

    @Test
    void regionsDoNotOverlap() {
        List<Content.Area> all = new java.util.ArrayList<>(content.regions());
        for (int i = 0; i < all.size(); i++) {
            for (int j = i + 1; j < all.size(); j++) {
                assertFalse(overlap(all.get(i), all.get(j), 3), all.get(i).id() + " / " + all.get(j).id());
            }
        }
    }

    private static boolean overlap(Content.Area a, Content.Area b, int margin) {
        for (int k = 0; k < 3; k += 2) { // horizontal axes only
            int a0 = a.at()[k] - margin, a1 = a.at()[k] + a.extent()[k] + margin;
            int b0 = b.at()[k], b1 = b.at()[k] + b.extent()[k];
            if (a1 <= b0 || b1 <= a0) return false;
        }
        return true;
    }

    @Test
    void challengeTargetsCanBeBuilt() {
        for (Content.Area a : content.regions()) {
            for (Content.Challenge c : a.challenges()) {
                PointGroups.Entry e = PointGroups.bySymbol(c.target()).orElseThrow();
                assertTrue(e.group().fitsCubicGrid(), c.target());
            }
        }
    }

    @Test
    void answeringEveryQuestionWalksThroughTheTiers() {
        Progress p = new Progress();
        for (int t = 0; t < content.maxTier(); t++) {
            assertEquals(t, p.tier());
            List<String> ids = List.copyOf(content.questionsForTier(t).keySet());
            for (int i = 0; i < ids.size(); i++) {
                boolean levelled = p.recordCorrect(content, ids.get(i));
                assertEquals(i == ids.size() - 1, levelled);
            }
        }
        assertEquals(content.maxTier(), p.tier());
    }

    @Test
    void explanationsGrowWithTier() {
        Content.Area mirror = content.region("mirror_plaza").orElseThrow();
        assertTrue(mirror.explanationFor(1).size() < mirror.explanationFor(3).size());
        assertTrue(mirror.explanationFor(0).isEmpty());
    }
}
