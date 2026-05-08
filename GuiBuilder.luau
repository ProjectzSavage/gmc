-- v2026-04-17 camera + head text typing
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local blur = Lighting:FindFirstChild("GameBlur")
if not blur then
	blur = Instance.new("BlurEffect")
	blur.Name = "GameBlur"
	blur.Parent = Lighting
end
blur.Size = 0

local GameGui = player:WaitForChild("PlayerGui"):WaitForChild("GameGui")
local HUD = GameGui:FindFirstChild("HUD")
local HUDSeat1 = HUD and HUD:FindFirstChild("Seat1") or nil
local HUDSeat2 = HUD and HUD:FindFirstChild("Seat2") or nil
local HUDStatus = HUD and HUD:FindFirstChild("Status") or nil

local BlurOverlay = GameGui:WaitForChild("BlurOverlay")

local GuessingLbl = BlurOverlay:FindFirstChild("GuessingLbl")
if not GuessingLbl then
	GuessingLbl = Instance.new("TextLabel")
	GuessingLbl.Name = "GuessingLbl"
	GuessingLbl.AnchorPoint = Vector2.new(0.5, 0.5)
	GuessingLbl.Size = UDim2.new(0.7, 0, 0.12, 0)
	GuessingLbl.Position = UDim2.new(0.5, 0, 0.14, 0)
	GuessingLbl.BackgroundTransparency = 1
	GuessingLbl.Text = ""
	GuessingLbl.TextTransparency = 1
	GuessingLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
	GuessingLbl.TextStrokeTransparency = 0.15
	GuessingLbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	GuessingLbl.Font = Enum.Font.GothamBold
	GuessingLbl.TextScaled = true
	GuessingLbl.ZIndex = 20
	GuessingLbl.Parent = BlurOverlay
end

local function showGuessingOverlay(text)
	BlurOverlay.Visible = true
	GuessingLbl.Text = tostring(text or "")
	GuessingLbl.TextTransparency = 0
end

local function hideGuessingOverlay()
	GuessingLbl.Text = ""
	GuessingLbl.TextTransparency = 1
end

local LPickF = GameGui:WaitForChild("LPickF")
local LPickGrid = LPickF:WaitForChild("Grid")
local CPickF = GameGui:WaitForChild("CPickF")
local CPickScroll = CPickF:WaitForChild("Scroll")
local LGuessF = GameGui:WaitForChild("LGuessF")
local LGuessTitle = LGuessF:WaitForChild("Title")
local LGuessTimer = LGuessF:WaitForChild("Timer")
local LGuessFeedback = LGuessF:WaitForChild("Feedback")
local LGuessGrid = LGuessF:WaitForChild("Grid")
local CGuessF = GameGui:WaitForChild("CGuessF")
local CGuessTitle = CGuessF:WaitForChild("Title")
local CGuessTimer = CGuessF:WaitForChild("Timer")
local CGuessInfo = CGuessF:WaitForChild("Info")
local CGuessScroll = CGuessF:WaitForChild("Scroll")
local WaitF = GameGui:WaitForChild("WaitF")
local WaitLbl = WaitF:WaitForChild("Lbl")
local ResultF = GameGui:FindFirstChild("ResultF")
local ResultLbl = ResultF and ResultF:FindFirstChild("Lbl") or nil
local GameOverF = GameGui:WaitForChild("GameOverF")
local GameOverLbl = GameOverF:WaitForChild("Lbl")

local function normalizeLetterGrid(grid)
	grid.BackgroundTransparency = 1
	grid.ClipsDescendants = true
	local layout = grid:FindFirstChildOfClass("UIGridLayout")
	if not layout then
		layout = Instance.new("UIGridLayout")
		layout.Parent = grid
	end
	layout.CellSize = UDim2.fromOffset(52, 52)
	layout.CellPadding = UDim2.fromOffset(6, 6)
	layout.FillDirectionMaxCells = 8
	layout.SortOrder = Enum.SortOrder.LayoutOrder
end

normalizeLetterGrid(LPickGrid)
normalizeLetterGrid(LGuessGrid)

local Table = workspace:WaitForChild("Table")
local SeatA = Table:WaitForChild("SeatA")
local SeatB = Table:WaitForChild("SeatB")

local CAM = {
	frontDistance = 13,
	height = 5,
	lookAtHeight = 1.5,
	fov = 72,
	faceDistance = 5.5,
	faceHeight = 2.8,
	faceLookHeight = 2,
	faceFov = 50,
	flip = true,
}

local activeTween = nil

local function stopTween()
	if activeTween then
		activeTween:Cancel()
		activeTween = nil
	end
end

local function tweenCam(targetCF, fov, duration)
	stopTween()
	camera.CameraType = Enum.CameraType.Scriptable
	activeTween = TweenService:Create(camera, TweenInfo.new(duration, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
		CFrame = targetCF,
		FieldOfView = fov,
	})
	activeTween:Play()
end

local function getWideCFrame()
	local posA = SeatA.Position
	local posB = SeatB.Position
	local center = (posA + posB) / 2
	local row = (posB - posA).Unit
	local forward = row:Cross(Vector3.new(0, 1, 0)).Unit
	if CAM.flip then forward = -forward end
	local camPos = center + forward * CAM.frontDistance + Vector3.new(0, CAM.height, 0)
	local lookAt = center + Vector3.new(0, CAM.lookAtHeight, 0)
	return CFrame.new(camPos, lookAt)
end

local function getFaceCFrame(slot)
	local seat = slot == "A" and SeatA or SeatB
	local row = (SeatB.Position - SeatA.Position).Unit
	local forward = row:Cross(Vector3.new(0, 1, 0)).Unit
	if CAM.flip then forward = -forward end
	local camPos = seat.Position + forward * CAM.faceDistance + Vector3.new(0, CAM.faceHeight, 0)
	local lookAt = seat.Position + Vector3.new(0, CAM.faceLookHeight, 0)
	return CFrame.new(camPos, lookAt)
end

local function goWideShot(duration)
	duration = duration or 0.8
	hideGuessingOverlay()
	tweenCam(getWideCFrame(), CAM.fov, duration)
	TweenService:Create(blur, TweenInfo.new(duration), { Size = 0 }):Play()
	BlurOverlay.Visible = true
	local t = TweenService:Create(BlurOverlay, TweenInfo.new(duration), { BackgroundTransparency = 1 })
	t:Play()
	t.Completed:Connect(function()
		if BlurOverlay.BackgroundTransparency >= 0.99 then
			BlurOverlay.Visible = false
		end
	end)
end

local function zoomIntoMyFace(slot, duration, overlayText)
	duration = duration or 0.9
	tweenCam(getFaceCFrame(slot), CAM.faceFov, duration)
	TweenService:Create(blur, TweenInfo.new(duration), { Size = 22 }):Play()
	BlurOverlay.Visible = true
	TweenService:Create(BlurOverlay, TweenInfo.new(duration), { BackgroundTransparency = 0.45 }):Play()
	if overlayText and overlayText ~= "" then
		showGuessingOverlay(overlayText)
	else
		hideGuessingOverlay()
	end
end

local function zoomGuessTurn(slot, duration, overlayText)
	duration = duration or 0.9
	tweenCam(getFaceCFrame(slot), math.max(CAM.faceFov - 8, 40), duration)
	TweenService:Create(blur, TweenInfo.new(duration), { Size = 28 }):Play()
	BlurOverlay.Visible = true
	TweenService:Create(BlurOverlay, TweenInfo.new(duration), { BackgroundTransparency = 0.32 }):Play()
	if overlayText and overlayText ~= "" then
		showGuessingOverlay(overlayText)
	else
		hideGuessingOverlay()
	end
end

local function observePlayerFace(slot, duration, overlayText)
	duration = duration or 0.8
	tweenCam(getFaceCFrame(slot), math.max(CAM.faceFov + 6, 56), duration)
	TweenService:Create(blur, TweenInfo.new(duration), { Size = 0 }):Play()
	BlurOverlay.Visible = true
	local t = TweenService:Create(BlurOverlay, TweenInfo.new(duration), { BackgroundTransparency = 1 })
	t:Play()
	if overlayText and overlayText ~= "" then
		showGuessingOverlay(overlayText)
	else
		hideGuessingOverlay()
	end
	t.Completed:Connect(function()
		if BlurOverlay.BackgroundTransparency >= 0.99 and GuessingLbl.Text == "" then
			BlurOverlay.Visible = false
		end
	end)
end

local function releaseCamera(duration)
	duration = duration or 0.8
	stopTween()
	TweenService:Create(blur, TweenInfo.new(duration), { Size = 0 }):Play()
	BlurOverlay.Visible = true
	local t = TweenService:Create(BlurOverlay, TweenInfo.new(duration), { BackgroundTransparency = 1 })
	t:Play()
	t.Completed:Connect(function()
		BlurOverlay.Visible = false
	end)
	task.delay(duration, function()
		camera.CameraType = Enum.CameraType.Custom
	end)
end

local HEAD_BB_STYLE = {
	Size = UDim2.new(5.4, 0, 1.55, 0),
	StudsOffset = Vector3.new(0, 4.1, 0),
	BackgroundColor = Color3.fromRGB(12, 18, 34),
	BackgroundTransparency = 1,
	StrokeThickness = 0,
	TextFont = Enum.Font.FredokaOne,
	TextStrokeTransparency = 0.18,
	TypeCharDelay = 0.06,
	MinVisibleTime = 1.0,
	LifeTime = 3.8,
}

_G.ShowHeadBB = function(targetPlayer, text, strokeColor)
	local char = targetPlayer and targetPlayer.Character
	local head = char and char:FindFirstChild("Head")
	if not head then return end

	local old = head:FindFirstChild("GameBB")
	if old then old:Destroy() end

	local bb = Instance.new("BillboardGui")
	bb.Name = "GameBB"
	bb.Size = HEAD_BB_STYLE.Size
	bb.StudsOffset = HEAD_BB_STYLE.StudsOffset
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.Parent = head

	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = HEAD_BB_STYLE.BackgroundColor
	bg.BackgroundTransparency = HEAD_BB_STYLE.BackgroundTransparency
	bg.BorderSizePixel = 0
	bg.Parent = bb

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = bg

	local stroke = Instance.new("UIStroke")
	stroke.Color = strokeColor or Color3.fromRGB(255, 255, 255)
	stroke.Thickness = HEAD_BB_STYLE.StrokeThickness
	stroke.Parent = bg

	local lb = Instance.new("TextLabel")
	lb.Size = UDim2.new(1, -12, 1, -8)
	lb.Position = UDim2.new(0, 6, 0, 4)
	lb.BackgroundTransparency = 1
	local fullText = tostring(text or "")
	lb.Text = ""
	lb.TextColor3 = stroke.Color
	lb.TextScaled = true
	lb.Font = HEAD_BB_STYLE.TextFont
	lb.TextStrokeTransparency = HEAD_BB_STYLE.TextStrokeTransparency
	lb.TextStrokeColor3 = Color3.new(0, 0, 0)
	lb.Parent = bg

	task.spawn(function()
		for i = 1, #fullText do
			if not bb or not bb.Parent then return end
			lb.Text = string.sub(fullText, 1, i)
			task.wait(HEAD_BB_STYLE.TypeCharDelay)
		end
		if #fullText == 0 then
			lb.Text = fullText
		end
	end)

	local typedDuration = (#fullText * HEAD_BB_STYLE.TypeCharDelay) + HEAD_BB_STYLE.MinVisibleTime
	local life = math.max(HEAD_BB_STYLE.LifeTime, typedDuration)
	task.delay(life, function()
		if bb and bb.Parent then bb:Destroy() end
	end)
end

_G.GoWideShot = goWideShot
_G.ZoomIntoMyFace = zoomIntoMyFace
_G.ZoomGuessTurn = zoomGuessTurn
_G.ObservePlayerFace = observePlayerFace
_G.ReleaseCamera = releaseCamera
_G.BlurEffect = blur

_G.Frames = {
	HUDSeat1 = HUDSeat1,
	HUDSeat2 = HUDSeat2,
	HUDStatus = HUDStatus,
	BlurOverlay = BlurOverlay,
	GuessingLbl = GuessingLbl,
	LPickF = LPickF,
	LPickGrid = LPickGrid,
	CPickF = CPickF,
	CPickScroll = CPickScroll,
	LGuessF = LGuessF,
	LGuessTitle = LGuessTitle,
	LGuessTimer = LGuessTimer,
	LGuessFeedback = LGuessFeedback,
	LGuessGrid = LGuessGrid,
	CGuessF = CGuessF,
	CGuessTitle = CGuessTitle,
	CGuessTimer = CGuessTimer,
	CGuessInfo = CGuessInfo,
	CGuessScroll = CGuessScroll,
	WaitF = WaitF,
	WaitLbl = WaitLbl,
	ResultF = ResultF,
	ResultLbl = ResultLbl,
	GameOverF = GameOverF,
	GameOverLbl = GameOverLbl,
}

print("[GuiBuilder] Ready")