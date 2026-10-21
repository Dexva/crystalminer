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
	T.eq(Tutor.URL, "https://api.anthropic.com/v1/messages")
	T.eq(b.model, "claude-opus-5-5")
	T.eq(b.max_tokens, 4096)
	T.eq(b.output_config.format, nil)
	T.eq(b.system[1].type, "text")
	T.eq(b.messages[1].role, "user")
	T.eq(#b.messages, 1)
	T.eq(b.output_config.effort, "low")
	T.eq(b.fallbacks, "default")
	T.eq(b.system[1].cache_control.type, "ephemeral")
	T.ok(b.messages[1].content:find("Square Court", 1, true))
	local hs = Tutor.headers("k")
	T.eq(#hs, 4)
	local h = table.concat(hs, "\n")
	T.ok(h:find("Content-Type: application/json", 1, true))
	T.ok(h:find("x-api-key: k", 1, true))
	T.ok(h:find("anthropic-version: 2023-06-01", 1, true))
	T.ok(h:find("anthropic-beta: server-side-fallback-2026-07-01", 1, true))
	for _, line in ipairs(hs) do T.ok(line:match("^[%w%-]+: %S"), "header format: " .. line) end
end)

T.run("symmetry request asks for a JSON schema with symbol and explanation", function()
	local b = Tutor.symmetry_body("a fourfold axis")
	T.eq(b.output_config.effort, "low")
	T.eq(b.fallbacks, "default")
	local f = b.output_config.format
	T.eq(f.type, "json_schema")
	T.eq(f.schema.type, "object")
	T.eq(f.schema.required[1], "symbol")
	T.eq(f.schema.required[2], "explanation")
	T.eq(f.schema.additionalProperties, false)
	T.eq(f.schema.properties.reason, nil)
	for k, prop in pairs(f.schema.properties) do
		T.eq(prop.type, "string", k)
		-- unsupported by structured outputs
		T.eq(prop.minLength, nil); T.eq(prop.maxLength, nil)
	end
	T.ok(b.messages[1].content:find("a fourfold axis", 1, true))
	-- ask bodies must not share the output_config table with symmetry bodies
	T.eq(Tutor.ask_body("x", 0, nil).output_config.format, nil)
end)

T.run("cut-off replies are not shown", function()
	local t, err = Tutor.response_text({ stop_reason = "max_tokens", content = { { type = "text", text = '{"symbol": "4' } } })
	T.ok(t == nil and err:find("cut off"))
	t = Tutor.response_text({ stop_reason = "end_turn", content = {
		{ type = "fallback", from = { model = "claude-opus-5-5" }, to = { model = "x" } },
		{ type = "text", text = "Hi" } } })
	T.eq(t, "Hi")
end)

T.run("question length is capped in characters, not bytes", function()
	T.eq(Tutor.char_count("abc"), 3)
	T.eq(Tutor.char_count("\u{00E9}\u{00E9}"), 2)
	T.eq(Tutor.check_length(string.rep("a", 300)), nil)
	T.ok(Tutor.check_length(string.rep("a", 301)):find("300"))
	T.eq(Tutor.check_length(string.rep("\u{00E9}", 300)), nil)
end)

T.run("cooldown per player and cap on requests in flight", function()
	local lim = Tutor.new_limiter()
	T.ok(Tutor.try_start(lim, "ann", 100))
	local ok, msg = Tutor.try_start(lim, "ann", 101)
	T.ok(not ok and msg:find("still thinking"))
	Tutor.finish(lim, "ann")
	ok, msg = Tutor.try_start(lim, "ann", 105)
	T.ok(not ok and msg:find("15 s"), msg)
	T.ok(Tutor.try_start(lim, "ann", 120))
	Tutor.finish(lim, "ann")
	-- server cap
	T.ok(Tutor.try_start(lim, "a", 200)); T.ok(Tutor.try_start(lim, "b", 200)); T.ok(Tutor.try_start(lim, "c", 200))
	ok, msg = Tutor.try_start(lim, "d", 200)
	T.ok(not ok and msg:find("other players"))
	T.eq(lim.last.d, nil)
	Tutor.finish(lim, "b")
	T.ok(Tutor.try_start(lim, "d", 201))
	-- finishing twice does not free an extra slot
	Tutor.finish(lim, "b")
	T.eq(lim.in_flight, 3)
end)

T.run("send reports an encode failure instead of hanging", function()
	local got
	Tutor.send({ fetch = function() error("should not fetch") end }, "k", {}, function() return nil, "bad" end,
		nil, function(t, e) got = e end)
	T.ok(got and got:find("could not send"))
	local req
	Tutor.send({ fetch = function(r, cb) req = r; cb({ succeeded = true, code = 200,
		data = '{"type":"message","stop_reason":"end_turn","content":[{"type":"text","text":"ok"}]}' }) end },
		"k", Tutor.ask_body("q", 0), function() return "{}" end,
		function(d) return { type = "message", stop_reason = "end_turn", content = { { type = "text", text = "ok" } } } end,
		function(t) got = t end)
	T.eq(req.method, "POST"); T.eq(req.url, Tutor.URL); T.eq(req.data, "{}"); T.eq(got, "ok")
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
