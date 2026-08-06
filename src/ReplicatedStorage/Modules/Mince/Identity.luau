--!nocheck 
export type Identity = "Server" | "Client" 
local ThisIdentity = game:GetService("RunService"):IsServer() and "Server" or "Client" 
return ThisIdentity