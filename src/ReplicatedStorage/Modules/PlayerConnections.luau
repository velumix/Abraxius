--[[
TheNexusAvenger

Simple utility for managing player and character events.
This resolves issues with garbage collection.
--]]
--!strict

export type PlayerConnections = {
	StaticPlayerConnections: PlayerConnections?,
	
	PlayerConnections: {RBXScriptConnection},
	CharacterConnections: {[Model]: {RBXScriptConnection}},
	new: () -> (PlayerConnections),
	Get: () -> (PlayerConnections),
	AddCharacterConnection: (self: PlayerConnections, Player: Player, Connection: RBXScriptConnection) -> (),
	AddPlayerConnection: (self: PlayerConnections, Player: Player, Connection: RBXScriptConnection) -> (),
	DisconnectCharacterConnections: (self: PlayerConnections, Player: Player) -> (),
	DisconnectPlayerConnections: (self: PlayerConnections, Player: Player) -> (),
}


local Players = game:GetService("Players")

local PlayerConnections = {
	StaticPlayerConnections = nil :: PlayerConnections?,
}
PlayerConnections.__index = PlayerConnections



--[[
Creates a PlayerConnections instance.
--]]
function PlayerConnections.new(): PlayerConnections
	--Create the instance.
	local self = (setmetatable({
		PlayerConnections = {},
		CharacterConnections = {},
	}, PlayerConnections) :: any) :: PlayerConnections
	
	--Connect clearing for players.
	Players.PlayerRemoving:Connect(function(Player)
		self:DisconnectPlayerConnections(Player)
	end)
	Players.PlayerAdded:Connect(function(Player)
		self:AddPlayerConnection(Player, Player.CharacterAdded:Connect(function(Character)
			self:DisconnectCharacterConnections(Player)
		end))
	end)
	for _, Player in Players:GetPlayers() do
		self:AddPlayerConnection(Player, Player.CharacterAdded:Connect(function(Character)
			self:DisconnectCharacterConnections(Player)
		end))
	end
	
	--Return the object.
	return self
end

--[[
Retturns a static instance of a PlayerConnections instance.
Clearing is automatically managed.
--]]
function PlayerConnections.Get(): PlayerConnections
	if not PlayerConnections.StaticPlayerConnections then
		PlayerConnections.StaticPlayerConnections = PlayerConnections.new()
	end
	return PlayerConnections.StaticPlayerConnections :: PlayerConnections
end


--[[
Adds a character connection for the current character.
--]]
function PlayerConnections:AddCharacterConnection(Player: Player, Connection: RBXScriptConnection): ()
	--Return if there is no character.
	local Character = Player.Character
	if not Character then
		warn("Player has no current character. Unable to store an event connection for the character.")
		return
	end
	
	--Store the connection.
	if not self.CharacterConnections[Player] then
		self.CharacterConnections[Player] = {}
	end
	if not self.CharacterConnections[Player][Character] then
		self.CharacterConnections[Player][Character] = {}
	end
	table.insert(self.CharacterConnections[Player][Character], Connection)
end

--[[
Adds a player connection.
--]]
function PlayerConnections:AddPlayerConnection(Player: Player, Connection: RBXScriptConnection): ()
	if not self.PlayerConnections[Player] then
		self.PlayerConnections[Player] = {}
	end
	table.insert(self.PlayerConnections[Player], Connection)
end

--[[
Disconnects the connections of previous characters.
--]]
function PlayerConnections:DisconnectCharacterConnections(Player: Player): ()
	if not self.CharacterConnections[Player] then return end
	
	--Get the characters to clear.
	--This is done to prevent modifying the table while iterating.
	local CharactersToClear = {}
	for Character, _ in self.CharacterConnections[Player] do
		if Character == Player.Character then continue end
		table.insert(CharactersToClear, Character)
	end
	
	--Disconnect the event connections.
	for _, Character in CharactersToClear do
		for _, Connection in self.CharacterConnections[Player][Character] do
			Connection:Disconnect()
		end
		self.CharacterConnections[Player][Character] = nil
	end
end

--[[
Disconnects the connection of the player and the player.
--]]
function PlayerConnections:DisconnectPlayerConnections(Player: Player): ()
	--Disconnect the character event connections.
	if self.CharacterConnections[Player] then
		for _, Connections in self.CharacterConnections[Player] do
			for _, Connection in Connections do
				Connection:Disconnect()
			end
		end
		self.CharacterConnections[Player] = nil
	end
	
	--Disconnect the player event connections.
	if self.PlayerConnections[Player] then
		for _, Connection in self.PlayerConnections[Player] do
			Connection:Disconnect()
		end
		self.PlayerConnections[Player] = nil
	end
end



return (PlayerConnections :: any) :: PlayerConnections