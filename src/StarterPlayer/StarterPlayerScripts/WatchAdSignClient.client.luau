local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AdService = game:GetService("AdService")

local Observers = require(ReplicatedStorage.Packages.Observers)
local Trove = require(ReplicatedStorage.Packages.Trove)
local ClaimSixSevenCoinsRE = ReplicatedStorage:WaitForChild("GameRemotes"):WaitForChild("ClaimSixSevenCoins") :: RemoteEvent

local INELIGIBLE_RESULTS = {
	Enum.AdAvailabilityResult.PlayerIneligible,
	Enum.AdAvailabilityResult.DeviceIneligible,
	Enum.AdAvailabilityResult.PublisherIneligible,
	Enum.AdAvailabilityResult.ExperienceIneligible,
}

local function isIneligible(result: Enum.AdAvailabilityResult)
	return table.find(INELIGIBLE_RESULTS, result) ~= nil
end

local function checkForAds()
	local isSuccess, result = pcall(function()
		return AdService:GetAdAvailabilityNowAsync(Enum.AdFormat.RewardedVideo)
	end)

	if not isSuccess or isIneligible(result.AdAvailabilityResult) then
		return false
	end

	return true
end

Observers.observeTag("WatchAdsButton", function(adsButton)
	local adsButtonTrove = Trove.new()
	adsButtonTrove:Add(adsButton.MouseButton1Click:Connect(function()
		if checkForAds() then
			ClaimSixSevenCoinsRE:FireServer()
		end
	end))
	return adsButtonTrove:WrapClean()
end)

