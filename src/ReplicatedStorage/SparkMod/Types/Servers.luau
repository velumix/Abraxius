--!strict

export type ServerInfo = {
	jobId: string,
	placeId: number,
	playerCount: number,
	maxPlayers: number,
	version: string?,
	isStale: boolean,
}

export type PlayerLocation = {
	userId: number,
	jobId: string,
	displayName: string,
	username: string,
	joinedAt: number,
}

return {}
