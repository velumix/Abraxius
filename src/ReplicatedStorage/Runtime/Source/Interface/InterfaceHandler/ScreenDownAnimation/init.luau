-- Services // Modules 
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Utility = require(ReplicatedStorage.Modules.Utility) 

-- Why such a complicated moduel for something so simple. BCUZ I only do it once and it'll be nice for my little interfacehandler! 
-- to make better ux have lots of tools for da future 

local ScreenDownAnimation = {
	Preset = {
		Inital = {
			Visible = {
				["Frame"] = {
					BackgroundTransparency = 0, 
				},
				["TextLabel"] = {
					TextTransparency = 0, 
				},
				["ImageFrame"] = {
					ImageTransparency = 0, 	
				},
				["ImageButton"] = {
					ImageTransparency = 0
				},
				["UIStroke"] = {
					Transparency = 0 
				}
			},
			
		} 
	} 
} 
ScreenDownAnimation.__index = ScreenDownAnimation

function ScreenDownAnimation.new(Base : GuiBase, Deep) 
	local NewAnimation = setmetatable({}, ScreenDownAnimation)
	NewAnimation:Init(Base, Deep) 
	
	return NewAnimation	
end

function ScreenDownAnimation:SetSettings(Settings) 
	local DefaultSettings = {
		InbetweenDelay = 0.1, 
		WaitForTween = false,
		InvisibleUntilAppear = true,
		Offset = UDim2.fromScale(0, -0.05),
		DownTween = TweenInfo.new(0.2),
		OrderAttribute = "Order",
		InitalProperties = {
			["Frame"] = {
				BackgroundTransparency = 1, 
			},
			["TextLabel"] = {
				TextTransparency = 1, 
			},
			["ImageFrame"] = {
				ImageTransparency = 1, 	
			},
			["ImageButton"] = {
				ImageTransparency = 1
			},
			["UIStroke"] = {
				Transparency = 1 
			}
		},
		SaveProperties = {
			["Frame"] = {"BackgroundTransparency"},
			["ImageFrame"] = {"ImageTransparency"},
			["ImageButton"] = {"ImageTransparency"},
			["TextLabel"] = {"TextTransparency"},
			["UIStroke"] = {"Transparency", "Enabled"}
		} 
	} 

	self.Settings = Settings or DefaultSettings
	
	-- Fuffill the defaults 
	for Index, Value in DefaultSettings do 
		if self.Settings[Index] == nil then 
			self.Settings[Index] = Value
		end
	end
end

function ScreenDownAnimation:Init(Base : GuiBase, Deep) 
	self.Base = Base
	self.Order = {} 
	self.OrderSaved = {} 
	self.Iterator = Base[Deep and "GetDescendants" or "GetChildren"] 
end


function ScreenDownAnimation:SaveForInstance(GuiObject, AddAdditonal)
	self.OrderSaved[GuiObject] = {} 
	
	if GuiObject:IsA("GuiObject") then
		self.OrderSaved[GuiObject].Position = GuiObject.Position 
		self.OrderSaved[GuiObject].Size = GuiObject.Size
	end

	for ClassName, PropertyList in self.Settings.SaveProperties do 
		if GuiObject:IsA(ClassName) then 
			for _, Property in PropertyList do 
				self.OrderSaved[GuiObject][Property] = GuiObject[Property]
			end
		end
	end
	
	if AddAdditonal then 
		table.insert(self.Additonals, GuiObject)
	end
end
function ScreenDownAnimation:Save() 
	if self.HasSaved then return end 
	
	for _, GuiObject : GuiObject in self.Iterator(self.Base) do 
		if GuiObject:IsA("GuiObject") and GuiObject:GetAttribute(self.Settings.OrderAttribute) then
			self.Order[GuiObject:GetAttribute(self.Settings.OrderAttribute)] = GuiObject 

			self:SaveForInstance(GuiObject)

			-- Add any supporting Tweens 
			for _, UIBase : UIBase in GuiObject:GetDescendants() do 
				if not (UIBase:IsA("UIConstraint") or UIBase:IsA("GuiObject")) then 
					continue 
				end

				self:SaveForInstance(UIBase, true)
			end 
		end
	end
	
	self.HasSaved = true
end

function ScreenDownAnimation:CreateTweens() 
	self.Additonals = {} 
	-- Firstly Create the order
	
	self:Save() 
	
	for _, Tween in Utility.updipairs(self.Tweens) do 
		Tween:Cancel()
	end
	
	self.Tweens = {} 
	
	for _, GuiObject : GuiObject in Utility.spairs(self.Order) do
		local TotalTweens = {} 
		local Properties = self.OrderSaved[GuiObject] or {} 
		local MainTween = TweenService:Create(GuiObject, self.Settings.DownTween, Properties) 
		
		table.insert(TotalTweens, MainTween)
		
		-- Add any supporting Tweens 
		for _, UIBase : UIBase in GuiObject:GetDescendants() do 
			if not self.OrderSaved[UIBase] then continue end 
			local AdditionalTween = TweenService:Create(UIBase, self.Settings.DownTween, self.OrderSaved[UIBase])

			table.insert(TotalTweens, AdditionalTween)
		end
		
		table.insert(self.Tweens, 
			TotalTweens
		)
	end
end

function ScreenDownAnimation:Play() 
	task.defer(self.PlayAsync, self)
end

function ScreenDownAnimation:PlayAsync() 
	if not self.Settings then self:SetSettings() end 
	self:CreateTweens() 
	self.PlayProxy = newproxy()
	local Identity = self.PlayProxy
	
	-- Set intial Propeties 
	for _, GuiObject : GuiObject in self.Order do
		local SavedProperties = self.OrderSaved[GuiObject] or {}  
		for Key, Value in SavedProperties do  
			GuiObject[Key] = Value 
		end
		
		warn(self.Settings.InitalProperties)

		for ClassName, Properties in self.Settings.InitalProperties do 	
			if GuiObject:IsA(ClassName) then 
				for Key, Value in Properties do 
					GuiObject[Key] = Value 
				end
			end
		end
		
		if self.Settings.InvisibleUntilAppear then 
			GuiObject.Visible = false 
		end
		
		GuiObject.Position += self.Settings.Offset
	end
	
	for _, AdditionalGuiObject : GuiObject in self.Additonals do 
		local SavedProperties = self.OrderSaved[AdditionalGuiObject] or {}
		for Key, Value in SavedProperties do  
			AdditionalGuiObject[Key] = Value
		end
		
		for ClassName, Properties in self.Settings.InitalProperties do 
			if AdditionalGuiObject:IsA(ClassName) then 
				for Key, Value in Properties do 
					AdditionalGuiObject[Key] = Value 
				end
			end
		end
	end
	
	for _, TweenList : {Tween} in self.Tweens do 		
		if self.PlayProxy ~= Identity then return end 
		
		local MainTween = TweenList[1]
		if self.Settings.InvisibleUntilAppear then 
			MainTween.Instance.Visible = true 
		end
		
		for _, SubTween in TweenList do 
			SubTween:Play()
		end
		
		if self.Settings.WaitForTween then 
			MainTween.Completed:Wait() 
		end
		
		task.wait(self.Settings.InbetweenDelay)
	end
end

return ScreenDownAnimation