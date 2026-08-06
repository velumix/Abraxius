
function StringAbbrivationToSeconds(string)
	local Matches = {
		["s"] = 1, ["sec"] = 1, ["secs"] = 1, ["second"] = 1, ["seconds"] = 1,
		["m"] = 60, ["min"] = 60, ["mins"] = 60, ["minute"] = 60, ["minutes"] = 60,
		["h"] = 3600, ["hr"] = 3600, ["hrs"] = 3600, ["hour"]= 3600, ["hours"] = 3600,
		["d"] = 86400, ["day"] = 86400, ["days"] = 86400,
		["w"] = 604800, ["week"] = 604800,  ["weeks"] = 604800,
		["mon"] = 2629743, ["month"] = 2629743, ["months"] = 2629743,
		["y"] = 31556926, ["yr"] = 31556926, ["yrs"] = 31556926, ["year"] = 31556926, ["years"] = 31556926,
	}

	local IsValid , Stub = false , 0;

	for i=1,#string do
		local Letter = string:sub(i,i)
		local IsLetter = Letter:match("%a") ~= nil
		if IsLetter then
			Stub = i;
			IsValid = true;
			break;
		end
	end

	if IsValid then
		local Match = Matches[string.lower(string:sub(Stub,#string))]
		local Number = tonumber(string:sub(1,Stub-1)) 

		if Number and Match then
			return Number*Match
		end
	end
end




return function (cmdr)
	cmdr:RegisterType("time", {
		Validate = function(Text)
			return StringAbbrivationToSeconds(Text) ~= nil 
		end;

		Parse = function(DateString)
			return StringAbbrivationToSeconds(DateString)
		end;
	})
end
