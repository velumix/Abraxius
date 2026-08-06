-- intykat 2024
-- states.... they do the stating of the
local ServerState = require(script.ServerState)
local ClientState = require(script.ClientState)

return {
	Client = {GetState = ClientState.GetState},
	Server = {GetState = ServerState.GetState}
}