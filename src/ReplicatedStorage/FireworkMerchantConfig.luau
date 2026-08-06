local FireworkMerchantConfig = {}

FireworkMerchantConfig.ITEMS = {}

FireworkMerchantConfig.ITEM_BY_ID = {}
for _, item in ipairs(FireworkMerchantConfig.ITEMS) do
	FireworkMerchantConfig.ITEM_BY_ID[item.id] = item
end

function FireworkMerchantConfig.get(id)
	return FireworkMerchantConfig.ITEM_BY_ID[id]
end

do
	local RunService = game:GetService("RunService")
	if RunService:IsStudio() and RunService:IsServer() then
		task.defer(function()
			local RS = game:GetService("ReplicatedStorage")
			local function tryReq(name)
				local ok, m = pcall(function() return require(RS:WaitForChild(name, 10)) end)
				return ok and m or nil
			end
			local Knives, Effects, Poses, Titles = tryReq("KnifeSkinManager"), tryReq("KillEffectManager"), tryReq("PoseConfig"), tryReq("TitleManager")
			local function resolves(itemType, id)
				if itemType == "knife" then return Knives ~= nil and Knives.getSkin(id) ~= nil
				elseif itemType == "killeffect" then return Effects ~= nil and Effects.getEffect(id) ~= nil
				elseif itemType == "pose" then return Poses ~= nil and Poses.getPose(id) ~= nil
				elseif itemType == "title" then return Titles ~= nil and Titles.getTitle(id) ~= nil
				end
				return false
			end
			for _, item in ipairs(FireworkMerchantConfig.ITEMS) do
				if not resolves(item.itemType, item.id) then
					warn(string.format("[FireworkMerchantConfig] Merchant item id '%s' (type '%s') does not resolve to a registered item",
						tostring(item.id), tostring(item.itemType)))
				end
			end
		end)
	end
end

return FireworkMerchantConfig
