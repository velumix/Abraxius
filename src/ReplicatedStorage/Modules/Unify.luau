local HOUR_LENGTH = 60*60
local MINUTE_LENGTH = 60

local Unify = {
	UnitTable = {
		years = 31556926,
		months = 2629744,
		weeks = 604800,
		days = 86400,
		hours = 3600,
		minutes = 60,
		seconds = 1,
		y = 31556926,
		mon = 2629744,
		w = 604800,
		d = 86400,
		h = 3600,
		m = 60,
		s = 1
	}
}


-- StandardTime Functionsd 
function Unify.GetStandardTimeFrom(StandardTime)  
	return Unify.GetStandardTime() - StandardTime 
end
function Unify.GetStandardTimeUntil(StandardTime) 
	return StandardTime - Unify.GetStandardTime()
end
function Unify.GetStandardTimeIn(Time) 
	return Unify.GetStandardTime() + Time 
end
function Unify.GetStandardTime() 
	return os.time(os.date("!*t"))
end

-- ServerTime Functyions 
function Unify.GetServerTimeFrom(ServerTime)  
	return Unify.GetServerTime()  - ServerTime
end
function Unify.GetServerTimeUntil(ServerTime) 
	return ServerTime - Unify.GetServerTime() 
end
function Unify.GetServerTimeIn(ServerTime) 
	return Unify.GetServerTime() + ServerTime 
end
function Unify.GetServerTime() 
	return workspace:GetServerTimeNow()
end

function Unify.ParseTimeString(timeString)
	local totalSeconds = 0

	for unitString in timeString:gmatch("(%d+%a+)") do
		local number, unit = unitString:match("(%d+)(%a+)")

		if not number or not unit then
			error("Invalid unit format: " .. unitString)
		end

		local secondsPerUnit = Unify.UnitTable[unit:lower()]
		if not secondsPerUnit then
			error("Unsupported unit: " .. unit)
		end

		totalSeconds = totalSeconds + tonumber(number) * secondsPerUnit
	end

	return totalSeconds 
end 

function Unify.ShortenedClockTime(Time,D) 
	local D = D or 2
	local TimeTable = {
		math.floor(Time/HOUR_LENGTH),
		math.floor((Time%HOUR_LENGTH)/MINUTE_LENGTH),
		math.floor(Time%MINUTE_LENGTH), 
	}
	local FormatText = ""
	for P,Value in ipairs(TimeTable) do 
		if P < D then
			if Value > 0 then 
				FormatText = FormatText .. string.format("%.2d",Value) .. ":"
			end
		else
			FormatText = FormatText .. string.format("%.2d",Value) 
			if P % 2 == 0 then 
				FormatText = FormatText..":"
			end 
		end
	end
	return FormatText
end

function Unify.ClockTime(Time)
	return string.gsub("0Hours:0Minutes:0Seconds", "%a+", {
		Hours = math.floor(Time/HOUR_LENGTH);
		Minutes = math.floor((Time%HOUR_LENGTH)/MINUTE_LENGTH);
		Seconds = math.floor(Time%MINUTE_LENGTH);
	}):gsub("%d%d%d",function(t) 
		return t:sub(2,3) 
	end)
end

function Unify.AbbreviatedTime(Time)
	local Hours = math.floor(Time/HOUR_LENGTH);
	local Minutes = math.floor((Time%HOUR_LENGTH)/MINUTE_LENGTH);
	local Seconds = math.floor(Time%MINUTE_LENGTH);

	return string.gsub("h m s", "%a+", {
		h = if Hours > 0 then tostring(Hours).."h" else "";
		m = if Hours > 0 or Minutes > 0 then tostring(Minutes).."m" else "";
		s = tostring(Seconds).."s";
	}):gsub('^%s*(.-)%s*$', '%1')
end

return Unify	