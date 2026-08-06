local MatchConfig = {}

MatchConfig.CONFIG = {
	MIN_PLAYERS = 2,
	INTERMISSION = 15,
	MAP_BUFFER = 5,
	REVEAL = 5.6,
	HIDE = 45,
	ROUND = 150,
	REVEALING_HIDERS = 8,
	RESOLVE = 10,
	HIDER_SPEED = 18,
	SEEKER_SPEED = 28,
}

MatchConfig.PITY = {
	BASE_WEIGHT = 1,
	GAMEPASS_MULT = 2,
	PER_ROUND = 0.5,
	MAX_PITY_BONUS = 7.5,
	RECENT_SEEKER_MULT = 0.05,
}

MatchConfig.SEEKER_BOOST_ATTR = "OwnsSeekerGamepass"
MatchConfig.SIZE_SCALES = { tiny = 0.7, giant = 1.65 }
MatchConfig.REVEAL_SECONDS = 10
MatchConfig.REVIVE_MIN_TIME_LEFT = 35
MatchConfig.REVIVE_MAX = 4
MatchConfig.MATCHMAKING_TIME_BUCKET_SECONDS = 15

return MatchConfig
