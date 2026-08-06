local HttpService = game:GetService("HttpService")
local JSON = require(script.JSON)
-- TODO: Remove unnecessary vars, update icons 
-- I forgot what exact settings i used sorry
-- Will add them in a future update!
return function(className,iconImage)
	local info = JSON[className] or JSON["Breakpoint"] -- Breakpoint For broken icons. Was gonna go with AuroraScript before but that might give somebody a scare and confuse them too much.
	local x,y = info.frame.x,info.frame.y
	return {x,y}
end