-- Write any code here, don't worry about returning anything.

-- Write any code here, don't worry about returning anything.
local Selection = game:GetService("Selection") 
local Items = Selection:Get() 
if #Items == 0 or #Items > 1 then
	warn(`Incorrect amount of instances selected!`)
	return
end

local CFrameValue : CFrameValue = Items[1] 

local Workspace = game:GetService("Workspace")
local CurrentCamera = Workspace.CurrentCamera
 
CFrameValue.Value = CurrentCamera.CFrame

warn("SAVED!")

