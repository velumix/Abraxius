--[=[
	@interface Middleware
	.Inbound ClientMiddleware?
	.Outbound ClientMiddleware?
	@within NerveClient
]=]
type Middleware = {
	Inbound: ClientMiddleware?,
	Outbound: ClientMiddleware?,
}

--[=[
	@type ClientMiddlewareFn (args: {any}) -> (shouldContinue: boolean, ...: any)
	@within NerveClient

	For more info, see [ClientComm](https://sleitnick.github.io/RbxUtil/api/ClientComm/) documentation.
]=]
type ClientMiddlewareFn = (args: { any }) -> (boolean, ...any)

--[=[
	@type ClientMiddleware {ClientMiddlewareFn}
	@within NerveClient
	An array of client middleware functions.
]=]
type ClientMiddleware = { ClientMiddlewareFn }

--[=[
	@type PerServiceMiddleware {[string]: Middleware}
	@within NerveClient
]=]
type PerServiceMiddleware = { [string]: Middleware }

--[=[
	@interface ControllerDef
	.Name string
	.[any] any
	@within NerveClient
	Used to define a controller when creating it in `CreateController`.
]=]
type ControllerDef = {
	Name: string,
	[any]: any,
}

--[=[
	@interface Controller
	.Name string
	.[any] any
	@within NerveClient
]=]
type Controller = {
	Name: string,
	[any]: any,
}

--[=[
	@interface Service
	.[any] any
	@within NerveClient
]=]
type Service = {
	[any]: any,
}

--[=[
	@interface NerveOptions
	.ServicePromises boolean?
	.Middleware Middleware?
	.PerServiceMiddleware PerServiceMiddleware?
	@within NerveClient

	- `ServicePromises` defaults to `true` and indicates if service methods use promises.
	- Each service will go through the defined middleware, unless the service
	has middleware defined in `PerServiceMiddleware`.
]=]
type NerveOptions = {
	ServicePromises: boolean,
	Middleware: Middleware?,
	PerServiceMiddleware: PerServiceMiddleware?,
}

local defaultOptions: NerveOptions = {
	ServicePromises = true,
	Middleware = nil,
	PerServiceMiddleware = {},
}

local selectedOptions = nil

--[=[
	@class NerveClient
	@client
]=]
local NerveClient = {}
NerveClient.Version = "1.3.0"

--[=[
	@prop Player Player
	@within NerveClient
	@readonly
	Reference to the LocalPlayer.
]=]
NerveClient.Player = game:GetService("Players").LocalPlayer

--[=[
	@prop Util Folder
	@within NerveClient
	@readonly
	References the Util folder. Should only be accessed when using Nerve as
	a standalone module. If using Nerve from Wally, modules should just be
	pulled in via Wally instead of relying on Nerve's Util folder, as this
	folder only contains what is necessary for Nerve to run in Wally mode.
]=]
NerveClient.Dependencies = script.Parent.Dependencies
NerveClient.Util = NerveClient.Dependencies

local Promise = require(NerveClient.Dependencies.Promise)
local ByteNetRuntime = require(script.Parent.Runtime)
local Lifecycle = require(script.Parent.Lifecycle)
local Schema = require(script.Parent.Schema)

NerveClient.Schema = Schema
NerveClient.ByteNet = require(NerveClient.Dependencies.ByteNet)
NerveClient.Promise = Promise
NerveClient.SignalClass = require(NerveClient.Dependencies.Signal)
NerveClient.Method = ByteNetRuntime.Method
NerveClient.Signal = ByteNetRuntime.Signal

function NerveClient.GetDependency(name: string): any
	assert(type(name) == "string" and name ~= "", "dependency name must be a non-empty string")
	local dependency = NerveClient.Dependencies:FindFirstChild(name)
	assert(dependency and dependency:IsA("ModuleScript"), `Unknown Nerve dependency "{name}"`)
	return require(dependency)
end

local controllers: { [string]: Controller } = {}
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

local function DoesControllerExist(controllerName: string): boolean
	local controller: Controller? = controllers[controllerName]

	return controller ~= nil
end

local function BuildService(serviceName: string)
	local service = ByteNetRuntime.GetClientService(serviceName)

	services[serviceName] = service

	return service
end

--[=[
	Creates a new controller.

	:::caution
	Controllers must be created _before_ calling `Nerve.Start()`.
	:::
	```lua
	-- Create a controller
	local MyController = Nerve.CreateController {
		Name = "MyController",
	}

	function MyController:NerveStart()
		print("MyController started")
	end

	function MyController:NerveInit()
		print("MyController initialized")
	end
	```
]=]
function NerveClient.CreateController(controllerDef: ControllerDef): Controller
	assert(type(controllerDef) == "table", `Controller must be a table; got {type(controllerDef)}`)
	assert(type(controllerDef.Name) == "string", `Controller.Name must be a string; got {type(controllerDef.Name)}`)
	assert(#controllerDef.Name > 0, "Controller.Name must be a non-empty string")
	assert(not DoesControllerExist(controllerDef.Name), `Controller {controllerDef.Name} already exists`)
	assert(not started, `Controllers cannot be created after calling "Nerve.Start()"`)

	local controller = controllerDef :: Controller
	controllers[controller.Name] = controller

	return controller
end

--[=[
	Requires all the modules that are children of the given parent. This is an easy
	way to quickly load all controllers that might be in a folder.
	```lua
	Nerve.AddControllers(somewhere.Controllers)
	```
]=]
function NerveClient.AddControllers(parent: Instance): { Controller }
	assert(not started, `Controllers cannot be added after calling "Nerve.Start()"`)

	local addedControllers = {}
	for _, v in parent:GetChildren() do
		if not v:IsA("ModuleScript") then
			continue
		end

		table.insert(addedControllers, require(v))
	end

	return addedControllers
end

--[=[
	Requires all the modules that are descendants of the given parent.
]=]
function NerveClient.AddControllersDeep(parent: Instance): { Controller }
	assert(not started, `Controllers cannot be added after calling "Nerve.Start()"`)

	local addedControllers = {}
	for _, v in parent:GetDescendants() do
		if not v:IsA("ModuleScript") then
			continue
		end

		table.insert(addedControllers, require(v))
	end

	return addedControllers
end

--[=[
	Returns a Service object which is a reflection of the remote objects
	within the Client table of the given service. Throws an error if the
	service is not found.

	If a service's Client table contains RemoteSignals and/or RemoteProperties,
	these values are reflected as
	[ClientRemoteSignals](https://sleitnick.github.io/RbxUtil/api/ClientRemoteSignal) and
	[ClientRemoteProperties](https://sleitnick.github.io/RbxUtil/api/ClientRemoteProperty).

	```lua
	-- Server-side service creation:
	local MyService = Nerve.CreateService {
		Name = "MyService",
		Client = {
			MySignal = Nerve.CreateSignal(),
			MyProperty = Nerve.CreateProperty("Hello"),
		},
	}
	function MyService:AddOne(player, number)
		return number + 1
	end

	-------------------------------------------------

	-- Client-side service reflection:
	local MyService = Nerve.GetService("MyService")

	-- Call a method:
	local num = MyService:AddOne(5) --> 6

	-- Fire a signal to the server:
	MyService.MySignal:Fire("Hello")

	-- Listen for signals from the server:
	MyService.MySignal:Connect(function(message)
		print(message)
	end)

	-- Observe the initial value and changes to properties:
	MyService.MyProperty:Observe(function(value)
		print(value)
	end)
	```

	:::caution
	Services are only exposed to the client if the service has remote-based
	content in the Client table. If not, the service will not be visible
	to the client. `NerveClient.GetService` will only work on services that
	expose remote-based content on their Client tables.
	:::
]=]
function NerveClient.GetService(serviceName: string): Service
	local service = services[serviceName]
	if service then
		return service
	end

	assert(started, "Cannot call GetService until Nerve has been started")
	assert(type(serviceName) == "string", `ServiceName must be a string; got {type(serviceName)}`)

	return BuildService(serviceName)
end

--[=[
	Gets the controller by name. Throws an error if the controller
	is not found.
]=]
function NerveClient.GetController(controllerName: string): Controller
	local controller = controllers[controllerName]
	if controller then
		return controller
	end

	assert(started, "Cannot call GetController until Nerve has been started")
	assert(type(controllerName) == "string", `ControllerName must be a string; got {type(controllerName)}`)
	error(`Could not find controller "{controllerName}". Check to verify a controller with this name exists.`, 2)
end

--[=[
	Gets a table of all controllers.
]=]
function NerveClient.GetControllers(): { [string]: Controller }
	assert(started, "Cannot call GetControllers until Nerve has been started")

	return controllers
end

--[=[
	@return Promise
	Starts Nerve. Should only be called once per client.
	```lua
	Nerve.Start():andThen(function()
		print("Nerve started!")
	end):catch(warn)
	```

	By default, service methods exposed to the client will return promises.
	To change this behavior, set the `ServicePromises` option to `false`:
	```lua
	Nerve.Start({ServicePromises = false}):andThen(function()
		print("Nerve started!")
	end):catch(warn)
	```
]=]
function NerveClient.Start(options: NerveOptions?)
	if started then
		return Promise.reject("Nerve already started")
	end

	started = true

	table.freeze(controllers)

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
	if type(selectedOptions.PerServiceMiddleware) ~= "table" then
		selectedOptions.PerServiceMiddleware = {}
	end

	startPromise = Promise.try(function()
		ByteNetRuntime.StartClient(selectedOptions)
	end)
		:andThen(function()
			return Lifecycle.Run(controllers, "NerveInit", "controller", Promise)
		end)
		:andThen(function()
			return Lifecycle.Run(controllers, "NerveStart", "controller", Promise)
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
	for any code that needs to tie into Nerve controllers but is not the script
	that called `Start`.
	```lua
	Nerve.OnStart():andThen(function()
		local MyController = Nerve.GetController("MyController")
		MyController:DoSomething()
	end):catch(warn)
	```
]=]
function NerveClient.OnStart()
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

return NerveClient
