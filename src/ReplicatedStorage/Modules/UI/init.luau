local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InterfaceHandler = require(ReplicatedStorage.Runtime.Source.Interface.InterfaceHandler)
local UI = InterfaceHandler:GetUI()

_G.UI = UI

export type UI = typeof(UI)

return UI
