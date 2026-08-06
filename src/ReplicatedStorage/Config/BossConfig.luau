export type BossDef = {
	displayName: string,
	health: number,
	healthPerPlayer: number?,
	walkSpeed: number,
	damage: number,
	attackRange: number,
	attackCooldown: number,
	searchRadius: number,
	tickRate: number,

	-- Custom-rig slam settings (used when the boss has no Humanoid).
	slamCooldown: number?,
	slamRadius: number?,
	slamWindup: number?,
	slamKnockback: number?,
	slamUpward: number?,

	-- Currency awarded to each player who attacked this monster when it dies.
	deathReward: number?,

	-- Fireworks awarded to each player who attacked this monster when it dies.
	fireworkReward: number?,

	-- Optional event-tuned spawn settings.
	minionCount: number?,
	minionSpawnRadius: number?,
}

local bosses: { [string]: BossDef } = {
	Minion = {
		displayName = "Minion",
		health = 500,
		walkSpeed = 14,
		damage = 25,
		attackRange = 5,
		attackCooldown = 1,
		searchRadius = 200,
		tickRate = 0.25,
	},
	PaintBoss = {
		displayName = "Paint Boss",
		health = 3000,
		healthPerPlayer = 7000,
		walkSpeed = 8,
		damage = 50,
		attackRange = 6,
		attackCooldown = 1.5,
		searchRadius = 200,
		tickRate = 0.25,

		slamCooldown = 6.5,
		slamRadius = 28,
		slamWindup = 0.4,
		slamKnockback = 140,
		slamUpward = 70,

		minionCount = 12,
		minionSpawnRadius = 15,
		deathReward = 100,
		fireworkReward = 50,
	},
	PaintMinion = {
		displayName = "Paint Minion",
		health = 250,
		walkSpeed = 12,
		damage = 15,
		attackRange = 4,
		attackCooldown = 1,
		searchRadius = 100,
		tickRate = 0.25,
		deathReward = 25,
		fireworkReward = 10,
	},
}

local BossConfig = {}

function BossConfig.Get(name: string): BossDef?
	return bosses[name]
end

function BossConfig.GetNames(): { string }
	local names = {}
	for name in pairs(bosses) do
		table.insert(names, name)
	end
	return names
end

return BossConfig
