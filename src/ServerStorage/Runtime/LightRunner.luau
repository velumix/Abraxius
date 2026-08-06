-- LightRunner

local LightRunner = {
	Modules = {},
	LoadOrder = {},
} 



function LightRunner:Get(Name) 
	return LightRunner.Modules[Name] 
end

function LightRunner:Load(Folder: Folder)
	table.clear(LightRunner.Modules)
	table.clear(LightRunner.LoadOrder)

	local moduleScripts = {}
	LightRunner:IterateRules(Folder, function(ModuleScript: ModuleScript)
		table.insert(moduleScripts, ModuleScript)
	end)

	for _, ModuleScript in moduleScripts do
		local ok, Module = pcall(require, ModuleScript)
		if not ok then
			error(`[LightRunner]: Failed to require module {ModuleScript:GetFullName()} :: {Module}`)
		end

		LightRunner.Modules[ModuleScript.Name] = Module
		table.insert(LightRunner.LoadOrder, ModuleScript.Name)
	end

	for _, ModuleName in LightRunner.LoadOrder do
		local Module = LightRunner.Modules[ModuleName]
		if type(Module) == "table" and type(Module.WhenLoaded) == "function" then
			Module:WhenLoaded()
		end
	end
end

function LightRunner:IterateRules(AnInstance, IterateFn : (ModuleScript : ModuleScript) -> ())
	for _,Descendant in AnInstance:GetDescendants() do 
		if Descendant:IsA("ModuleScript") and not (Descendant.Parent:IsA("ModuleScript")) and not Descendant.Parent:IsA("Configuration") then
			IterateFn(Descendant)
		end
	end
end

return LightRunner