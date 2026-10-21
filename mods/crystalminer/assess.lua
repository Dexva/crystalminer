-- Measuring learning: the same short test before and after playing, predictions players make in
-- the regions, and the discoveries they find. Pure Lua (no Luanti calls), so it can be tested.
--
-- A record belongs to one player but carries only an anonymous id; exports never contain names.
-- record = { id = "a1b2c3d4", pre = { [item_id] = { choice, correct, t } }, post = {...},
--            predictions = { { region, guess, actual, operations, t } } }

local A = {}

function A.new(id)
	return { id = id, pre = {}, post = {}, predictions = {} }
end

local function item_by_id(items, id)
	for _, it in ipairs(items) do
		if it.id == id then return it end
	end
end

--- Records one answer. choice is the 0-based option index; the last option is "I don't know".
function A.answer(rec, phase, items, item_id, choice, t)
	local it = item_by_id(items, item_id)
	if not it then return false end
	rec[phase][item_id] = { choice = choice, correct = choice == it.answer, t = t or 0 }
	return true
end

--- The first item of a phase not yet answered, or nil when the phase is complete.
function A.next_item(rec, phase, items)
	for _, it in ipairs(items) do
		if not rec[phase][it.id] then return it end
	end
end

function A.complete(rec, phase, items)
	return A.next_item(rec, phase, items) == nil
end

--- Correct answers and number of items in a phase (counting only answered items as attempted).
function A.score(rec, phase, items)
	local correct = 0
	for _, it in ipairs(items) do
		local a = rec[phase][it.id]
		if a and a.correct then correct = correct + 1 end
	end
	return correct, #items
end

--- Normalized gain (Hake): (post - pre) / (max - pre), the fraction of the possible improvement
-- that was achieved. Undefined (nil) when the pre-test score was already the maximum.
function A.gain(pre, post, max)
	if pre >= max then return nil end
	return (post - pre) / (max - pre)
end

function A.record_prediction(rec, region, guess, actual, operations, t)
	rec.predictions[#rec.predictions + 1] = { region = region, guess = guess, actual = actual,
		operations = operations, t = t or 0 }
end

--- Class summary over complete records: counts, mean scores and mean normalized gain (paired).
function A.summary(records, items)
	local n_pre, n_post, n_pair, sum_pre, sum_post, sum_gain, n_gain = 0, 0, 0, 0, 0, 0, 0
	local pair_pre, pair_post = 0, 0
	for _, rec in pairs(records) do
		local pre_done, post_done = A.complete(rec, "pre", items), A.complete(rec, "post", items)
		local pre, max = A.score(rec, "pre", items)
		local post = A.score(rec, "post", items)
		if pre_done then n_pre, sum_pre = n_pre + 1, sum_pre + pre end
		if post_done then n_post, sum_post = n_post + 1, sum_post + post end
		if pre_done and post_done then
			n_pair, pair_pre, pair_post = n_pair + 1, pair_pre + pre, pair_post + post
			local g = A.gain(pre, post, max)
			if g then n_gain, sum_gain = n_gain + 1, sum_gain + g end
		end
	end
	local function mean(s, n) return n > 0 and s / n or nil end
	return {
		items = #items, n_pre = n_pre, n_post = n_post, n_paired = n_pair,
		mean_pre = mean(sum_pre, n_pre), mean_post = mean(sum_post, n_post),
		paired_mean_pre = mean(pair_pre, n_pair), paired_mean_post = mean(pair_post, n_pair),
		mean_gain = mean(sum_gain, n_gain), n_gain = n_gain,
	}
end

local function csv_field(v)
	v = tostring(v == nil and "" or v)
	if v:find('[,"\n]') then v = '"' .. v:gsub('"', '""') .. '"' end
	return v
end

local function csv(rows)
	local out = {}
	for _, r in ipairs(rows) do
		local f = {}
		for i, v in ipairs(r) do f[i] = csv_field(v) end
		out[#out + 1] = table.concat(f, ",")
	end
	return table.concat(out, "\n") .. "\n"
end

--- One row per answer: participant, phase, item, tag, choice, correct, unix time.
function A.tests_csv(records, items)
	local rows = { { "participant", "phase", "item", "tag", "choice", "correct", "time" } }
	local ids = {}
	for _, rec in pairs(records) do ids[#ids + 1] = rec end
	table.sort(ids, function(a, b) return a.id < b.id end)
	for _, rec in ipairs(ids) do
		for _, phase in ipairs({ "pre", "post" }) do
			for _, it in ipairs(items) do
				local a = rec[phase][it.id]
				if a then
					rows[#rows + 1] = { rec.id, phase, it.id, it.tag, a.choice, a.correct and 1 or 0, a.t }
				end
			end
		end
	end
	return csv(rows)
end

--- One row per prediction: participant, region, guess, actual, operations, correct, time.
function A.predictions_csv(records)
	local rows = { { "participant", "region", "guess", "actual", "operations", "correct", "time" } }
	local ids = {}
	for _, rec in pairs(records) do ids[#ids + 1] = rec end
	table.sort(ids, function(a, b) return a.id < b.id end)
	for _, rec in ipairs(ids) do
		for _, p in ipairs(rec.predictions) do
			rows[#rows + 1] = { rec.id, p.region, p.guess, p.actual, p.operations, p.guess == p.actual and 1 or 0, p.t }
		end
	end
	return csv(rows)
end

--- Answer options for "how many blocks?": the true count plus up to three plausible wrong ones,
-- including the group's number of operations when the block sits on a symmetry element.
function A.count_options(actual, operations)
	local set, list = {}, {}
	local function add(n)
		n = math.floor(n)
		if n >= 1 and not set[n] then
			set[n] = true
			list[#list + 1] = n
		end
	end
	add(actual)
	add(operations)
	add(actual * 2)
	if actual % 2 == 0 then add(actual / 2) end
	add(actual + 1)
	add(1)
	local keep = { actual }
	for _, n in ipairs(list) do
		if n ~= actual and #keep < 4 then keep[#keep + 1] = n end
	end
	table.sort(keep)
	return keep
end

return A
