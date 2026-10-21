package crystalminer.tutor;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import crystalminer.content.Content;
import crystalminer.symmetry.PointGroups;
import org.junit.jupiter.api.Test;

/** Checks the tutor's requests without calling the API. */
class ClaudeTutorTest {
    private final Content content = Content.load();

    @Test
    void referenceCoversEveryRegionButNotTheHiddenAnswer() {
        String prompt = ClaudeTutor.tutorSystemPrompt(content);
        for (Content.Area a : content.regions()) assertTrue(prompt.contains(a.name()), a.name());
        Content.Area mystery = content.region("mystery_lab").orElseThrow();
        assertFalse(prompt.contains(mystery.hidden()), "the tutor must not know the Mystery Lab answer");
    }

    @Test
    void symmetryPromptListsAll32Groups() {
        String prompt = ClaudeTutor.symmetrySystemPrompt();
        for (PointGroups.Entry e : PointGroups.all()) assertTrue(prompt.contains(e.symbol() + " "), e.symbol());
    }

    @Test
    void requestsBuildWithModelEffortAndFallbacks() {
        String ask = ClaudeTutor.askParams("system", "question").toString();
        assertTrue(ask.contains(ClaudeTutor.MODEL));
        assertTrue(ask.contains("fallbacks"));
        assertTrue(ask.contains("low"));
        String sym = ClaudeTutor.symmetryParams("system", "a fourfold axis").toString();
        assertTrue(sym.contains("json_schema"));
    }
}
