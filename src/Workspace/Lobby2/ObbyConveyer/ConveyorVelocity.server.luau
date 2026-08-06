-- ConveyorVelocity: drives every conveyor belt part under this model.
-- Replaces the 7 legacy free-model scripts that each ran `while true do part.Velocity = ... wait(0.1)`
-- forever. The deprecated .Velocity property is gone; the modern equivalent is AssemblyLinearVelocity,
-- and per the Roblox docs an ANCHORED part may hold a nonzero AssemblyLinearVelocity — which acts as
-- surface (conveyor) velocity for anything standing on it. The value persists once set, so this runs
-- ONCE at server start: no loops, no per-frame work, identical belt behavior.

for _, d in ipairs(script.Parent:GetDescendants()) do
	if d:IsA("BasePart") and d.Name == "Conveyer" then
		d.AssemblyLinearVelocity = d.CFrame.LookVector * 50  -- same direction & speed as the old scripts
	end
end