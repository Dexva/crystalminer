-- Minimal test harness for plain LuaJIT.
local T = { passed = 0, failed = 0 }

function T.eq(actual, expected, msg)
	if actual ~= expected then
		error((msg or "") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
	end
end

function T.ok(cond, msg)
	if not cond then error(msg or "expected true", 2) end
end

function T.fails(fn, msg)
	if pcall(fn) then error((msg or "") .. ": expected an error", 2) end
end

function T.run(name, fn)
	local ok, err = pcall(fn)
	if ok then
		T.passed = T.passed + 1
		print("  ok    " .. name)
	else
		T.failed = T.failed + 1
		print("  FAIL  " .. name .. "\n        " .. tostring(err))
	end
end

function T.finish()
	print(string.format("%d passed, %d failed", T.passed, T.failed))
	os.exit(T.failed == 0 and 0 or 1)
end

return T
