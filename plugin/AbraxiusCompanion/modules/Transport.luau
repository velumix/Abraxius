--!strict
local Transport = {}

function Transport.create(HttpService: HttpService): any
	local function postTo(baseUrl: string, path: string, payload: any): (boolean, any)
		local ok, result = pcall(function()
			return HttpService:RequestAsync({ Url = baseUrl .. path, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = HttpService:JSONEncode(payload) })
		end)
		if not ok then return false, tostring(result) end
		if result.Body then
			local decodeOk, decoded = pcall(HttpService.JSONDecode, HttpService, result.Body)
			if decodeOk then return result.Success, decoded end
		end
		return false, result.Body or "unknown"
	end
	return {
		postTo = postTo,
		bind = function(baseUrl: string): (string, any) -> (boolean, any)
			return function(path: string, payload: any): (boolean, any) return postTo(baseUrl, path, payload) end
		end,
	}
end

return Transport
