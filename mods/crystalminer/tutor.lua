-- The in-game tutor, backed by the Claude API over raw HTTP (Luanti has no Anthropic SDK).
--
-- Claude only explains and translates. /ask answers from the reviewed text in content.lua;
-- /symmetry only picks a point-group symbol, which the symmetry engine then checks.
--
-- Loaded with loadfile(...)(symmetry, content).

local S, content = ...

local T = {}

-- Verified against https://platform.claude.com/docs/en/models/overview (October 2026).
T.MODEL = "claude-opus-5-5"
T.URL = "https://api.anthropic.com/v1/messages"
-- Hard cap on output per request (thinking plus reply). Opus 5.5 always thinks a little, even at
-- low effort; 4096 leaves ample room for an 80-word answer while bounding the cost of one request.
T.MAX_TOKENS = 4096

-- Cost and abuse limits.
T.COOLDOWN = 20        -- seconds between requests from one player
T.MAX_IN_FLIGHT = 3    -- requests waiting for the API at once, across the whole server
T.MAX_CHARS = 300      -- longest question or description a player may send

--- Number of characters (UTF-8 code points) in s.
function T.char_count(s)
	local _, n = s:gsub("[^\128-\191]", "")
	return n
end

--- nil if the text may be sent, otherwise a message for the player.
function T.check_length(text)
	if T.char_count(text) > T.MAX_CHARS then
		return "That is too long for the tutor. Please keep it under " .. T.MAX_CHARS .. " characters."
	end
	return nil
end

function T.new_limiter()
	return { last = {}, busy = {}, in_flight = 0 }
end

--- Reserves a request slot for a player. now is in seconds.
-- Returns true, or false and a friendly message.
function T.try_start(lim, name, now)
	if lim.busy[name] then
		return false, "The tutor is still thinking about your last question."
	end
	local last = lim.last[name]
	if last and now - last < T.COOLDOWN then
		local wait = math.ceil(T.COOLDOWN - (now - last))
		return false, "Give the tutor a moment: you can ask again in " .. wait .. " s."
	end
	if lim.in_flight >= T.MAX_IN_FLIGHT then
		return false, "The tutor is helping other players right now. Try again in a few seconds."
	end
	lim.busy[name] = true
	lim.last[name] = now
	lim.in_flight = lim.in_flight + 1
	return true
end

--- Releases the slot taken by try_start once the reply (or error) has arrived.
function T.finish(lim, name)
	if lim.busy[name] then
		lim.busy[name] = nil
		lim.in_flight = lim.in_flight - 1
	end
end

function T.tutor_system_prompt()
	local lines = {
		"You are the tutor inside crystalminer, a Luanti world where students learn symmetry, the "
			.. "foundation of crystallography. Each region of the world has a symmetry group: whatever a "
			.. "student builds there is copied by every operation of the group.",
		"",
		"How to answer:",
		"- Use only the reference below. If it does not cover the question, say you are not sure and "
			.. "suggest asking their teacher. Never guess or invent facts.",
		"- Reply in plain text for game chat: no markdown, no bullet symbols, at most 80 words.",
		"- Pitch the answer at the student's tier. Ideas from a higher tier than theirs can be mentioned "
			.. "as something they will meet later, without explaining them in full.",
		"- Do not give away quiz answers or the hidden symmetry of the Mystery Lab. Give a hint about what "
			.. "to build or look for instead.",
		"- If the question is not about symmetry, crystals or this world, say briefly that you can only "
			.. "help with those.",
		"",
		"REFERENCE",
		"",
		"Glossary:",
	}
	for _, g in ipairs(content.glossary) do lines[#lines + 1] = "- " .. g end
	lines[#lines + 1] = ""
	lines[#lines + 1] = "Introduction (tier 0):"
	for _, l in ipairs(content.intro) do lines[#lines + 1] = "- " .. l end
	for _, a in ipairs(content.regions) do
		lines[#lines + 1] = ""
		lines[#lines + 1] = "Region: " .. a.name .. " (tier " .. a.tier .. ", symmetry "
			.. (a.hidden and "hidden" or a.symbol) .. ")"
		local tiers = {}
		for t in pairs(a.explain or {}) do tiers[#tiers + 1] = t end
		table.sort(tiers)
		for _, t in ipairs(tiers) do
			lines[#lines + 1] = "  Tier " .. t .. ":"
			for _, l in ipairs(a.explain[t]) do lines[#lines + 1] = "  - " .. l end
		end
	end
	return table.concat(lines, "\n")
end

function T.symmetry_system_prompt()
	local symbols = {}
	for _, e in ipairs(S.catalog) do symbols[#symbols + 1] = e.symbol end
	return "A student describes a symmetry in words. Pick the crystallographic point group that matches "
		.. "the description. Use exactly one symbol from this list, or 'none' if nothing matches (for "
		.. "example a 5-fold axis, which no crystal can have):\n"
		.. table.concat(symbols, " ") .. " \n\n"
		.. "If the description is incomplete, choose the smallest group that has everything mentioned. "
		.. "For example \"a fourfold axis\" is 4, \"a fourfold axis with mirrors\" is 4mm, \"a mirror\" is m. "
		.. "Pick the group even if it cannot be built on a grid of cubes; the game checks that separately."
end

local function base(system, user_text)
	return {
		model = T.MODEL,
		max_tokens = T.MAX_TOKENS,
		-- https://platform.claude.com/docs/en/build-with-claude/effort (GA, no beta header)
		output_config = { effort = "low" },
		-- Server-side fallback (beta, needs the anthropic-beta header in T.headers): if a safety
		-- classifier declines, the API retries on a recommended fallback model.
		-- https://platform.claude.com/docs/en/build-with-claude/refusals-and-fallback#server-side-fallback
		fallbacks = "default",
		system = { { type = "text", text = system, cache_control = { type = "ephemeral" } } },
		messages = { { role = "user", content = user_text } },
	}
end

function T.ask_body(question, tier, region_name)
	return base(T.tutor_system_prompt(),
		"Student tier: " .. tier .. "\nStudent is in: " .. (region_name or "no region") .. "\nQuestion: " .. question)
end

function T.symmetry_body(description)
	local body = base(T.symmetry_system_prompt(), "Description: " .. description)
	-- Structured outputs, GA, no beta header:
	-- https://platform.claude.com/docs/en/build-with-claude/structured-outputs
	-- The field is "explanation", not "reason": the docs warn that a property asking for the
	-- model's reasoning can trigger a reasoning_extraction refusal; a short explanation is fine.
	body.output_config.format = {
		type = "json_schema",
		schema = {
			type = "object",
			properties = {
				symbol = {
					type = "string",
					description = "Hermann-Mauguin symbol of the crystallographic point group that matches the "
						.. "description, exactly as written in the list, or 'none' if no point group matches",
				},
				explanation = {
					type = "string",
					description = "One short sentence for a student explaining which words in the description "
						.. "led to this symbol. Do not list the group's operations.",
				},
			},
			required = { "symbol", "explanation" },
			additionalProperties = false,
		},
	}
	return body
end

function T.headers(api_key)
	return {
		"Content-Type: application/json",
		"x-api-key: " .. api_key,
		"anthropic-version: 2023-06-01",
		-- Required for the fallbacks field; must be exactly this date for fallbacks = "default".
		"anthropic-beta: server-side-fallback-2026-07-01",
	}
end

--- Text of a Messages API response, or nil and a message for the player.
function T.response_text(response)
	if type(response) ~= "table" then return nil, "The tutor sent an unreadable reply." end
	if response.type == "error" then
		local kind = response.error and response.error.type or "error"
		if kind == "rate_limit_error" or kind == "overloaded_error" then
			return nil, "The tutor is busy right now. Try again in a minute."
		end
		return nil, "The tutor is unavailable (" .. kind .. ")."
	end
	if response.stop_reason == "refusal" then
		return nil, "The tutor can't answer that one. Try asking about symmetry or crystals."
	end
	-- A cut-off reply may be half a sentence or broken JSON, so it is not shown.
	-- https://platform.claude.com/docs/en/build-with-claude/handling-stop-reasons
	if response.stop_reason == "max_tokens" or response.stop_reason == "model_context_window_exceeded" then
		return nil, "The tutor's answer was cut off. Try a shorter or simpler question."
	end
	local parts = {}
	for _, block in ipairs(response.content or {}) do
		if block.type == "text" then parts[#parts + 1] = block.text end
	end
	local text = table.concat(parts):gsub("^%s+", ""):gsub("%s+$", "")
	if text == "" then return nil, "The tutor had nothing to say. Try rephrasing your question." end
	return text
end

--- Sends a request. http is Luanti's HTTP API; encode/decode are core.write_json/parse_json.
-- callback(text_or_nil, error_message_or_nil)
function T.send(http, api_key, body, encode, decode, callback)
	local ok, data = pcall(encode, body)
	if not ok or type(data) ~= "string" then
		callback(nil, "The tutor could not send that question.")
		return
	end
	http.fetch({
		url = T.URL,
		method = "POST",
		extra_headers = T.headers(api_key),
		data = data,
		timeout = 90,
	}, function(res)
		if not res.succeeded then
			callback(nil, "The tutor could not be reached.")
			return
		end
		local ok, parsed = pcall(decode, res.data)
		if not ok or parsed == nil then
			callback(nil, "The tutor sent an unreadable reply.")
			return
		end
		callback(T.response_text(parsed))
	end)
end

return T
