local Players = game:GetService("Players")

local RevealHighlights = {}

function RevealHighlights.show(hiders, opts)
	opts = opts or {}
	local color = opts.color or Color3.fromRGB(0, 255, 80)
	local hls = {}
	for _, h in ipairs(hiders) do
		local char = h.Character
		if char then
			local hl = Instance.new("Highlight")
			hl.Name = "RoundEndReveal"
			hl.FillColor = color
			hl.FillTransparency = 0.5
			hl.OutlineColor = color
			hl.OutlineTransparency = 0
			hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			hl.Adornee = char
			hl.Parent = char
			table.insert(hls, hl)
		end
	end
	return hls
end

function RevealHighlights.clear(hls)
	for _, hl in ipairs(hls) do
		pcall(function()
			hl:Destroy()
		end)
	end
end

-- Defensive: destroy EVERY "RoundEndReveal" highlight currently on any player's character (not just a
-- tracked set). Guarantees no reveal highlight lingers into a phase where it shouldn't show -- e.g. the
-- Reverse Race hide phase, where reveal highlights should only ever appear during the reveal stage.
function RevealHighlights.clearAll()
	for _, plr in ipairs(Players:GetPlayers()) do
		local char = plr.Character
		if char then
			for _, d in ipairs(char:GetDescendants()) do
				if d:IsA("Highlight") and d.Name == "RoundEndReveal" then
					pcall(function()
						d:Destroy()
					end)
				end
			end
		end
	end
end

return RevealHighlights
