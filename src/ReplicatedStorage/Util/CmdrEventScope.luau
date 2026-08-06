--!strict
-- Bridge between Cmdr types: eventName's Transform stashes the resolved
-- event here so dependent argument types (e.g. eventAdminAction) can scope
-- their autocomplete to it. Cmdr doesn't pass prior-arg context into type
-- callbacks, so a shared module is the cleanest hand-off.
local CmdrEventScope = {}

CmdrEventScope.lastEvent = nil :: string?

return CmdrEventScope
