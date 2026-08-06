local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Signal = require(ReplicatedStorage.Modules.Signal)
local PoolSimulation = {}
PoolSimulation.__index = PoolSimulation

local BALL_SETUP = {
	{1},{9, 6},{2, 8, 14},
	{10, 7, 15, 5},
	{3, 11, 12, 4, 13}
}

export type BillardBall = {
	Instance: BasePart,
	Position: Vector2,
	Velocity: Vector2,

	Simulate: boolean,
	Bounced: boolean,
	Pocketed: boolean,
	Stationary: boolean
}


function PoolSimulation.new(Options)
	assert(Options.Container, "You must provide a simulation Container!")
	assert(Options.Models, "You must provide a path of the ball models")
	assert(Options.Parent, "You must provide a parent for the billard balls")

	local self = setmetatable({
		Restitution = Options.Restitution or 1,
		Container = Options.Container,
		Friction = Options.Friction or 0.995,
		Radius = Options.Radius or 0.1,
		Models = Options.Models,

		PocketRadius = nil,
		Pockets = {},

		AccumulatedTime = 0,
		Framerate = Options.Framerate or 60,
		RelativePosition = Options.Container.Position - Vector3.new(Options.Container.Size.X / 2, 0, Options.Container.Size.Z / 2),

		Simulation = true,
		CueBall = nil,
		Balls = {},
		Parent = Options.Parent,

		OnCueBallHit = Signal.new(),
		OnBallPocket = Signal.new(),
		OnBallCollision = Signal.new(),
		__InstanceToData = {}
	}, PoolSimulation)

	if Options.ConstructBalls then
		local Id = 1
		local StartX = self.Container.Size.X  / 2
		local StartY = self.Container.Size.Z  * 0.8

		self.CueBall = self:CreateBall(
			0, 
			Vector2.new(
				self.Container.Size.X / 2, 
				self.Container.Size.Z * 0.2
			)
		)
		self.__InstanceToData[self.CueBall.Instance] = self.CueBall

		for Row = 1, #BALL_SETUP do
			for Col = 1, #BALL_SETUP[Row] do
				local OffsetX = (Col - (Row / 2)) * self.Radius * 2 
				local OffsetY = (Row - 1) * self.Radius * 2 * math.cos(math.pi / 6)
				local Position = Vector2.new(StartX + OffsetX, StartY + OffsetY)
				local Data = self:CreateBall(BALL_SETUP[Row][Col], Position)
				self.__InstanceToData[Data.Instance] = Data
			end
		end
	end

	if Options.Pockets then
		for _, Pocket in Options.Pockets do
			if not self.PocketRadius then
				self.PocketRadius = Pocket.Size.Y / 2
			end

			local RelativePocketPosition = Pocket.Position - self.RelativePosition
			print(Vector2.new(RelativePocketPosition.X, RelativePocketPosition.Z))
			self.Pockets[Pocket] = Vector2.new(RelativePocketPosition.X, RelativePocketPosition.Z)
		end
	end

	return self
end

function PoolSimulation:CreateBall(Id: number, Position: Vector2?): BillardBall
	local Ball = self.Models:FindFirstChild(Id):Clone()
	Ball.Anchored = true
	Ball.Size = Vector3.new(
		self.Radius * 2, 
		self.Radius * 2, 
		self.Radius * 2
	)
	Ball.Position = self.RelativePosition + (Position and Vector3.new(Position.X, self.Radius, Position.Y) or Vector3.zero)
	Ball.Parent = self.Parent

	local Data = {
		Instance = Ball,
		Position = Position or Vector2.zero,
		Velocity = Vector2.zero,
		Simulate = true, 
		Pocketed = false,
		Bounced = false,
		Stationary = true
	}

	if Id == "0" then
		self.CueBall = Data
	end

	table.insert(self.Balls, Data)
	return Data
end

function PoolSimulation:DeleteBall(Object: BasePart, Delay: number)
	local Index = nil

	for i, v in self.Balls do
		if v.Instance == Object then
			Index = i
		end
	end

	if Index then
		local Ball = self.Balls[Index]
		Debris:AddItem(Ball.Instance, Delay or 0)

		self.__InstanceToData[Object] = nil
		table.remove(self.Balls, Index)
	end
end

function PoolSimulation:GetBallObject(Object: BasePart)
	return self.__InstanceToData[Object]
end

function PoolSimulation:Simulate(Ball: BillardBall, DeltaTime: number)
	if not Ball.Simulate then
		return
	end

	local Velocity = Ball.Velocity
	Ball.Position += Vector2.new(Velocity.X * DeltaTime, Velocity.Y * DeltaTime)
	Ball.Instance.Position = self.RelativePosition + Vector3.new(Ball.Position.X, self.Radius, Ball.Position.Y)

	if Velocity.Magnitude > 0 then
		local Distance = Velocity.Magnitude * DeltaTime
		local RotationAngle = Distance / self.Radius
		local RollingAxis = Vector3.new(-Velocity.Y, 0, Velocity.X)
		if RollingAxis.Magnitude > 0 then
			RollingAxis = RollingAxis.Unit
		else
			RollingAxis = Vector3.zero
		end

		Ball.Instance.CFrame *= CFrame.fromAxisAngle(RollingAxis, RotationAngle)
	end

	if Velocity.Magnitude < 0.2 then
		Velocity = Vector2.zero
		Ball.Stationary = true
	else
		Ball.Stationary = false
	end

	Ball.Velocity = Velocity * self.Friction
end

function PoolSimulation:HandleBallCollision(Ball1: BillardBall, Ball2: BillardBall)
	local Direction: Vector2 = (Ball1.Position - Ball2.Position)
	local RelativeVelocity = Ball1.Velocity - Ball2.Velocity
	local Distance = Direction.Magnitude

	if Distance == 0 or Distance > self.Radius * 2 then
		return
	end

	if Ball1.Instance.Name == "0" or Ball2.Instance.Name == "0" then
		self.OnCueBallHit:Fire(Ball1, Ball2)
	end

	Direction = Direction / Distance

	if RelativeVelocity:Dot(Direction) >= 0 then
		return
	end

	local Overlap = (self.Radius * 2 - Distance) / 2
	Ball1.Position += Vector2.new(Direction.X * Overlap, Direction.Y * Overlap)
	Ball2.Position -= Vector2.new(Direction.X * Overlap, Direction.Y * Overlap)

	local V1, V2 = Ball1.Velocity:Dot(Direction), Ball2.Velocity:Dot(Direction)
	local NewV1 = (V1 + V2 - (V1 - V2) * self.Restitution) / 2
	local NewV2 = (V1 + V2 - (V2 - V1) * self.Restitution) / 2

	Ball1.Velocity +=  Direction * (NewV1 - V1)
	Ball2.Velocity += Direction * (NewV2 - V2)
	self.OnBallCollision:Fire("Ball", Ball1, Ball2)
end

function PoolSimulation:HandleWallCollision(Ball: BillardBall)
	local Velocity = Ball.Velocity
	local Position = Ball.Position

	local Bounds = {
		X = { Min = self.Radius, Max = self.Container.Size.X - self.Radius },
		Y = { Min = self.Radius, Max = self.Container.Size.Z - self.Radius },
	}

	for Pocket, PocketPosition in self.Pockets do
		if (PocketPosition - Position).Magnitude < self.PocketRadius and not Ball.Pocketed then
			self.OnBallPocket:Fire(Pocket, Ball)
			Ball.Pocketed = true
		end
	end

	for Axis, Limit in Bounds do
		local Pos = Position[Axis]
		local Vel = Velocity[Axis]

		if Pos < Limit.Min then
			Position = Position + Vector2.new(
				Axis == "X" and (Limit.Min - Pos) or 0,
				Axis == "Y" and (Limit.Min - Pos) or 0
			)
			Velocity = Velocity * Vector2.new(
				Axis == "X" and -1 or 1, 
				Axis == "Y" and -1 or 1
			) * self.Restitution
			self.OnBallCollision:Fire("Wall", Ball)
			Ball.Bounced = true
		elseif Pos > Limit.Max then
			Position = Position + Vector2.new(
				Axis == "X" and (Limit.Max - Pos) or 0,
				Axis == "Y" and (Limit.Max - Pos) or 0
			)
			Velocity = Velocity * Vector2.new(
				Axis == "X" and -1 or 1, 
				Axis == "Y" and -1 or 1
			) * self.Restitution
			self.OnBallCollision:Fire("Wall", Ball)
			Ball.Bounced = true
		end
	end

	Ball.Position = Position
	Ball.Velocity = Velocity
end

function PoolSimulation:Destroy()
	for i = #self.Balls, 1, -1  do
		self:DeleteBall(self.Balls[i].Instance)
	end

	self.OnBallPocket:Destroy()
	self.OnBallCollision:Destroy()
	self.OnCueBallHit:Destroy()
	self.__InstanceToData = nil
	setmetatable(self, nil)
end

function PoolSimulation:Update(DeltaTime: number)
	local FixedDeltaTime = 1 / self.Framerate
	self.AccumulatedTime += DeltaTime

	while self.AccumulatedTime >= FixedDeltaTime do
		local Balls = self.Balls
		local BallCount = #Balls
		for I = 1, BallCount do
			local Ball1 = Balls[I]
			self:Simulate(Ball1, FixedDeltaTime)

			if self.Simulation then
				for J = I + 1, BallCount do
					local Ball2 = Balls[J]
					self:HandleBallCollision(Ball1, Ball2)
				end

				self:HandleWallCollision(Ball1)
			end
		end

		self.AccumulatedTime -= FixedDeltaTime
	end
end

return PoolSimulation