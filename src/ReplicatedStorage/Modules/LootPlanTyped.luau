--!strict

-- Original Module can be found at - roblox.com/library/4710697524/LootPlan
-- API Documentation can be found at - https://devforum.roblox.com/t/lootplan-random-loot-generation-made-easy/463702
-- Two example scripts can be found within the explorer, inside this module

local LootPlan = {}

-- Classes --

local SingleLootPlan = {}
SingleLootPlan.__index = SingleLootPlan

local MultiLootPlan = {}
MultiLootPlan.__index = MultiLootPlan

-- Types

type Loot = {
	name:string;
	chance:number;
}

type SingleProperties = {
	Randomizer: Random;
	Loot: {[string]:Loot};
	LootList: {[number]:Loot};
	LootCount: number;
	TotalChance: number;
}

type MultiProperties = {
	Randomizer: Random;
	Loot: {[string]:Loot};
}

type SingleLootPlan = typeof(setmetatable({}::SingleProperties, SingleLootPlan))
type MultiLootPlan = typeof(setmetatable({}::MultiProperties, MultiLootPlan))

--> SingleLootPlan <--

function SingleLootPlan.new(seed:number?) : SingleLootPlan
	local SingleLootPlan = setmetatable({},SingleLootPlan)
	SingleLootPlan.Randomizer = Random.new(seed or (tick()%1)*1e10)
	SingleLootPlan.Loot = {}
	SingleLootPlan.LootList = {}
	SingleLootPlan.LootCount = 0
	SingleLootPlan.TotalChance = 0
	return SingleLootPlan
end

function SingleLootPlan.AddLoot(self:SingleLootPlan, name:string, chance:number)
	local newLoot: Loot = {
		name = name;
		chance = chance;
	}
	self.Loot[name] = newLoot
	self.LootCount += 1
	self.TotalChance += chance
	self:_updateLootList()
	return self
end

function SingleLootPlan.AddLootFromTable(self:SingleLootPlan, list:{[string]:number})
	for name, chance in list do
		self:AddLoot(name, chance)
	end
	return self
end

function SingleLootPlan.GetLootChance(self:SingleLootPlan, name:string)
	local loot = self.Loot[name]
	if loot then
		return loot.chance
	else
		error("Loot with name '"..tostring(name).."' does not exist")
	end
end

function SingleLootPlan.GetTrueLootChance(self:SingleLootPlan, name:string)
	local loot = self.Loot[name]
	if loot then
		return (loot.chance/self.TotalChance)*100
	else
		error("Loot with name '"..tostring(name).."' does not exist")
	end
end

function SingleLootPlan.RemoveLoot(self:SingleLootPlan, name:string)
	local loot = self.Loot[name]
	if loot then
		self.TotalChance -= loot.chance
		self.LootCount -= 1
		self.Loot[name] = nil
		self:_updateLootList()
	end
end

function SingleLootPlan.ChangeLootChance(self:SingleLootPlan, name:string, chance:number)
	local loot = self.Loot[name]
	if loot then
		self.TotalChance += chance - loot.chance
		loot.chance = chance
		self:_updateLootList()
		return loot
	else
		error("Loot with name '"..tostring(name).."' does not exist")
	end
end

function SingleLootPlan.GetRandomLoot(self:SingleLootPlan, luck:number?) : string
	local luck = luck or 1
	local lootName: string
	if luck >= 1 then
		local result = self.Randomizer:NextNumber()
		local aggregate = 0
		for i, loot in self.LootList do
			local chance = loot.chance * luck
			if result < (chance + aggregate) / self.TotalChance then
				lootName = loot.name
				break
			end
			aggregate += chance
		end
	else
		local luck = 1/luck
		local result = self.Randomizer:NextNumber()
		local aggregate = 0
		for i = self.LootCount, 1, -1 do
			local loot = self.LootList[i]
			local chance = loot.chance * luck
			if result < (chance + aggregate) / self.TotalChance then
				lootName = loot.name
				break
			end
			aggregate += chance
		end
	end
	return lootName
end

function SingleLootPlan._updateLootList(self:SingleLootPlan)
	local LootList = {}

	for Name,Loot in self.Loot do
		table.insert(LootList, Loot)
	end

	table.sort(LootList, function(a,b)
		return a.chance < b.chance
	end)

	self.LootList = LootList

	return self
end

--> MultiLootPlan <--

function MultiLootPlan.new(seed:number?)
	local MultiLootPlan = setmetatable({},MultiLootPlan)
	MultiLootPlan.Randomizer = Random.new(seed or (tick()%1)*1e10)
	MultiLootPlan.Loot = {}
	return MultiLootPlan
end

function MultiLootPlan.AddLoot(self:MultiLootPlan, name:string, chance:number) 
	local newLoot = {
		name = name;
		chance = chance;
	}
	self.Loot[name]=newLoot
	return newLoot
end

function MultiLootPlan.AddLootFromTable(self:MultiLootPlan, list:{[string]:number})
	for name, chance in list do
		self:AddLoot(name, chance)
	end
end

function MultiLootPlan.GetLootChance(self:MultiLootPlan, name:string)
	local loot = self.Loot[name]
	if loot then
		return loot.chance
	else
		error("Loot with name '"..tostring(name).."' does not exist")
	end
end

function MultiLootPlan.RemoveLoot(self:MultiLootPlan, name:string)
	self.Loot[name]=nil
end

function MultiLootPlan.ChangeLootChance(self:MultiLootPlan, name:string, newChance:number)
	local loot = self.Loot[name]
	if loot then
		loot.chance = newChance
	else
		error("Loot with name '"..tostring(name).."' does not exist")
	end
end

function MultiLootPlan.GetRandomLoot(self: MultiLootPlan, luck:number, iterations:number?)
	local LootTable = {} :: {[string]:number}
	for i = 1, iterations or 1 do
		for name,loot in self.Loot do 
			local result = self.Randomizer:NextNumber()
			local chance = (loot.chance/100) * (luck or 1)
			if result < chance then
				LootTable[name] = LootTable[name] and LootTable[name]+1 or 1
			end
		end
	end
	return LootTable
end

return {
	newSingle = SingleLootPlan.new;
	newMulti = MultiLootPlan.new;
}