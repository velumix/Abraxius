local charset = ""
-- compilicated binary base94
local readable = {33,126}
local depth = readable[2]-readable[1] 
for i=readable[1],readable[2] do 
	charset = charset .. string.char(i)
end 
local floor,insert = math.floor, table.insert
function encode(n)
	local t , n , b , sign = {} , floor(n) , string.len(charset) , ""
	repeat
		local d = (n % b) + 1
		n = floor(n / b)
		insert(t, 1, charset:sub(d,d))
	until n == 0
	return table.concat(t,"")
end

function decode(str) 
	local n , e , x , b = #str , 0 , 0  , string.len(charset)
	repeat 
		local v = string.byte(str:sub(n,n))-readable[1]
		if e > 0 then
			v = (v*(b^e))
		end 
		x = x + v  
		n = n - 1 
		e = e + 1 
	until n == 0
	return floor(x) 
end 
-- ^Binary
local CHAR_SET = [[ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!#$%&()*+,./:;<=>?@[]^_`{|}~"]]
local encode_CharSet = {}
local decode_CharSet = {}
for i = 1, 91 do
	encode_CharSet[i-1] = string.sub(CHAR_SET, i, i)
	decode_CharSet[string.sub(CHAR_SET, i, i)] = i-1
end
local function encodeBase91(input)
	local output = {}
	local c = 1

	local counter = 0
	local numBits = 0

	for i = 1, #input do
		counter = bit32.bor(counter, bit32.lshift(string.byte(input, i), numBits))
		numBits = numBits+8
		if numBits > 13 then
			local entry = bit32.band(counter, 8191) -- 2^13-1 = 8191
			if entry > 88 then -- Voodoo magic (https://www.reddit.com/r/learnprogramming/comments/8sbb3v/understanding_base91_encoding/e0y85ot/)
				counter = bit32.rshift(counter, 13)
				numBits = numBits-13
			else
				entry = bit32.band(counter, 16383) -- 2^14-1 = 16383
				counter = bit32.rshift(counter, 14)
				numBits = numBits-14
			end
			output[c] = encode_CharSet[entry%91]..encode_CharSet[math.floor(entry/91)]
			c = c+1
		end
	end

	if numBits > 0 then
		output[c] = encode_CharSet[counter%91]
		if numBits > 7 or counter > 90 then
			output[c+1] = encode_CharSet[math.floor(counter/91)]
		end
	end

	return table.concat(output)
end
local function decodeBase91(input)
	local output = {}
	local c = 1

	local counter = 0
	local numBits = 0
	local entry = -1

	for i = 1, #input do
		if decode_CharSet[string.sub(input, i, i)] then
			if entry == -1 then
				entry = decode_CharSet[string.sub(input, i, i)]
			else
				entry = entry+decode_CharSet[string.sub(input, i, i)]*91
				counter = bit32.bor(counter, bit32.lshift(entry, numBits))
				if bit32.band(entry, 8191) > 88 then
					numBits = numBits+13
				else
					numBits = numBits+14
				end

				while numBits > 7 do
					output[c] = string.char(counter%256)
					c = c+1
					counter = bit32.rshift(counter, 8)
					numBits = numBits-8
				end
				entry = -1
			end
		end
	end

	if entry ~= -1 then
		output[c] = string.char(bit32.bor(counter, bit32.lshift(entry, numBits))%256)
	end

	return table.concat(output)
end
-- ^Base91
local LTCS = {
	_VERSION = 0.36
} 

LTCS.SpecialChars = ",^*#\"?{}";
LTCS.EscapeCharacter = "\\"

LTCS.Indents = {"Ordered","NumberHash","NumberSmall","Number","String","Bool","Table","TableAnchor"}
LTCS.IdentsToChar = {}
LTCS.CharToIdents = {} 

LTCS.Cast = {} 
LTCS.Vert = {}

function LTCS.EscapeGsub(x)
	return (x:gsub('%%', '%%%%'):gsub('^%^', '%%^'):gsub('%$$', '%%$'):gsub('%(', '%%('):gsub('%)', '%%)'):gsub('%.', '%%.'):gsub('%[', '%%['):gsub('%]', '%%]'):gsub('%*', '%%*') :gsub('%+', '%%+'):gsub('%-', '%%-'):gsub('%?', '%%?'))
end
function LTCS.EscapeAllIdents(String) 
	for i=1,#LTCS.Indents do
		local Symbol = LTCS.SpecialChars:sub(i,i)
		String = String:gsub(LTCS.EscapeGsub(Symbol),LTCS.EscapeGsub("\\"..Symbol))
	end
	return String 
end 

function LTCS.EscapeStringableIdents(String) 
	String = String:gsub(LTCS.EscapeGsub(LTCS.EscapeCharacter),LTCS.EscapeGsub(string.rep(LTCS.EscapeCharacter,2)))
	
	local TableIdents = {"String","Table","TableAnchor"}
	for i=1,#TableIdents do
		local Symbol = LTCS.IdentsToChar[TableIdents[i]]
		String = String:gsub(LTCS.EscapeGsub(Symbol),LTCS.EscapeGsub("\\"..Symbol))
	end
	
	return String 
end

function LTCS.EscapeSymbol(String,IdentName) 
	local Symbol = LTCS.IdentsToChar[IdentName]
	String = String:gsub(LTCS.EscapeGsub(Symbol),LTCS.EscapeGsub("\\"..Symbol))
	return String
end 

function LTCS.DescapeSymbol(String,IdentName) 
	local Symbol = LTCS.IdentsToChar[IdentName]
	String = String:gsub(LTCS.EscapeGsub("\\"..Symbol),LTCS.EscapeGsub(Symbol))
	return String
end 

function LTCS.DescapeStringableIdents(String,IdentName)
	
	String = String:gsub(LTCS.EscapeGsub(string.rep(LTCS.EscapeCharacter,2)),LTCS.EscapeGsub(LTCS.EscapeCharacter))
	
	local TableIdents = {"String","Table","TableAnchor"}
	for i=1,#TableIdents do
		local Symbol = LTCS.IdentsToChar[TableIdents[i]]
		String = String:gsub(LTCS.EscapeGsub("\\"..Symbol),LTCS.EscapeGsub(Symbol))
	end
	return String 
end


function LTCS.AssignIdents()
	for i=1,#LTCS.Indents do
		local Ident , Char = LTCS.Indents[i] , LTCS.SpecialChars:sub(i,i)
		LTCS.IdentsToChar[Ident] = Char 
		LTCS.CharToIdents[Char] = Ident
	end
end

function LTCS.GenerateValue(Value,Type)
	local Method = LTCS.Cast[Type] 
	if Method then 
		return Method(Value,Type) 
	end 
end 

function LTCS.ConvertValue(Value,Type,Order) 
	local Method = LTCS.Vert[Type]
	if Method then 
		return Method(Value,Type,Order)
	end 
end 

function LTCS.GetMember(char)  
	return LTCS.CharToIdents[char] 
end 


function LTCS.Encode(Table,Order)    
	local String , Size, Ordered = "" , #Table , false 
	-- checke if ordered.
	for Index,Value in ipairs(Table) do Ordered = true 
		local ValueConv = LTCS.GenerateValue(Value, type(Value))
		if ValueConv then 
			String = String .. LTCS.IdentsToChar["Ordered"] .. ValueConv 
		end 
	end

    for Index,Value in pairs(Table) do
		local IndexType = type(Index)
		if Ordered and IndexType == "number" then 
			if Index <= Size then 
				IndexType = "Invalid"
			end 
		end 
		
		local IndexConv =  LTCS.GenerateValue(Index,IndexType)
		if IndexConv then 
			local ValueConv = LTCS.GenerateValue(Value,type(Value))
			if ValueConv then 
				String = String .. IndexConv .. ValueConv
			end 
		end 
	end 
	return String
end


function LTCS.Throw(pos,str) 
	error(pos .. ":~|" .. str)
end 

function LTCS.ReadBase92Stream(String,Pos)
	local i = Pos-1
	while i < #String do i = i + 1
		local Character = String:sub(i,i)
		if Character == " " then 
			return String:sub(Pos,i-1) , i+1
		end
	end
	return String:sub(Pos,i) , i
end

function LTCS.ReadStream(String,Pos,Match,Open,IgnoreIdent) 
	local i = Pos-1
	local Limit , Ignore = 0 , false 
	local Escape = i-1
	while i < #String do i = i + 1
		local Character = String:sub(i,i)
		local Member = LTCS.GetMember(Character)
		
		if Character == LTCS.EscapeCharacter and i > Escape then 
			Escape = i+1
		end
		
		if i > Escape then 
			
			if IgnoreIdent then 
				if Match then 
					if Member == IgnoreIdent then 
						--Ignore = not Ignore 
					end
				end
			end
			if Match then 
				if Member == Match and Limit < 1 then 
					--warn("<- Ending Match")
					return String:sub(Pos,i-1) , i
				end 
				if not Ignore then 
					if Member == Open then 
						Limit = Limit + 1 
					end 
					if Member == Match then 
						Limit = Limit - 1 
					end
				end
			else
				if Member then 
					--warn("<- No Match Member Detected.")
					return String:sub(Pos,i-1) , i
				end 
			end 
		end 
	end 
	--warn("<- Reached End")
	return String:sub(Pos,i) , i
end 

function LTCS.Decode(String) 
	local Order = 0  
	local Table , i = {} , 1
	while i < #String-1  do 
		local IndexRawData = String:sub(i,i)
		local IndexMember , IndexData = LTCS.GetMember(IndexRawData) ; i = i + 1 
		if not IndexMember then
			LTCS.Throw(i,"[Index]Failed to find member for " .. String:sub(i-1,i-1)) 
		end 
		if IndexMember == "Ordered" then 
			Order = Order + 1 
		end 
		if IndexMember == "String" then 
			IndexData , NewPos = LTCS.ReadStream(String,i,"String","Invalid") i = NewPos+1
		elseif IndexMember == "NumberHash" or IndexMember == "NumberSmall" then 
			IndexData , NewPos = LTCS.ReadBase92Stream(String,i) i = NewPos
		elseif IndexMember == "Table" then 
			-- Table Decoding
			IndexData , NewPos = LTCS.ReadStream(String,i,"TableAnchor","Table","String") i = NewPos+1
		else
			IndexData , NewPos = LTCS.ReadStream(String,i) i = NewPos
		end 

		local ValueRawData = String:sub(i,i)
		local ValueMember , ValueData = LTCS.GetMember(ValueRawData) ; i = i + 1  

		if not ValueMember then 
			LTCS.Throw(i,"[Value]Failed to find member for " .. String:sub(i-1,i-1)) 
		end 
		if ValueMember == "String" then 
			ValueData , NewPos = LTCS.ReadStream(String,i,"String","Invalid") i = NewPos+1
		elseif ValueMember == "NumberHash" or ValueMember == "NumberSmall" then
			ValueData , NewPos = LTCS.ReadBase92Stream(String,i) i = NewPos
		elseif ValueMember == "Table" then 
			-- Table Decoding
			ValueData , NewPos = LTCS.ReadStream(String,i,"TableAnchor","Table","String") i = NewPos+1
		else
			ValueData , NewPos = LTCS.ReadStream(String,i) i = NewPos
		end
		local Value , Index = LTCS.ConvertValue(ValueData,ValueMember,Order) 
		if Value ~= nil  then 
			Index = LTCS.ConvertValue(IndexData,IndexMember,Order) 
			if Index == nil then 
				LTCS.Throw(i,"IndexData was not able to convert ["..IndexMember.."]")
			end 
		else
			LTCS.Throw(i,"ValueData was not able to convert ["..ValueMember.."]")
		end 
		Table[Index] = Value 
	end 
	return Table 
end 


function LTCS.EncodeBase91(Text) 
	return encodeBase91(LTCS.Encode(Text))
end

function LTCS.DecodeBase91(Text) 
	return LTCS.Decode(decodeBase91(Text))
end


-- Intilization 
LTCS.AssignIdents()

LTCS.Cast.number = function(Value,Type)
	if Value == math.floor(Value) then 
		if #tostring(Value) > 2 then 
			local String = encode(Value)
			return 	LTCS.IdentsToChar["NumberSmall"] .. LTCS.EscapeStringableIdents(String) .. " "
		end
	end
	-- If more than 5 bytes 
	if #tostring(Value) > 5 then 
		local String = encodeBase91(string.pack("f",Value))
		return LTCS.IdentsToChar["NumberHash"] .. LTCS.EscapeStringableIdents(String) .. " "	
	else 
		return LTCS.IdentsToChar["Number"] .. Value 	
	end
end
LTCS.Cast.string = function(Value,Type)
	return LTCS.IdentsToChar["String"] .. LTCS.EscapeStringableIdents(Value) ..  LTCS.IdentsToChar["String"] 
end

LTCS.Cast.boolean = function(Value,Type) 
	return LTCS.IdentsToChar["Bool"] .. ({[true]="1",[false]="0"})[Value]
end 

LTCS.Cast.table = function(Value,Type) 
	return LTCS.IdentsToChar["Table"] .. LTCS.Encode( Value )  .. LTCS.IdentsToChar["TableAnchor"] 
end 

LTCS.Vert.Bool = function(Value,Type) 
	return ({["1"]=true,["0"]=false})[Value]
end

LTCS.Vert.Number = function(Value,Type) 
	return tonumber(Value)
end 

LTCS.Vert.NumberHash = function(Value,Type)
	local String = LTCS.DescapeStringableIdents(Value) 
	return string.unpack("f",decodeBase91(String))
end 

LTCS.Vert.NumberSmall = function(Value,Type) 
	local String = LTCS.DescapeStringableIdents(Value) 
	return decode(String)
end

LTCS.Vert.String = function(Value,Type) 
	return LTCS.DescapeStringableIdents(Value) 
end 

LTCS.Vert.Table = function(Value,Type) 
	return LTCS.Decode(Value)
end 

LTCS.Vert.Ordered = function(Value,Type,Order)
	return Order
end  

return LTCS 