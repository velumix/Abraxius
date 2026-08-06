--!strict
local Impact = {}

export type Data = {
	IsCharacter: boolean,
	Material: Enum.Material,
	Color: Color3,
}

function Impact:GetData(_player: Player, hit: BasePart): Data
	local model = hit:FindFirstAncestorOfClass("Model")
	local humanoid = model and model:FindFirstChildOfClass("Humanoid")
	return {
		IsCharacter = humanoid ~= nil,
		Material = hit.Material,
		Color = if humanoid then Color3.fromRGB(130, 0, 0) else hit.Color,
	}
end

return table.freeze(Impact)
