local Crypto = {
	IntRange = { 33, 126 },
	Layout    = "oxyzoxyzoxyzoxyzoxyzoxyzoxyzoxyzoxyzoxyzoxyzoxyzoxyzoxyzoxyzoxyz"
}

function Crypto:NewKey(Key)
	function Key:Serialize() 
		return `{Key.Seed}:{Key.Parts[1]}:{Key.Parts[2]}:{Key.Parts[3]}`
	end

	return Key
end

function Crypto:ParseKey(RawKey)
	local Split =  function(str, sep) -- https://stackoverflow.com/questions/1426954/split-string-in-lua 
		if sep == nil then
			sep = "%s"
		end
		local t={}
		for str in string.gmatch(str, "([^"..sep.."]+)") do
			table.insert(t, tonumber(str))
		end
		return t
	end
	
	local S,P1,P2,P3 = table.unpack(Split(RawKey,":"))
	return Crypto:NewKey({
		Seed = S,
		Parts = {P1,P2,P3}
	})
end

function Crypto:GenKey()
	local RandomClass = Random.new(os.clock()) 
	local Gen = function() return RandomClass:NextNumber() * 100000000 end 
	local Key = {
		Parts = {Gen(),Gen(),Gen()},
		Seed = math.floor(os.clock() * 10^7)
	}

	return Crypto:NewKey(Key)
end

function Crypto:String(Key, BaseString)
	local Last = Key.Seed
	local StrPos, LStrPos = 0, 0
	local NextX = function(E)
		Last = Last - (E and E * Last or 0)
		Last = (Key.Parts[1] * Last + Key.Parts[2]) % Key.Parts[3]
		return Last
	end
	local NextY
	NextY = function(G, A)
		StrPos = A and StrPos + NextX() % math.floor(#BaseString / 2) or StrPos + 1
		if not G and StrPos == LStrPos then return NextY() end
		if StrPos > #BaseString then
			StrPos = 1
		end

		LStrPos = StrPos

		return string.byte(BaseString:sub(StrPos, StrPos))
	end
	local Range = function(I, MN, MX)
		return ((I - 1) % ((MX - MN) + 1)) + MN;
	end
	return string.gsub(Crypto.Layout, '[xyzo]', function(c)
		local v = 0
		if c == 'x' then
			v = NextX(NextY(nil, true)) -- Sequentional Anti-Repeat Key Stepping
		elseif c == 'y' then
			v = NextX(NextY()) -- Random Key Stepping
		elseif c == 'z' then
			v = NextX() -- Random Seeding Steeping
		elseif c == 'o' then
			v = NextY(true, true) -- Sequentional Key Stepping
		end
		v = v or 1
		
		return string.char(Range(math.abs(v), Crypto.IntRange[1], Crypto.IntRange[2]))
	end), BaseString
end

return Crypto