local Players = game:GetService("Players")

return function(part): Player?
	local model = part:FindFirstAncestorWhichIsA("Model")
	return model and Players:GetPlayerFromCharacter(model)
end