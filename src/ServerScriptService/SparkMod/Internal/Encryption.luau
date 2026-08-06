--[[
	SparkMod — Centralized Coordinator for Roblox Game Servers

	Copyright 2026 Nicholas Rice

	Licensed under the Apache License, Version 2.0 (the "License");
	you may not use this file except in compliance with the License.
	You may obtain a copy of the License at

		http://www.apache.org/licenses/LICENSE-2.0

	Unless required by applicable law or agreed to in writing, software
	distributed under the License is distributed on an "AS IS" BASIS,
	WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
	See the License for the specific language governing permissions and
	limitations under the License.
]]
--!strict


local HttpService = game:GetService("HttpService")

-- ========== Constants ========== --

local BLOCK_SIZE = 64
local NONCE_LENGTH = 16

-- ========== SHA-256 ========== --

local K = {
	0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5,
	0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
	0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
	0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
	0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc,
	0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
	0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
	0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
	0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
	0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
	0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3,
	0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
	0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5,
	0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
	0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
	0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
}

local function rightRotate(value: number, bits: number): number
	return bit32.bor(bit32.rshift(value, bits), bit32.lshift(value, 32 - bits))
end

local function sha256(message: string): string
	local msgLen = #message
	local bitLen = msgLen * 8

	-- Padding
	message ..= "\128"
	while (#message % 64) ~= 56 do
		message ..= "\0"
	end
	-- Append length as 64-bit big-endian
	for i = 56, 0, -8 do
		message ..= string.char(bit32.band(bit32.rshift(bitLen, i), 0xFF))
	end

	local h0 = 0x6a09e667
	local h1 = 0xbb67ae85
	local h2 = 0x3c6ef372
	local h3 = 0xa54ff53a
	local h4 = 0x510e527f
	local h5 = 0x9b05688c
	local h6 = 0x1f83d9ab
	local h7 = 0x5be0cd19

	for chunkStart = 1, #message, 64 do
		local w = table.create(64, 0)

		for i = 0, 15 do
			local offset = chunkStart + i * 4
			w[i + 1] = bit32.bor(
				bit32.lshift(string.byte(message, offset), 24),
				bit32.lshift(string.byte(message, offset + 1), 16),
				bit32.lshift(string.byte(message, offset + 2), 8),
				string.byte(message, offset + 3)
			)
		end

		for i = 17, 64 do
			local s0 = bit32.bxor(rightRotate(w[i - 15], 7), rightRotate(w[i - 15], 18), bit32.rshift(w[i - 15], 3))
			local s1 = bit32.bxor(rightRotate(w[i - 2], 17), rightRotate(w[i - 2], 19), bit32.rshift(w[i - 2], 10))
			w[i] = bit32.band(w[i - 16] + s0 + w[i - 7] + s1, 0xFFFFFFFF)
		end

		local a, b, c, d, e, f, g, h = h0, h1, h2, h3, h4, h5, h6, h7

		for i = 1, 64 do
			local S1 = bit32.bxor(rightRotate(e, 6), rightRotate(e, 11), rightRotate(e, 25))
			local ch = bit32.bxor(bit32.band(e, f), bit32.band(bit32.bnot(e), g))
			local temp1 = bit32.band(h + S1 + ch + K[i] + w[i], 0xFFFFFFFF)
			local S0 = bit32.bxor(rightRotate(a, 2), rightRotate(a, 13), rightRotate(a, 22))
			local maj = bit32.bxor(bit32.band(a, b), bit32.band(a, c), bit32.band(b, c))
			local temp2 = bit32.band(S0 + maj, 0xFFFFFFFF)

			h = g
			g = f
			f = e
			e = bit32.band(d + temp1, 0xFFFFFFFF)
			d = c
			c = b
			b = a
			a = bit32.band(temp1 + temp2, 0xFFFFFFFF)
		end

		h0 = bit32.band(h0 + a, 0xFFFFFFFF)
		h1 = bit32.band(h1 + b, 0xFFFFFFFF)
		h2 = bit32.band(h2 + c, 0xFFFFFFFF)
		h3 = bit32.band(h3 + d, 0xFFFFFFFF)
		h4 = bit32.band(h4 + e, 0xFFFFFFFF)
		h5 = bit32.band(h5 + f, 0xFFFFFFFF)
		h6 = bit32.band(h6 + g, 0xFFFFFFFF)
		h7 = bit32.band(h7 + h, 0xFFFFFFFF)
	end

	return string.format(
		"%08x%08x%08x%08x%08x%08x%08x%08x",
		h0, h1, h2, h3, h4, h5, h6, h7
	)
end

-- ========== HMAC-SHA256 ========== --

local function hmacSha256(key: string, message: string): string
	if #key > BLOCK_SIZE then
		-- Hash the key if longer than block size
		local hashed = sha256(key)
		key = ""
		for i = 1, #hashed, 2 do
			key ..= string.char(tonumber(hashed:sub(i, i + 1), 16) :: number)
		end
	end

	while #key < BLOCK_SIZE do
		key ..= "\0"
	end

	local oKeyPad = ""
	local iKeyPad = ""
	for i = 1, BLOCK_SIZE do
		local byte = string.byte(key, i)
		oKeyPad ..= string.char(bit32.bxor(byte, 0x5C))
		iKeyPad ..= string.char(bit32.bxor(byte, 0x36))
	end

	local innerHash = sha256(iKeyPad .. message)

	-- Convert hex string back to bytes for outer hash
	local innerBytes = ""
	for i = 1, #innerHash, 2 do
		innerBytes ..= string.char(tonumber(innerHash:sub(i, i + 1), 16) :: number)
	end

	return sha256(oKeyPad .. innerBytes)
end

-- ========== Module ========== --

local module = {}

function module.GenerateNonce(): string
	local chars = {}
	for _ = 1, NONCE_LENGTH do
		table.insert(chars, string.format("%02x", math.random(0, 255)))
	end
	return table.concat(chars)
end

function module.Sign(apiKey: string, method: string, path: string, bodyString: string?): (string, string, number, string?)
	local nonce = module.GenerateNonce()
	local timestamp = os.time()
	local bodyHash = if bodyString and #bodyString > 0 then sha256(bodyString) else nil
	local signingInput = `{nonce}.{timestamp}.{method}.{path}.{bodyHash or ""}`
	local signature = hmacSha256(apiKey, signingInput)
	return signature, nonce, timestamp, bodyHash
end

function module.BuildSignedHeaders(apiKey: string, method: string, path: string, bodyString: string?): { [string]: string }
	local signature, nonce, timestamp, bodyHash = module.Sign(apiKey, method, path, bodyString)
	local headers = {
		["x-api-key"] = apiKey,
		["x-signature"] = signature,
		["x-nonce"] = nonce,
		["x-timestamp"] = tostring(timestamp),
	}
	if bodyHash then
		headers["x-body-hash"] = bodyHash
	end
	return headers
end

module.Sha256 = sha256
module.HmacSha256 = hmacSha256

return table.freeze(module)
