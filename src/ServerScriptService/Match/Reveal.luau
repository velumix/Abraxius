local Reveal = {}

function Reveal.forSeeker(buyer, mode, alive, revealRemote, duration)
	if #alive == 0 then
		return 0
	end

	local targets = {}
	if mode == "all" then
		targets = alive
	else
		local sChar = buyer.Character
		local sRoot = sChar and sChar:FindFirstChild("HumanoidRootPart")
		if sRoot then
			local best, bestDist = nil, math.huge
			for _, h in ipairs(alive) do
				local hChar = h.Character
				local hRoot = hChar and hChar:FindFirstChild("HumanoidRootPart")
				if hRoot then
					local d = (hRoot.Position - sRoot.Position).Magnitude
					if d < bestDist then
						best, bestDist = h, d
					end
				end
			end
			if best then
				targets = { best }
			end
		end
		if #targets == 0 then
			targets = { alive[math.random(1, #alive)] }
		end
	end

	local ids = {}
	for _, h in ipairs(targets) do
		table.insert(ids, h.UserId)
	end
	revealRemote:FireClient(buyer, { mode = "highlight", revealMode = mode, userIds = ids, duration = duration })

	for _, h in ipairs(targets) do
		revealRemote:FireClient(h, { mode = "revealed", duration = duration })
	end

	print(string.format("[MatchManager] %s revealed %d hider(s) via %s reveal", buyer.Name, #targets, mode))
	return #targets
end

function Reveal.inRadius(origin, radius, alive, activeSeekers, revealRemote, duration)
	local targets = {}
	for _, h in ipairs(alive) do
		local char = h.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if root and (root.Position - origin).Magnitude <= radius then
			table.insert(targets, h)
		end
	end

	if #targets == 0 then
		return 0
	end

	local ids = {}
	for _, h in ipairs(targets) do
		table.insert(ids, h.UserId)
	end

	for _, s in ipairs(activeSeekers) do
		revealRemote:FireClient(s, {
			mode = "paintbucket",
			revealMode = (#targets > 1) and "all" or "one",
			userIds = ids,
			duration = duration,
		})
	end

	for _, h in ipairs(targets) do
		revealRemote:FireClient(h, { mode = "revealed", duration = duration })
	end

	print(string.format("[MatchManager] Paint-bucket splash revealed %d hider(s)", #targets))
	return #targets
end

return Reveal
