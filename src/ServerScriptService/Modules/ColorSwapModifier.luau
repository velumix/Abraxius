local ServerStorage = game:GetService("ServerStorage")
local ModifierUtils = require(script.Parent:WaitForChild("ModifierUtils"))
local StudsConverter = require(ServerStorage:WaitForChild("StudsConverter"))

local ColorSwapModifier = {}

local SWAP_INTERVAL = 15
local COUNTDOWN_SECONDS = 3
local STUD_TAG = "StudsCamoTexture"

function ColorSwapModifier.buildOptions(duration: number?, modifierService)
	local colorCache = {}
	local activeThread = nil
	local running = false

	local function cacheOriginalColors(character)
		local cache = {}
		for _, part in ipairs(character:GetDescendants()) do
			if part:IsA("BasePart") then
				local textures = {}
				for _, child in ipairs(part:GetChildren()) do
					if child:IsA("Texture") and child.Name == STUD_TAG then
						textures[child] = child.Color3
					end
				end
				cache[part] = { color = part.Color, textures = textures }
			end
		end
		return cache
	end

	local function randomizeCharacterColors(character)
		local color = ModifierUtils.randomBrightColor()
		for _, part in ipairs(character:GetDescendants()) do
			if part:IsA("BasePart") then
				StudsConverter.paintPart(part, color)
			end
		end
	end

	local function swapColors()
		ModifierUtils.forEachHider(function(player)
			local character = player.Character
			if not character then
				return
			end
			if not colorCache[player] then
				colorCache[player] = cacheOriginalColors(character)
			end
			randomizeCharacterColors(character)
		end)
	end

	local function fireCountdown(seconds: number)
		if not modifierService then
			return
		end
		modifierService.Client.Countdown:FireAll({
			id = "ColorSwap",
			text = "COLOR SWAP",
			seconds = seconds,
		})
	end

	local function updateMeta(nextSwapAt: number)
		if not modifierService then
			return
		end
		modifierService:SetMeta("ColorSwap", {
			interval = SWAP_INTERVAL,
			nextTickAt = nextSwapAt,
		})
	end

	local function cycle()
		local nextSwapAt = os.clock() + SWAP_INTERVAL
		updateMeta(nextSwapAt)

		while running do
			local now = os.clock()
			local untilSwap = nextSwapAt - now

			if untilSwap <= 0 then
				swapColors()
				nextSwapAt = os.clock() + SWAP_INTERVAL
				updateMeta(nextSwapAt)
				untilSwap = SWAP_INTERVAL
			end

			local untilCountdown = untilSwap - COUNTDOWN_SECONDS
			if untilCountdown > 0 then
				task.wait(untilCountdown)
			end

			for i = COUNTDOWN_SECONDS, 1, -1 do
				if not running then
					break
				end
				fireCountdown(i)
				task.wait(1)
			end
		end
	end

	local function onStart()
		running = true
		activeThread = task.spawn(cycle)
	end

	local function onStop()
		running = false
		activeThread = nil

		for player, playerCache in pairs(colorCache) do
			local character = player.Character
			if character then
				for part, data in pairs(playerCache) do
					if part.Parent then
						part.Color = data.color
						for texture, color in pairs(data.textures) do
							if texture.Parent then
								texture.Color3 = color
							end
						end
					end
				end
			end
		end
		table.clear(colorCache)
	end

	return {
		duration = duration,
		onStart = onStart,
		onStop = onStop,
		meta = { interval = SWAP_INTERVAL },
	}
end

return ColorSwapModifier
