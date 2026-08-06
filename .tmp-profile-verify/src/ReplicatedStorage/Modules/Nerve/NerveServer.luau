--[=[
	@interface Middleware
	.Inbound ServerMiddleware?
	.Outbound ServerMiddleware?
	@within NerveServer
]=]
type Middleware = {
	Inbound: ServerMiddleware?,
	Outbound: ServerMiddleware?,
}

--[=[
	@type ServerMiddlewareFn (player: Player, args: {any}) -> (shouldContinue: boolean, ...: any)
	@within NerveServer

	For more info, see [ServerComm](https://sleitnick.github.io/RbxUtil/api/ServerComm/) documentation.
]=]
type ServerMiddlewareFn = (player: Player, args: { any }) -> (boolean, ...any)

--[=[
	@type ServerMiddleware {ServerMiddlewareFn}
	@within NerveServer
	An array of server middleware functions.
]=]
type ServerMiddleware = { ServerMiddlewareFn }

--[=[
	@interface ServiceDef
	.Name string
	.Client table?
	.Middleware Middleware?
	.[any] any
	@within NerveServer
	Used to define a service when creating it in `CreateService`.

	The middleware tables provided will be used instead of the Nerve-level
	middleware (if any). This allows fine-tuning each service's middleware.
	These can also be left out or `nil` to not include middleware.
]=]
type ServiceDef = {
	Name: string,
	Client: { [any]: any }?,
	Middleware: Middleware?,
	[any]: any,
}

--[=[
	@interface Service
	.Name string
	.Client ServiceClient
	.NerveComm Comm
	.[any] any
	@within NerveServer
]=]
type Service = {
	Name: string,
	Client: ServiceClient,
	[any]: any,
}

--[=[
	@interface ServiceClient
	.Server Service
	.[any] any
	@within NerveServer
]=]
type ServiceClient = {
	Server: Service,
	[any]: any,
}

--[=[
	@interface NerveOptions
	.Middleware Middleware?
	@within NerveServer

	- Middleware will apply to all services _except_ ones that define
	their own middleware.
]=]
type NerveOptions = {
	Middleware: Middleware?,
}

local defaultOptions: NerveOptions = {
	Middleware = nil,
}

local selectedOptions = nil

--[=[
	@class NerveServer
	@server
	Nerve server-side lets developers create services and expose methods and signals
	to the clients.

	```lua
	local Nerve = require(somewhere.Nerve)

	-- Load service modules within some folder:
	Nerve.AddServices(somewhere.Services)

	-- Start Nerve:
	Nerve.Start():andThen(function()
		print("Nerve started")
	end):catch(warn)
	```
]=]
local NerveServer = {}
NerveServer.Version = "1.3.0"

--[=[
	@prop Util Folder
	@within NerveServer
	@readonly
	References the Util folder. Should only be accessed when using Nerve as
	a standalone module. If using Nerve from Wally, modules should just be
	pulled in via Wally instead of relying on Nerve's Util folder, as this
	folder only contains what is necessary for Nerve to run in Wally mode.
]=]
NerveServer.Dependencies = script.Parent.Dependencies
NerveServer.Util = NerveServer.Dependencies

local Promise = require(NerveServer.Dependencies.Promise)
local ByteNetRuntime = require(script.Parent.Runtime)
local Lifecycle = require(script.Parent.Lifecycle)
local Schema = require(script.Parent.Schema)

NerveServer.Schema = Schema
NerveServer.ByteNet = require(NerveServer.Dependencies.ByteNet)
NerveServer.Promise = Promise
NerveServer.SignalClass = require(NerveServer.Dependencies.Signal)

function NerveServer.GetDependency(name: string): any
	assert(type(name) == "string" and name ~= "", "dependency name must be a non-empty string")
	local dependency = NerveServer.Dependencies:FindFirstChild(name)
	assert(dependency and dependency:IsA("ModuleScript"), `Unknown Nerve dependency "{name}"`)
	return require(dependency)
end

-- Defines a typed client-to-server request/response contract for a Client
-- method. Put these under a service's Network table using the same member name.
NerveServer.Method = ByteNetRuntime.Method

-- Defines an explicitly directed ByteNet signal. Server-to-client is the safe
-- default; pass Direction = "client" or "duplex" only when required.
NerveServer.Signal = ByteNetRuntime.Signal

local services: { [string]: Service } = {}
local started = false
local startedComplete = false
local startFailed = false
local startFailure = nil
local startPromise = nil
local startWaiters = {}

local function settleStartWaiters(succeeded: boolean, reason: any?)
	for _, waiter in startWaiters do
		if succeeded then
			waiter.Resolve()
		else
			waiter.Reject(reason)
		end
	end

	table.clear(startWaiters)
end

local function DoesServiceExist(serviceName: string): boolean
	local service: Service? = services[serviceName]

	return service ~= nil
end

--[=[
	Constructs a new service.

	:::caution
	Services must be created _before_ calling `Nerve.Start()`.
	:::
	```lua
	-- Create a service
	local MyService = Nerve.CreateService {
		Name = "MyService",
		Client = {},
	}

	-- Expose a ToAllCaps remote function to the clients
	function MyService.Client:ToAllCaps(player, msg)
		return msg:upper()
	end

	-- Nerve will call NerveStart after all services have been initialized
	function MyService:NerveStart()
		print("MyService started")
	end

	-- Nerve will call NerveInit when Nerve is first started
	function MyService:NerveInit()
		print("MyService initialize")
	end
	```
]=]
function NerveServer.CreateService(serviceDef: ServiceDef): Service
	assert(type(serviceDef) == "table", `Service must be a table; got {type(serviceDef)}`)
	assert(type(serviceDef.Name) == "string", `Service.Name must be a string; got {type(serviceDef.Name)}`)
	assert(#serviceDef.Name > 0, "Service.Name must be a non-empty string")
	assert(not DoesServiceExist(serviceDef.Name), `Service "{serviceDef.Name}" already exists`)
	assert(not started, `Services cannot be created after calling "Nerve.Start()"`)

	local service = serviceDef

	if type(service.Client) ~= "table" then
		service.Client = { Server = service }
	else
		if service.Client.Server ~= service then
			service.Client.Server = service
		end
	end

	services[service.Name] = service

	return service
end

--[=[
	Requires all the modules that are children of the given parent. This is an easy
	way to quickly load all services that might be in a folder.
	```lua
	Nerve.AddServices(somewhere.Services)
	```
]=]
function NerveServer.AddServices(parent: Instance): { Service }
	assert(not started, `Services cannot be added after calling "Nerve.Start()"`)

	local addedServices = {}
	for _, v in parent:GetChildren() do
		if not v:IsA("ModuleScript") then
			continue
		end

		table.insert(addedServices, require(v))
	end

	return addedServices
end

--[=[
	Requires all the modules that are descendants of the given parent.
]=]
function NerveServer.AddServicesDeep(parent: Instance): { Service }
	assert(not started, `Services cannot be added after calling "Nerve.Start()"`)

	local addedServices = {}
	for _, v in parent:GetDescendants() do
		if not v:IsA("ModuleScript") then
			continue
		end

		table.insert(addedServices, require(v))
	end

	return addedServices
end

--[=[
	Gets the service by name. Throws an error if the service is not found.
]=]
function NerveServer.GetService(serviceName: string): Service
	assert(started, "Cannot call GetService until Nerve has been started")
	assert(type(serviceName) == "string", `ServiceName must be a string; got {type(serviceName)}`)

	return assert(services[serviceName], `Could not find service "{serviceName}"`) :: Service
end

--[=[
	Gets a table of all services.
]=]
function NerveServer.GetServices(): { [string]: Service }
	assert(started, "Cannot call GetServices until Nerve has been started")

	return services
end

--[=[
	@return SIGNAL_MARKER
	Returns a marker that will transform the current key into
	a RemoteSignal once the service is created. Should only
	be called within the Client table of a service.

	See [RemoteSignal](https://sleitnick.github.io/RbxUtil/api/RemoteSignal)
	documentation for more info.
	```lua
	local MyService = Nerve.CreateService {
		Name = "MyService",
		Client = {
			-- Create the signal marker, which will turn into a
			-- RemoteSignal when Nerve.Start() is called:
			MySignal = Nerve.CreateSignal(),
		},
	}

	function MyService:NerveInit()
		-- Connect to the signal:
		self.Client.MySignal:Connect(function(player, ...) end)
	end
	```
]=]
function NerveServer.CreateSignal(arguments, options)
	return ByteNetRuntime.Signal(arguments, options)
end

--[=[
	@return UNRELIABLE_SIGNAL_MARKER

	Returns a marker that will transform the current key into
	an unreliable RemoteSignal once the service is created. Should
	only be called within the Client table of a service.

	See [RemoteSignal](https://sleitnick.github.io/RbxUtil/api/RemoteSignal)
	documentation for more info.

	:::info Unreliable Events
	Internally, this uses UnreliableRemoteEvents, which allows for
	network communication that is unreliable and unordered. This is
	useful for events that are not crucial for gameplay, since the
	delivery of the events may occur out of order or not at all.

	See  the documentation for [UnreliableRemoteEvents](https://create.roblox.com/docs/reference/engine/classes/UnreliableRemoteEvent)
	for more info.
]=]
function NerveServer.CreateUnreliableSignal(arguments, options)
	local resolved = if type(options) == "table" then table.clone(options) else {}
	resolved.Reliability = "unreliable"
	return ByteNetRuntime.Signal(arguments, resolved)
end

--[=[
	@return PROPERTY_MARKER
	Returns a marker that will transform the current key into
	a RemoteProperty once the service is created. Should only
	be called within the Client table of a service. An initial
	value can be passed along as well.

	RemoteProperties are great for replicating data to all of
	the clients. Different data can also be set per client.

	See [RemoteProperty](https://sleitnick.github.io/RbxUtil/api/RemoteProperty)
	documentation for more info.

	```lua
	local MyService = Nerve.CreateService {
		Name = "MyService",
		Client = {
			-- Create the property marker, which will turn into a
			-- RemoteProperty when Nerve.Start() is called:
			MyProperty = Nerve.CreateProperty("HelloWorld"),
		},
	}

	function MyService:NerveInit()
		-- Change the value of the property:
		self.Client.MyProperty:Set("HelloWorldAgain")
	end
	```
]=]
function NerveServer.CreateProperty(initialValue: any)
	return ByteNetRuntime.Property(initialValue)
end

--[=[
	@return Promise
	Starts Nerve. Should only be called once.

	Optionally, `NerveOptions` can be passed in order to set
	Nerve's custom configurations.

	:::caution
	Be sure that all services have been created _before_
	calling `Start`. Services cannot be added later.
	:::

	```lua
	Nerve.Start():andThen(function()
		print("Nerve started!")
	end):catch(warn)
	```
	
	Example of Nerve started with options:
	```lua
	Nerve.Start({
		Middleware = {
			Inbound = {
				function(player, args)
					print("Player is giving following args to server:", args)
					return true
				end
			},
		},
	}):andThen(function()
		print("Nerve started!")
	end):catch(warn)
	```
]=]
function NerveServer.Start(options: NerveOptions?)
	if started then
		return Promise.reject("Nerve already started")
	end

	started = true

	table.freeze(services)

	if options == nil then
		selectedOptions = defaultOptions
	else
		assert(typeof(options) == "table", `NerveOptions should be a table or nil; got {typeof(options)}`)
		selectedOptions = options
		for k, v in defaultOptions do
			if selectedOptions[k] == nil then
				selectedOptions[k] = v
			end
		end
	end

	startPromise = Promise.try(function()
		ByteNetRuntime.StartServer(services, selectedOptions)
	end)
		:andThen(function()
			return Lifecycle.Run(services, "NerveInit", "service", Promise)
		end)
		:andThen(function()
			return Lifecycle.Run(services, "NerveStart", "service", Promise)
		end)
		:andThen(function()
			startedComplete = true
			settleStartWaiters(true)
		end)
		:catch(function(reason)
			startFailed = true
			startFailure = reason
			settleStartWaiters(false, reason)
			return Promise.reject(reason)
		end)

	return startPromise
end

--[=[
	@return Promise
	Returns a promise that is resolved once Nerve has started. This is useful
	for any code that needs to tie into Nerve services but is not the script
	that called `Start`.
	```lua
	Nerve.OnStart():andThen(function()
		local MyService = Nerve.Services.MyService
		MyService:DoSomething()
	end):catch(warn)
	```
]=]
function NerveServer.OnStart()
	if startedComplete then
		return Promise.resolve()
	elseif startFailed then
		return Promise.reject(startFailure)
	else
		return Promise.new(function(resolve, reject, onCancel)
			local waiter = {
				Resolve = resolve,
				Reject = reject,
			}
			table.insert(startWaiters, waiter)

			onCancel(function()
				local index = table.find(startWaiters, waiter)
				if index then
					table.remove(startWaiters, index)
				end
			end)
		end)
	end
end

return NerveServer
