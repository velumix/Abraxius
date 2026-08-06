local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local GetEnv = require(ReplicatedStorage.GetEnv)

local LocalPlayer = Players.LocalPlayer

local CmdrClient = nil

local CmdrController = Knit.CreateController({ Name = "CmdrController" })

function CmdrController:KnitInit()
	--
end

function CmdrController:KnitStart()
	local AdminService = Knit.GetService("AdminService")

	if not ReplicatedStorage:GetAttribute("CMDR_Loaded") then
		ReplicatedStorage:GetAttributeChangedSignal("CMDR_Loaded"):Wait()
	end

	if not (RunService:IsStudio() or not GetEnv:isProdEnv() or AdminService:IsAdmin(LocalPlayer)) then
		return
	end

	CmdrClient = require(ReplicatedStorage:WaitForChild("CmdrClient") :: ModuleScript)
	CmdrClient:SetActivationKeys({ Enum.KeyCode.F2 })
end

return CmdrController
