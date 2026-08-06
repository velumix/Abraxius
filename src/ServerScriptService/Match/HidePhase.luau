local MatchState = require(script.Parent:WaitForChild("MatchState"))

local found = MatchState.found
local hiderPlacedAt = MatchState.hiderPlacedAt
local roles = MatchState.roles
local diedConns = MatchState.diedConns

local HidePhase = {}

-- Places a list of players onto the map as hiders: screen-fade in, per-hider
-- map placement with hider walkspeed, role announce, and a death hook with a
-- streaming-fall grace window. Mode-specific behavior is passed via opts:
--   opts.placement      Placement service
--   opts.roleAnnounce   RoleAnnounce remote
--   opts.screenFade     ScreenFade remote
--   opts.mapTarget      function(index) -> CFrame
--   opts.walkspeed      number
--   opts.gracePeriod    number? (default 2)
--   opts.isActivePhase  function() -> boolean (is placement/death still relevant)
--   opts.onDeath        function(player)? (what to do on a real death; nil = nothing)
function HidePhase.placeHiders(hiders, opts)
	local Placement = opts.placement
	local RoleAnnounce = opts.roleAnnounce
	local ScreenFade = opts.screenFade
	local mapTarget = opts.mapTarget
	local walkspeed = opts.walkspeed
	local gracePeriod = opts.gracePeriod or 2
	local isActivePhase = opts.isActivePhase
	local onDeath = opts.onDeath

	for _, h in ipairs(hiders) do
		ScreenFade:FireClient(h, "in", { fadeTime = 0.25 })
	end
	task.wait(0.3)
	for i, h in ipairs(hiders) do
		if i > 1 then
			task.wait(0.05)
		end
		local hider, target = h, mapTarget(i)
		Placement.setDesiredPlacement(hider, target, {
			convert = true,
			valid = function(p)
				return isActivePhase() and roles[p] == "Hider" and not found[p]
			end,
			onPlaced = function(p)
				local c = p.Character
				local hum = c and c:FindFirstChildOfClass("Humanoid")
				if hum then
					hum.WalkSpeed = walkspeed
				end
				hiderPlacedAt[p] = os.clock()
			end,
		})
		RoleAnnounce:FireClient(h, "Hider")
		do
			local hchar = h.Character
			local hhum = hchar and hchar:FindFirstChildOfClass("Humanoid")
			if hhum then
				hhum.WalkSpeed = walkspeed
			end
		end
		local char = h.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum then
			local hider2 = h
			table.insert(
				diedConns,
				hum.Died:Connect(function()
					if not isActivePhase() then
						return
					end
					local placedAt = hiderPlacedAt[hider2]
					if placedAt and (os.clock() - placedAt) < gracePeriod and not found[hider2] and Placement.desired[hider2] then
						warn("[HidePhase] streaming-fall grace: " .. hider2.Name .. " died <" .. gracePeriod .. "s after placement; re-placing instead of eliminating")
						local intent = Placement.desired[hider2]
						if intent then
							intent.placed = false
							intent.onPlacedFired = false
						end
						hiderPlacedAt[hider2] = nil
						return
					end
					if onDeath then
						onDeath(hider2)
					end
				end)
			)
		end
	end
end

return HidePhase
