--// Camera Module V1.1

--// Services
local Heart = game:GetService("RunService")

--// Requires
local Settings = require(script.Parent.Setting)
local Physics = require(script.PhysicsModule)

--// Core
local CameraHandler = {}

--// Data
CameraHandler.CurrentCam = workspace.CurrentCamera

--// Angles
CameraHandler.angles = {}
CameraHandler.angles.x = 0
CameraHandler.angles.y = 0
CameraHandler.angles.z = 0

--// Recoil Directional Forces
CameraHandler.recoil = {}
CameraHandler.recoil.x = Physics.spring.new{d=Settings.RecoilDamper;s=Settings.RecoilSpeed;}
CameraHandler.recoil.y = Physics.spring.new{d=Settings.RecoilDamper;s=Settings.RecoilSpeed;}
CameraHandler.recoil.z = Physics.spring.new{d=Settings.RecoilDamper;s=Settings.RecoilSpeed;}

--// Accelerate 
function CameraHandler:accelerate(x,y,z)
	CameraHandler.recoil.x.impulse(x)
	CameraHandler.recoil.y.impulse(y)
	CameraHandler.recoil.z.impulse(z)
end

--// Recoil
function CameraHandler:accelerateXY(x,y)
	CameraHandler.recoil.x.impulse(x)
	CameraHandler.recoil.y.impulse(y)
end

--// UpdateCam
local function updatecam()			
	CameraHandler.CurrentCam.CoordinateFrame = 
		CameraHandler.CurrentCam.CoordinateFrame*CFrame.Angles(
			CameraHandler.recoil.x.p(),CameraHandler.recoil.y.p(),CameraHandler.recoil.z.p())
end

--// Binds
Heart:BindToRenderStep("RecoilCam",2000,function()
	updatecam()
end)

return CameraHandler

--// MrHardswell
--// 5/24/2022
