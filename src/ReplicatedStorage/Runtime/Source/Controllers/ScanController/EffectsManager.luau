local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local UIColors = require(ReplicatedStorage.Modules.UI.UIColors)
local UIFactory = require(ReplicatedStorage.Modules.UI.UIFactory)
local Config = require(script.Parent.Config)

local EffectsManager = {}
EffectsManager.__index = EffectsManager

function EffectsManager.new(scanController)
	local self = setmetatable({}, EffectsManager)
	self.scanController = scanController
	return self
end

function EffectsManager:PlayNodeStateTransition(nodeObject, targetStyle)
	if not nodeObject or nodeObject.Type ~= "Dot" or not nodeObject.Frame then
		return
	end

	local frame = nodeObject.Frame
	if not frame.Parent then
		return
	end

	local style = Config.NODE_STYLES[targetStyle] or Config.NODE_STYLES.Default
	frame.AutoButtonColor = false
	frame.BackgroundColor3 = style.Background or frame.BackgroundColor3
	frame.BackgroundTransparency = style.BackgroundTransparency or 0.1

	if nodeObject.Stroke then
		nodeObject.Stroke.Color = style.Stroke or nodeObject.Stroke.Color
		nodeObject.Stroke.Thickness = style.StrokeThickness or nodeObject.Stroke.Thickness
		nodeObject.Stroke.Transparency = 0
	end

	nodeObject.CurrentStyle = targetStyle or "Default"
end

function EffectsManager:PlayDiscoveryEffect(ScanViewFrame)
	if not ScanViewFrame then
		return
	end

	local effectLayer = UIFactory.createFrame(ScanViewFrame, {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		ZIndex = 20
	})

	local overlay = UIFactory.createFrame(effectLayer, {
		BackgroundColor3 = UIColors.Success,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1)
	})

	local overlayIn = TweenService:Create(
		overlay,
		Config.DISCOVERY_OVERLAY_IN_TWEEN,
		{BackgroundTransparency = Config.DISCOVERY_OVERLAY_TRANSPARENCY}
	)

	local overlayOut = TweenService:Create(
		overlay,
		Config.DISCOVERY_OVERLAY_OUT_TWEEN,
		{BackgroundTransparency = 1}
	)

	local burst = UIFactory.createFrame(effectLayer, {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(0.2, 0.2),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		ZIndex = effectLayer.ZIndex + 1
	}, {
		Corner = {CornerRadius = UDim.new(1, 0)},
		Stroke = {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Thickness = Config.DISCOVERY_BURST_STROKE_THICKNESS,
			Color = UIColors.AccentAlt,
			Transparency = Config.DISCOVERY_BURST_STROKE_TRANSPARENCY
		}
	})

	local burstStroke = burst:FindFirstChildOfClass("UIStroke")

	local burstExpand = TweenService:Create(
		burst,
		Config.DISCOVERY_BURST_EXPAND_TWEEN,
		{Size = UDim2.fromScale(1.1, 1.1)}
	)

	local burstFade = TweenService:Create(
		burstStroke,
		Config.DISCOVERY_BURST_FADE_TWEEN,
		{Thickness = 0, Transparency = 1}
	)

	local cleaned = false
	local function cleanup()
		if cleaned then return end
		cleaned = true
		if overlayIn then overlayIn:Cancel() end
		if overlayOut then overlayOut:Cancel() end
		if burstExpand then burstExpand:Cancel() end
		if burstFade then burstFade:Cancel() end
		if effectLayer and effectLayer.Parent then
			effectLayer:Destroy()
		end
	end

	overlayIn.Completed:Connect(function()
		overlayOut:Play()
	end)

	burstExpand.Completed:Connect(cleanup)

	overlayIn:Play()
	burstExpand:Play()
	burstFade:Play()

	task.delay(Config.DISCOVERY_EFFECT_CLEANUP_DELAY, cleanup)
end

local CLICK_RING_TWEEN = TweenInfo.new(0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
local CLICK_FLASH_TWEEN = TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
local CLICK_PRESS_TWEEN = TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local CLICK_RELEASE_TWEEN = TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
local CLICK_GLOW_TWEEN = TweenInfo.new(0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)

function EffectsManager:PlaySkeletonNodeClickEffect(nodeObject)
	if not nodeObject or nodeObject.Type ~= "Dot" then
		return
	end

	local frame = nodeObject.Frame
	if not frame or not frame.Parent then
		return
	end

	local effectScale = Config.SKELETON_EFFECT_SCALE or 1

	local sounds = self.scanController and self.scanController.Sounds
	if sounds and sounds.Click then
		local clickSound = sounds.Click:Clone()
		local gui = self.scanController.ScannerGui
		if gui then
			clickSound.Parent = gui
			clickSound:Play()
			game:GetService("Debris"):AddItem(clickSound, clickSound.TimeLength)
		else
			clickSound:Destroy()
		end
	end

	local existing = frame:FindFirstChild("SkeletonNodeClickEffect")
	if existing then
		existing:Destroy()
	end

	local effectLayer = UIFactory.createFrame(frame, {
		Name = "SkeletonNodeClickEffect",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = frame.ZIndex + 5
	})

	local originalSize = frame.Size
	local pressTween
	local releaseTween
	local cleaned = false
	local function cleanup()
		if cleaned then
			return
		end
		cleaned = true
		if pressTween then
			pressTween:Cancel()
		end
		if releaseTween then
			releaseTween:Cancel()
		end
		if frame and frame.Parent then
			frame.Size = originalSize
		end
		if effectLayer and effectLayer.Parent then
			effectLayer:Destroy()
		end
	end

	local skeletalGuide = self.scanController and self.scanController.SkeletalGuide
	if skeletalGuide then
		skeletalGuide:Add(effectLayer)
		skeletalGuide:Add(cleanup)
	end

	local sizeOffset = (Config.SKELETON_NODE_CLICK_SIZE_OFFSET or 0) * effectScale
	local sizePulseTarget = originalSize + UDim2.fromOffset(sizeOffset, sizeOffset)

	pressTween = TweenService:Create(frame, CLICK_PRESS_TWEEN, {Size = sizePulseTarget})
	releaseTween = TweenService:Create(frame, CLICK_RELEASE_TWEEN, {Size = originalSize})

	pressTween.Completed:Connect(function(state)
		if state == Enum.PlaybackState.Completed and frame and frame.Parent then
			releaseTween:Play()
		end
	end)

	releaseTween.Completed:Connect(function(state)
		if state == Enum.PlaybackState.Completed and frame and frame.Parent then
			frame.Size = originalSize
		end
	end)

	pressTween:Play()

	local baseZ = effectLayer.ZIndex

	local function createRing(sizeScale, thickness, color, rotation, zOffset)
		local ring = UIFactory.createFrame(effectLayer, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(sizeScale, sizeScale),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Rotation = rotation or 0,
			ZIndex = baseZ + (zOffset or 0)
		}, {
			Corner = {CornerRadius = UDim.new(1, 0)},
			Stroke = {
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Thickness = thickness,
				Color = color,
				Transparency = 0
			}
		})
		local stroke = ring:FindFirstChildOfClass("UIStroke")
		return ring, stroke
	end

	local primaryRing, primaryStroke = createRing(1.35 * effectScale, 5 * effectScale, UIColors.White, 8, 1)
	if primaryRing and primaryStroke then
		local ringTween = TweenService:Create(primaryRing, CLICK_RING_TWEEN, {
			Size = UDim2.fromScale(2.6 * effectScale, 2.6 * effectScale),
			Rotation = primaryRing.Rotation + 24
		})
		local ringFade = TweenService:Create(primaryStroke, CLICK_RING_TWEEN, {
			Thickness = 0,
			Transparency = 1
		})
		ringTween.Completed:Connect(function()
			if primaryRing and primaryRing.Parent then
				primaryRing:Destroy()
			end
		end)
		ringTween:Play()
		ringFade:Play()
	end

	task.delay(0.075, function()
		if cleaned or not effectLayer or not effectLayer.Parent then
			return
		end

		local echoRing, echoStroke = createRing(1.05 * effectScale, 4 * effectScale, UIColors.AccentAlt, -10, 1)
		if not echoRing or not echoStroke then
			return
		end

		echoRing.ZIndex = baseZ + 2

		local echoTween = TweenService:Create(echoRing, TweenInfo.new(0.42, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
			Size = UDim2.fromScale(3.2 * effectScale, 3.2 * effectScale),
			Rotation = echoRing.Rotation + 40
		})
		local echoFade = TweenService:Create(echoStroke, TweenInfo.new(0.42, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
			Thickness = 0,
			Transparency = 1,
			Color = UIColors.White
		})

		echoTween.Completed:Connect(function()
			if echoRing and echoRing.Parent then
				echoRing:Destroy()
			end
		end)

		echoTween:Play()
		echoFade:Play()
	end)

	local coreFlash = UIFactory.createFrame(effectLayer, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.55 * effectScale, 0.55 * effectScale),
		BackgroundColor3 = UIColors.ScanNodeSelected,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		ZIndex = baseZ + 3
	}, {
		Corner = {CornerRadius = UDim.new(1, 0)}
	})

	local coreFlashTween = TweenService:Create(coreFlash, CLICK_FLASH_TWEEN, {
		Size = UDim2.fromScale(1.5 * effectScale, 1.5 * effectScale),
		BackgroundTransparency = 1
	})

	coreFlashTween.Completed:Connect(function()
		if coreFlash and coreFlash.Parent then
			coreFlash:Destroy()
		end
	end)

	coreFlashTween:Play()

	local aura = UIFactory.createFrame(effectLayer, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1.7 * effectScale, 1.7 * effectScale),
		BackgroundColor3 = UIColors.ScanNodeSelectedStroke,
		BackgroundTransparency = 0.7,
		BorderSizePixel = 0,
		ZIndex = baseZ + 2
	}, {
		Corner = {CornerRadius = UDim.new(1, 0)}
	})

	local auraTween = TweenService:Create(aura, CLICK_GLOW_TWEEN, {
		Size = UDim2.fromScale(2.5 * effectScale, 2.5 * effectScale),
		BackgroundTransparency = 1
	})

	auraTween.Completed:Connect(function()
		if aura and aura.Parent then
			aura:Destroy()
		end
	end)

	auraTween:Play()

	local sparkCount = Config.SKELETON_NODE_SPARK_COUNT or 6
	local sparkDistance = (Config.SKELETON_NODE_SPARK_DISTANCE or 0.45) * effectScale

	for index = 0, sparkCount - 1 do
		local angle = (index / sparkCount) * math.pi * 2
		local spark = UIFactory.createFrame(effectLayer, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.12 * effectScale, 0.025 * effectScale),
			BackgroundColor3 = UIColors.ScanNodeSelectedStroke,
			BackgroundTransparency = 0,
			BorderSizePixel = 0,
			Rotation = math.deg(angle),
			ZIndex = baseZ + 4
		})

		local target = UDim2.fromScale(
			0.5 + math.cos(angle) * sparkDistance * 1.2,
			0.5 + math.sin(angle) * sparkDistance * 1.2
		)

		local sparkTween = TweenService:Create(spark, CLICK_RING_TWEEN, {
			Position = target,
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(0.25 * effectScale, 0.008 * effectScale)
		})

		sparkTween.Completed:Connect(function()
			if spark and spark.Parent then
				spark:Destroy()
			end
		end)

		sparkTween:Play()
	end

	local glow = frame:FindFirstChild("Glow")
	if glow then
		local originalGlowSize = glow.Size
		local expandOffset = (Config.SKELETON_NODE_GLOW_EXPAND or 0) * effectScale
		local pulseSize = originalGlowSize + UDim2.fromScale(expandOffset, expandOffset)

		local glowPulse = TweenService:Create(glow, CLICK_GLOW_TWEEN, {
			Size = pulseSize,
			BackgroundTransparency = math.max(glow.BackgroundTransparency - 0.4, 0)
		})

		local glowReturn = TweenService:Create(glow, CLICK_GLOW_TWEEN, {
			Size = originalGlowSize,
			BackgroundTransparency = glow.BackgroundTransparency
		})

		glowPulse.Completed:Connect(function(state)
			if state == Enum.PlaybackState.Completed and glow and glow.Parent then
				glowReturn:Play()
			end
		end)

		glowReturn.Completed:Connect(function()
			if glow and glow.Parent then
				glow.Size = originalGlowSize
			end
		end)

		glowPulse:Play()
	end

	task.delay(0.6, cleanup)
end

function EffectsManager:PlayConnectionEffect(startNode, endNode)
	if not startNode or not endNode then
		return
	end

	local effectScale = Config.SKELETON_EFFECT_SCALE or 1
	local ringEndSize = (Config.SKELETON_CONNECTION_RING_SIZE or 2.6) * effectScale

	local startFrame = startNode.Frame
	local endFrame = endNode.Frame

	if not startFrame or not endFrame or not startFrame.Parent or not endFrame.Parent then
		return
	end

	local sounds = self.scanController and self.scanController.Sounds
	if sounds and sounds.Click then
		local connectSound = sounds.Click:Clone()
		local gui = self.scanController.ScannerGui
		if gui then
			connectSound.Parent = gui
			connectSound:Play()
			game:GetService("Debris"):AddItem(connectSound, connectSound.TimeLength)
		else
			connectSound:Destroy()
		end
	end

	local function spawnConnectionBurst(targetFrame, delay)
		task.delay(delay or 0, function()
			if not targetFrame or not targetFrame.Parent then
				return
			end

			local baseZ = targetFrame.ZIndex

			local ring1 = UIFactory.createFrame(targetFrame, {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(1.0 * effectScale, 1.0 * effectScale),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ZIndex = baseZ + 10
			}, {
				Corner = {CornerRadius = UDim.new(1, 0)},
				Stroke = {
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					Thickness = 6 * effectScale,
					Color = UIColors.ScanNodeSelectedStroke,
					Transparency = 0
				}
			})

			local ring1Stroke = ring1:FindFirstChildOfClass("UIStroke")
			local ring1Expand = TweenService:Create(ring1, TweenInfo.new(0.75, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
				Size = UDim2.fromScale(ringEndSize, ringEndSize)
			})
			local ring1Fade = TweenService:Create(ring1Stroke, TweenInfo.new(0.75, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
				Thickness = 0,
				Transparency = 1
			})

			ring1Expand.Completed:Connect(function()
				if ring1 and ring1.Parent then
					ring1:Destroy()
				end
			end)

			ring1Expand:Play()
			ring1Fade:Play()

			-- Secondary echo ring
			task.delay(0.1, function()
				if not targetFrame or not targetFrame.Parent then return end

				local ring2 = UIFactory.createFrame(targetFrame, {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromScale(0.8 * effectScale, 0.8 * effectScale),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					ZIndex = baseZ + 9
				}, {
					Corner = {CornerRadius = UDim.new(1, 0)},
					Stroke = {
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
						Thickness = 3 * effectScale,
						Color = UIColors.ScanNodeSelected,
						Transparency = 0.3
					}
				})

				local ring2Stroke = ring2:FindFirstChildOfClass("UIStroke")
				local ring2Expand = TweenService:Create(ring2, TweenInfo.new(0.65, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
					Size = UDim2.fromScale(math.max(1.4, ringEndSize - 0.5), math.max(1.4, ringEndSize - 0.5))
				})
				local ring2Fade = TweenService:Create(ring2Stroke, TweenInfo.new(0.65, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
					Thickness = 0,
					Transparency = 1
				})

				ring2Expand.Completed:Connect(function()
					if ring2 and ring2.Parent then
						ring2:Destroy()
					end
				end)

				ring2Expand:Play()
				ring2Fade:Play()
			end)

			-- Glow pulse
			local glow = UIFactory.createFrame(targetFrame, {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(1.5 * effectScale, 1.5 * effectScale),
				BackgroundColor3 = UIColors.ScanNodeSelectedStroke,
				BackgroundTransparency = 0.6,
				BorderSizePixel = 0,
				ZIndex = baseZ + 8
			}, {
				Corner = {CornerRadius = UDim.new(1, 0)}
			})

			local glowTween = TweenService:Create(glow, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
				Size = UDim2.fromScale((2.5 * effectScale), (2.5 * effectScale)),
				BackgroundTransparency = 1
			})

			glowTween.Completed:Connect(function()
				if glow and glow.Parent then
					glow:Destroy()
				end
			end)

			glowTween:Play()

			-- Sparks bursting outward
			local sparkCount = Config.SKELETON_CONNECTION_SPARK_COUNT or 8
			local sparkDistance = (Config.SKELETON_CONNECTION_SPARK_DISTANCE or 0.55) * effectScale

			for i = 0, sparkCount - 1 do
				local angle = (i / sparkCount) * math.pi * 2

				local spark = UIFactory.createFrame(targetFrame, {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromScale(0.18 * effectScale, 0.03 * effectScale),
					BackgroundColor3 = UIColors.ScanNodeSelectedStroke,
					BackgroundTransparency = 0,
					BorderSizePixel = 0,
					Rotation = math.deg(angle),
					ZIndex = baseZ + 11
				})

				local targetX = 0.5 + math.cos(angle) * sparkDistance * 1.3
				local targetY = 0.5 + math.sin(angle) * sparkDistance * 1.3

				local sparkTween = TweenService:Create(spark, TweenInfo.new(0.65, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
					Position = UDim2.fromScale(targetX, targetY),
					Size = UDim2.fromScale(0.35 * effectScale, 0.015 * effectScale),
					BackgroundTransparency = 1
				})

				sparkTween.Completed:Connect(function()
					if spark and spark.Parent then
						spark:Destroy()
					end
				end)

				sparkTween:Play()
			end

			local trove = self.scanController and self.scanController.SkeletalGuide
			if trove then
				trove:Add(ring1)
				trove:Add(glow)
			end
		end)
	end

	spawnConnectionBurst(startFrame, 0)
	spawnConnectionBurst(endFrame, 0.15)
end

function EffectsManager:PlayButtonScaleAnimation(button)
	if not button then
		return
	end

	local scale = button:FindFirstChild("UIScale")
	if not scale then
		scale = Instance.new("UIScale")
		scale.Parent = button
	end

	local scaleAnimation = TweenService:Create(
		scale,
		TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{Scale = 0.95}
	)
	scaleAnimation:Play()

	scaleAnimation.Completed:Connect(function()
		local resetAnimation = TweenService:Create(
			scale,
			TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{Scale = 1}
		)
		resetAnimation:Play()
	end)
end

return EffectsManager
