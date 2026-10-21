package.path = "mods/crystalminer/?.lua;tests/?.lua;" .. package.path
local S = require("symmetry")
local content = require("content")
local Tutor = loadfile("mods/crystalminer/tutor.lua")(S, content)
local T = require("testlib")

print("tutor")

T.run("reference covers every region but not the Mystery Lab answer", function()
	local prompt = Tutor.tutor_system_prompt()
	for _, a in ipairs(content.regions) do T.ok(prompt:find(a.name, 1, true), a.name) end
	for _, a in ipairs(content.regions) do
		if a.hidden then T.ok(not prompt:find(a.hidden, 1, true), "hidden answer leaked: " .. a.hidden) end
	end
end)

T.run("symmetry prompt lists all 32 groups", function()
	local prompt = Tutor.symmetry_system_prompt()
	for _, e in ipairs(S.catalog) do T.ok(prompt:find(" " .. e.symbol .. " ", 1, true) or prompt:find("\n" .. e.symbol .. " ", 1, true), e.symbol) end
end)

T.run("ask request uses the model, low effort, fallbacks and a cached system prompt", function()
	local b = Tutor.ask_body("Why?", 2, "Square Court")
	T.eq(b.model, "claude-opus-5-5")
	T.eq(b.output_config.effort, "low")
	T.eq(b.fallbacks, "default")
	T.eq(b.system[1].cache_control.type, "ephemeral")
	T.ok(b.messages[1].content:find("Square Court", 1, true))
	local h = table.concat(Tutor.headers("k"), "\n")
	T.ok(h:find("anthropic-version: 2023-06-01", 1, true) and h:find("server-side-fallback-2026-07-01", 1, true))
end)

T.run("symmetry request asks for a JSON schema with symbol and reason", function()
	local b = Tutor.symmetry_body("a fourfold axis")
	T.eq(b.output_config.format.type, "json_schema")
	T.eq(b.output_config.format.schema.required[1], "symbol")
	T.eq(b.output_config.format.schema.additionalProperties, false)
end)

T.run("responses are read safely", function()
	T.eq(Tutor.response_text({ content = { { type = "text", text = "  A mirror.  " } }, stop_reason = "end_turn" }), "A mirror.")
	local t, err = Tutor.response_text({ stop_reason = "refusal", content = {} })
	T.ok(t == nil and err:find("can't answer"))
	t, err = Tutor.response_text({ type = "error", error = { type = "rate_limit_error" } })
	T.ok(t == nil and err:find("busy"))
	t, err = Tutor.response_text({ content = { { type = "thinking", thinking = "" } }, stop_reason = "end_turn" })
	T.ok(t == nil and err:find("nothing to say"))
end)

T.finish()
