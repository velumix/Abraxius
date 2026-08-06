return {
	-- Core coffee drinks
	SimpleCoffee = {
		DisplayName = "Simple Coffee",
		Ingredients = { Coffee = 4 },
		BlendTime = 2,
		OutputToolName = "CoffeeCup",
	},
	EspressoShot = {
		DisplayName = "Espresso Shot",
		Ingredients = { Espresso = 4 },
		BlendTime = 1,
		OutputToolName = "EspressoCup",
	},
	CoffeeMix = {
		DisplayName = "Coffee Mix",
		Ingredients = { Coffee = 2, Espresso = 2 },
		BlendTime = 3,
		OutputToolName = "CoffeeCup",
	},

	-- Milk-based drinks
	FlatWhite = {
		DisplayName = "Flat White",
		Ingredients = { Espresso = 2, Milk = 2 },
		BlendTime = 3,
		OutputToolName = "CoffeeCup",
	},
	Cappuccino = {
		DisplayName = "Cappuccino",
		Ingredients = { Espresso = 2, Milk = 1, Cream = 1 },
		BlendTime = 3,
		OutputToolName = "CoffeeCup",
	},
	VanillaLatte = {
		DisplayName = "Vanilla Latte",
		Ingredients = { Coffee = 2, Milk = 1, VanillaSyrup = 1 },
		BlendTime = 3,
		OutputToolName = "CoffeeCup",
	},
	CaramelMacchiato = {
		DisplayName = "Caramel Macchiato",
		Ingredients = { Espresso = 2, Milk = 1, CaramelSyrup = 1 },
		BlendTime = 3,
		OutputToolName = "CoffeeCup",
	},
	HazelnutLatte = {
		DisplayName = "Hazelnut Latte",
		Ingredients = { Coffee = 2, Milk = 1, HazelnutSyrup = 1 },
		BlendTime = 3,
		OutputToolName = "CoffeeCup",
	},

	-- Matcha drinks
	MatchaLatte = {
		DisplayName = "Matcha Latte",
		Ingredients = { Matcha = 2, Milk = 2 },
		BlendTime = 3,
		OutputToolName = "CoffeeCup",
	},

	-- Signature drink
	Observatory = {
		DisplayName = "Observatory Special",
		Ingredients = { Coffee = 2, Espresso = 1, CoconutSyrup = 1 },
		BlendTime = 4,
		OutputToolName = "CoffeeCup",
	},
}