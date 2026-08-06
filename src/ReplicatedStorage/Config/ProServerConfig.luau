local ProServerConfig = {
	RequiredWins = 30,
	PlaceName = "ProServers",
	FallbackPlaceName = "Main",
	Tag = "Matchmaking",
	PreviewServers = {},
	LobbyListMaxEntries = 8,
	TeleportCooldownSeconds = 8,
	Registry = {
		DataStoreName = "ProServerLobbyRegistry",
		KeyName = "ActiveLobbies",
		HeartbeatInterval = 15,
		ListRefreshInterval = 12,
		LobbyTTLSeconds = 120,
		ReadCacheSeconds = 10,
		MinReadBudget = 2,
		MinWriteBudget = 2,
	},
	JoinCodeLengthMin = 8,
}

return ProServerConfig