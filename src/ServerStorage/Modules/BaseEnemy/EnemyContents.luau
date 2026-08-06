local BaseEnemyContents = {
	EffectNames = {"Jump", "Spike", "TreeSpike", "ThrowHead", "PumpkinDrop", "Stomp", "AirJump", "SuperJump"}
} 

for I,V in BaseEnemyContents.EffectNames do 
	BaseEnemyContents.EffectNames[V] = I  
end


return BaseEnemyContents 