package crystalminer.tutor;

import com.anthropic.client.AnthropicClient;
import com.anthropic.client.okhttp.AnthropicOkHttpClient;
import com.anthropic.core.JsonSchemaLocalValidation;
import com.anthropic.errors.AnthropicServiceException;
import com.anthropic.errors.RateLimitException;
import com.anthropic.models.beta.AnthropicBeta;
import com.anthropic.models.beta.messages.BetaCacheControlEphemeral;
import com.anthropic.models.beta.messages.BetaFallbacksParam;
import com.anthropic.models.beta.messages.BetaMessage;
import com.anthropic.models.beta.messages.BetaOutputConfig;
import com.anthropic.models.beta.messages.BetaStopReason;
import com.anthropic.models.beta.messages.BetaTextBlockParam;
import com.anthropic.models.beta.messages.MessageCreateParams;
import com.anthropic.models.beta.messages.StructuredMessage;
import com.anthropic.models.beta.messages.StructuredMessageCreateParams;
import com.anthropic.models.beta.messages.StructuredOutputConfig;
import com.fasterxml.jackson.annotation.JsonPropertyDescription;
import crystalminer.content.Content;
import crystalminer.symmetry.PointGroups;
import java.util.List;
import java.util.Optional;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

/**
 * The in-game tutor, backed by the Claude API.
 *
 * <p>Claude only explains and translates. It answers from the reviewed content in content.yaml,
 * and for {@code /symmetry} it only picks a point-group symbol; the symmetry engine checks that
 * symbol and produces every statement about the resulting group.
 */
public final class ClaudeTutor {
    public static final String MODEL = "claude-opus-5-5";

    /** Claude's reading of a symmetry description. */
    public record SymmetryChoice(
            @JsonPropertyDescription("Hermann-Mauguin symbol of the crystallographic point group that matches the "
                    + "description, exactly as written in the list, or 'none' if no point group matches")
                    String symbol,
            @JsonPropertyDescription("One short sentence for a student explaining which words in the description "
                    + "led to this symbol. Do not list the group's operations.")
                    String reason) {}

    private final AnthropicClient client;
    private final String tutorSystem;
    private final String symmetrySystem;
    private final ExecutorService executor = Executors.newVirtualThreadPerTaskExecutor();

    private ClaudeTutor(AnthropicClient client, Content content) {
        this.client = client;
        this.tutorSystem = tutorSystemPrompt(content);
        this.symmetrySystem = symmetrySystemPrompt();
    }

    /** Empty when no Anthropic credentials are configured; the game then runs without the tutor. */
    public static Optional<ClaudeTutor> fromEnv(Content content) {
        String key = System.getenv("ANTHROPIC_API_KEY");
        String token = System.getenv("ANTHROPIC_AUTH_TOKEN");
        if ((key == null || key.isBlank()) && (token == null || token.isBlank())) return Optional.empty();
        return Optional.of(new ClaudeTutor(AnthropicOkHttpClient.fromEnv(), content));
    }

    /** Answers a student's question, grounded in the content they have unlocked. */
    public CompletableFuture<String> ask(String question, int tier, String regionName) {
        return CompletableFuture.supplyAsync(() -> {
            String context = "Student tier: " + tier
                    + "\nStudent is in: " + (regionName == null ? "no region" : regionName)
                    + "\nQuestion: " + question;
            MessageCreateParams params = askParams(tutorSystem, context);
            return call(() -> textOf(client.beta().messages().create(params)));
        }, executor);
    }

    /** Asks Claude which point group a description means. The caller must validate the symbol. */
    public CompletableFuture<Optional<SymmetryChoice>> chooseSymmetry(String description) {
        return CompletableFuture.supplyAsync(() -> {
            StructuredMessageCreateParams<SymmetryChoice> params = symmetryParams(symmetrySystem, description);
            StructuredMessage<SymmetryChoice> msg = client.beta().messages().create(params);
            if (msg.stopReason().map(BetaStopReason.REFUSAL::equals).orElse(false)) return Optional.empty();
            return msg.content().stream().flatMap(b -> b.text().stream()).findFirst().map(t -> t.text());
        }, executor);
    }

    static MessageCreateParams askParams(String system, String context) {
        return base()
                .systemOfBetaTextBlockParams(List.of(cachedText(system)))
                .addUserMessage(context)
                .build();
    }

    static StructuredMessageCreateParams<SymmetryChoice> symmetryParams(String system, String description) {
        return base()
                .systemOfBetaTextBlockParams(List.of(cachedText(system)))
                .addUserMessage("Description: " + description)
                .outputConfig(StructuredOutputConfig.<SymmetryChoice>builder()
                        .effort(BetaOutputConfig.Effort.LOW)
                        .format(SymmetryChoice.class, JsonSchemaLocalValidation.YES)
                        .build())
                .build();
    }

    private static MessageCreateParams.Builder base() {
        return MessageCreateParams.builder()
                .model(MODEL)
                .maxTokens(16000L)
                .outputConfig(BetaOutputConfig.builder().effort(BetaOutputConfig.Effort.LOW).build())
                // If a safety classifier declines, let the API retry on a fallback model.
                .addBeta(AnthropicBeta.SERVER_SIDE_FALLBACK_2026_07_01)
                .fallbacks(BetaFallbacksParam.ofDefault());
    }

    private static BetaTextBlockParam cachedText(String text) {
        return BetaTextBlockParam.builder()
                .text(text)
                .cacheControl(BetaCacheControlEphemeral.builder().build())
                .build();
    }

    private static String textOf(BetaMessage msg) {
        if (msg.stopReason().map(BetaStopReason.REFUSAL::equals).orElse(false)) {
            return "The tutor can't answer that one. Try asking about symmetry or crystals.";
        }
        StringBuilder sb = new StringBuilder();
        msg.content().forEach(b -> b.text().ifPresent(t -> sb.append(t.text())));
        String s = sb.toString().strip();
        return s.isEmpty() ? "The tutor had nothing to say. Try rephrasing your question." : s;
    }

    private interface Call {
        String run();
    }

    private static String call(Call c) {
        try {
            return c.run();
        } catch (RateLimitException e) {
            return "The tutor is busy right now. Try again in a minute.";
        } catch (AnthropicServiceException e) {
            return "The tutor is unavailable (" + e.statusCode() + ").";
        } catch (RuntimeException e) {
            return "The tutor could not be reached.";
        }
    }

    static String tutorSystemPrompt(Content content) {
        StringBuilder sb = new StringBuilder();
        sb.append("""
                You are the tutor inside crystalminer, a Minecraft world where students learn symmetry, the \
                foundation of crystallography. Each region of the world has a symmetry group: whatever a student \
                builds there is copied by every operation of the group.

                How to answer:
                - Use only the reference below. If it does not cover the question, say you are not sure and \
                suggest asking their teacher. Never guess or invent facts.
                - Reply in plain text for Minecraft chat: no markdown, no bullet symbols, at most 80 words.
                - Pitch the answer at the student's tier. Ideas from a higher tier than theirs can be mentioned \
                as something they will meet later, without explaining them in full.
                - Do not give away quiz answers or the hidden symmetry of the Mystery Lab. Give a hint about \
                what to build or look for instead.
                - If the question is not about symmetry, crystals or this world, say briefly that you can only \
                help with those.

                REFERENCE
                """);
        sb.append("\nGlossary:\n");
        content.glossary().forEach(g -> sb.append("- ").append(g).append('\n'));
        sb.append("\nIntroduction (tier 0):\n");
        content.intro().forEach(l -> sb.append("- ").append(l).append('\n'));
        for (Content.Area a : content.regions()) {
            boolean hidden = a.hidden() != null;
            sb.append("\nRegion: ").append(a.name())
                    .append(" (tier ").append(a.tier()).append(", symmetry ")
                    .append(hidden ? "hidden" : a.symbol()).append(")\n");
            a.explain().forEach((t, lines) -> {
                sb.append("  Tier ").append(t).append(":\n");
                lines.forEach(l -> sb.append("  - ").append(l).append('\n'));
            });
        }
        return sb.toString();
    }

    static String symmetrySystemPrompt() {
        StringBuilder sb = new StringBuilder("""
                A student describes a symmetry in words. Pick the crystallographic point group that matches \
                the description. Use exactly one symbol from this list, or 'none' if nothing matches \
                (for example a 5-fold axis, which no crystal can have):
                """);
        for (PointGroups.Entry e : PointGroups.all()) sb.append(e.symbol()).append(' ');
        sb.append("""

                If the description is incomplete, choose the smallest group that has everything mentioned. \
                For example "a fourfold axis" is 4, "a fourfold axis with mirrors" is 4mm, "a mirror" is m. \
                Pick the group even if it cannot be built on a block grid; the game checks that separately.
                """);
        return sb.toString();
    }
}
