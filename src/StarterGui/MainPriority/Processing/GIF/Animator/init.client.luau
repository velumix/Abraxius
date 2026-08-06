-- whats getting animated? 
local animatee = script.Parent 
--[[
   https://assetdelivery.roblox.com/v1/asset/?id= 
   
   to make sure that your image is sized correctly.
   
   i beileve if you image is bigger than 1024x1024 than you expereince resizing. so you must downscale yoru image or modify he rectsize 
   to reflect the new reoslution. 

]]
local update = 1; 
local waitTime = script.FrameDelay
local imageData = {
	tile = {
		x = script.TileWidth.Value, 
		y = script.TileHeight.Value, 
	},
	position = {
		-- starts at 0, lua should adopt the basis of 0 range. instaed of EG : 1-6 its 0-5. 
		iterate = -1,
		x = 1,
		y = 1, 
	},
} 
imageData.position.x,imageData.position.y = (imageData.position.iterate % imageData.tile.x) , math.floor(imageData.position.iterate/imageData.tile.x)
local animationRoutine = coroutine.create(function()
	while wait(waitTime) do 
		debug.profilebegin("IMGGIF :: Update")
		imageData.position.iterate = imageData.position.iterate+1 > (imageData.tile.x*imageData.tile.y)-1 and 1 or imageData.position.iterate+1
		imageData.position.x,imageData.position.y = (imageData.position.iterate % imageData.tile.x) , math.floor(imageData.position.iterate/imageData.tile.x)
		animatee.ImageRectOffset = Vector2.new(imageData.position.x*animatee.imageRectSize.X,imageData.position.y*animatee.imageRectSize.Y)
		debug.profileend()	
	end
end)
coroutine.resume(animationRoutine)