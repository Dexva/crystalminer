package crystalminer.content;

import java.util.HashSet;
import java.util.Set;

/** One player's progress: their tier, which questions they have answered, and their challenge. */
public final class Progress {
    private int tier;
    private final Set<String> answered = new HashSet<>();
    private int challenge;

    public int tier() {
        return tier;
    }

    public boolean hasAnswered(String questionId) {
        return answered.contains(questionId);
    }

    public int challenge() {
        return challenge;
    }

    public void nextChallenge() {
        challenge++;
    }

    /**
     * Records a correct answer. Returns true if this completed the player's current tier, in which
     * case the tier has been raised.
     */
    public boolean recordCorrect(Content content, String questionId) {
        answered.add(questionId);
        if (tier < content.maxTier() && answered.containsAll(content.questionsForTier(tier).keySet())) {
            tier++;
            return true;
        }
        return false;
    }

    /** Questions in the current tier still to answer. */
    public int remaining(Content content) {
        int n = 0;
        for (String id : content.questionsForTier(tier).keySet()) if (!answered.contains(id)) n++;
        return n;
    }

    /** For teachers and demos: jump to a tier directly. */
    public void setTier(int tier) {
        this.tier = tier;
    }
}
