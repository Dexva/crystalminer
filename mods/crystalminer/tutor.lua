-- The in-game tutor, backed by the Claude API over raw HTTP (Luanti has no Anthropic SDK).
--
-- Claude only explains and translates. /ask answers from the reviewed text in content.lua;
-- /symmetry only picks a point-group symbol, which the symmetry engine then checks.
--
-- Loaded with loadfile(...)(symmetry, content).

local S, content = ...

local T = {}

T.MODEL = "claude-opus-5-5"
T.URL = "https://api.anthropic.com/v1/messages"

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
		max_tokens = 16000,
		output_config = { effort = "low" },
		-- If a safety classifier declines, the API retries on a fallback model.
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
				reason = {
					type = "string",
					description = "One short sentence for a student explaining which words in the description "
						.. "led to this symbol. Do not list the group's operations.",
				},
			},
			required = { "symbol", "reason" },
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
	http.fetch({
		url = T.URL,
		method = "POST",
		extra_headers = T.headers(api_key),
		data = encode(body),
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
