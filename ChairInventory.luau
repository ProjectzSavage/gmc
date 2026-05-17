-- ChairInventory v3 (stable viewport previews)
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local Events = RS:WaitForChild("Events")

local ChairSync = Events:WaitForChild("ChairSync")
local RequestSync = Events:WaitForChild("RequestSync")
local EquipChair = Events:WaitForChild("EquipChair")

local PlayerGui = player:WaitForChild("PlayerGui")
local GameGui = PlayerGui:WaitForChild("GameGui")
local Panel = GameGui:WaitForChild("ChairInvPanel")
local Grid = Panel:WaitForChild("Grid")
local Template = Grid:WaitForChild("Template")

Template.Visible = false

local ChairsRoot = RS:WaitForChild("Chairs")
local ShopChairs = ChairsRoot:WaitForChild("ShopChairs")
local EquippableChairs = ChairsRoot:WaitForChild("EquippableChairs")

local state = {
	owned = {},
	equipped = "Default",
}

local layout = Grid:FindFirstChildOfClass("UIGridLayout")
if not layout then
	layout = Instance.new("UIGridLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = Grid
end

local rebuildToken = 0
local rebuildQueued = false
local panelWasVisible = Panel.Visible
local pendingRenderRefresh = false
local viewportRefreshQueued = false
local lastViewportRefresh = 0

local function getChairModel(name)
	return ShopChairs:FindFirstChild(name) or EquippableChairs:FindFirstChild(name)
end

local function sanitizeOwned(list)
	if type(list) ~= "table" then return {} end
	local out = {}
	local seen = {}
	for _, v in ipairs(list) do
		if type(v) == "string" and v ~= "" and not seen[v] then
			seen[v] = true
			table.insert(out, v)
			if #out >= 120 then break end
		end
	end
	return out
end

local function mergeData(incoming)
	if type(incoming) ~= "table" then return end
	if type(incoming.owned) == "table" then
		state.owned = sanitizeOwned(incoming.owned)
	end
	if type(incoming.equipped) == "string" and incoming.equipped ~= "" then
		state.equipped = incoming.equipped
	end
end

local function clearViewport(vp)
	for _, c in ipairs(vp:GetChildren()) do
		c:Destroy()
	end
end

local function makePreviewClone(srcModel)
	local clone = srcModel:Clone()

	for _, d in ipairs(clone:GetDescendants()) do
		if d:IsA("LuaSourceContainer")
			or d:IsA("ProximityPrompt")
			or d:IsA("Constraint")
			or d:IsA("JointInstance")
			or d:IsA("ParticleEmitter")
			or d:IsA("Trail")
			or d:IsA("Beam")
			or d:IsA("Highlight") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.AssemblyLinearVelocity = Vector3.zero
			d.AssemblyAngularVelocity = Vector3.zero
		end
	end

	return clone
end

local function setupViewport(vp, chairName)
	clearViewport(vp)

	local model = getChairModel(chairName)
	if not model then return end

	vp.BackgroundTransparency = 1
	vp.BorderSizePixel = 0
	vp.LightDirection = Vector3.new(-1, -1, -1)
	vp.LightColor = Color3.fromRGB(255, 255, 255)
	vp.Ambient = Color3.fromRGB(190, 190, 190)

	-- Camera first, before anything is parented
	local cam = Instance.new("Camera")
	cam.FieldOfView = 35
	cam.Parent = vp
	vp.CurrentCamera = cam

	local world = Instance.new("WorldModel")
	world.Parent = vp

	local clone = makePreviewClone(model)
	clone.Parent = world
	clone:PivotTo(CFrame.new(0, 0, 0))

	local cf, size = clone:GetBoundingBox()
	local center = cf.Position
	local radius = math.clamp(math.max(size.X, size.Y, size.Z), 1.2, 10)
	local dist = radius * 2.0 + 1.5
	local camPos = center + Vector3.new(dist, dist * 0.62, dist)
	local lookAt = center + Vector3.new(0, math.clamp(size.Y * 0.12, 0.1, 1.2), 0)
	cam.CFrame = CFrame.lookAt(camPos, lookAt)

	return cam, camPos, lookAt
end

local function updateGridLayout()
	local width = Grid.AbsoluteSize.X
	local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

	local padding = 10
	local columns

	if isMobile then
		columns = 2
	else
		columns = (width >= 1100) and 4 or 3
	end

	local cellWidth = math.floor((width - (padding * (columns - 1))) / columns)
	cellWidth = math.max(cellWidth, 140)

	local cellHeight = math.floor(cellWidth * 1.28)
	cellHeight = math.max(cellHeight, 190)

	layout.FillDirectionMaxCells = columns
	layout.CellPadding = UDim2.fromOffset(padding, padding)
	layout.CellSize = UDim2.fromOffset(cellWidth, cellHeight)

	if Grid:IsA("ScrollingFrame") then
		Grid.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + 12)
	end
end

local function styleRow(row)
	local cellH = layout.CellSize.Y.Offset

	local vp = row:FindFirstChild("ViewportFrame")
	if not vp then
		vp = Instance.new("ViewportFrame")
		vp.Name = "ViewportFrame"
		vp.Parent = row
	end

	vp.BackgroundTransparency = 1
	vp.BorderSizePixel = 0
	vp.ClipsDescendants = true
	vp.Size = UDim2.new(1, -12, 0, math.floor(cellH * 0.62))
	vp.Position = UDim2.fromOffset(6, 6)

	local nameLbl = row:FindFirstChild("NameLbl")
	if nameLbl and nameLbl:IsA("TextLabel") then
		nameLbl.Size = UDim2.new(1, -12, 0, 26)
		nameLbl.Position = UDim2.new(0, 6, 0, math.floor(cellH * 0.62) + 10)
		nameLbl.TextScaled = true
	end

	local equipBtn = row:FindFirstChild("EquipBtn")
	if equipBtn and equipBtn:IsA("TextButton") then
		equipBtn.Size = UDim2.new(1, -12, 0, 30)
		equipBtn.Position = UDim2.new(0, 6, 1, -36)
		equipBtn.TextScaled = true
	end
end

local function renderRows(token)
	for _, row in ipairs(Grid:GetChildren()) do
		if row:IsA("Frame") and row.Name ~= "Template" then
			local vp = row:FindFirstChild("ViewportFrame")
			if vp then
				setupViewport(vp, row.Name)
			end
		end
	end

	-- Delayed pass fixes occasional first-frame bad framing.

end
local function queueViewportRefresh()
	if viewportRefreshQueued then return end
	viewportRefreshQueued = true

	task.delay(0.08, function()
		viewportRefreshQueued = false

		-- Skip if panel is hidden.
		if not Panel.Visible then return end

		-- Avoid hammering during tween.
		local now = os.clock()
		if now - lastViewportRefresh < 0.06 then return end
		lastViewportRefresh = now

		for _, row in ipairs(Grid:GetChildren()) do
			if row:IsA("Frame") and row.Name ~= "Template" then
				local vp = row:FindFirstChild("ViewportFrame")
				if vp then
					setupViewport(vp, row.Name)
				end
			end
		end
	end)
end
local function rebuildUI()
	rebuildToken += 1
	local token = rebuildToken

	for _, child in ipairs(Grid:GetChildren()) do
		if child:IsA("Frame") and child.Name ~= "Template" then
			child:Destroy()
		end
	end

	updateGridLayout()

	for _, chairName in ipairs(state.owned) do
		local row = Template:Clone()
		row.Name = chairName
		row.Visible = true
		row.Parent = Grid

		styleRow(row)

		local nameLbl = row:FindFirstChild("NameLbl")
		if nameLbl and nameLbl:IsA("TextLabel") then
			nameLbl.Text = chairName
		end

		local equipBtn = row:FindFirstChild("EquipBtn")
		if equipBtn and equipBtn:IsA("TextButton") then
			if state.equipped == chairName then
				equipBtn.Text = "Equipped"
				equipBtn.BackgroundColor3 = Color3.fromRGB(85, 255, 127)
			else
				equipBtn.Text = "Equip"
				equipBtn.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
			end

			equipBtn.Activated:Connect(function()
				equipBtn.Text = "Equipping..."
				EquipChair:FireServer(chairName)
			end)
		end
	end

	renderRows(token)

	if Grid:IsA("ScrollingFrame") then
		task.defer(function()
			if token ~= rebuildToken then return end
			Grid.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + 12)
		end)
	end
end

local function queueRebuild()
	if rebuildQueued then return end
	rebuildQueued = true
	task.defer(function()
		rebuildQueued = false
		rebuildUI()
	end)
end

local function refreshViewports()
	if not Panel.Visible then return end
	for _, row in ipairs(Grid:GetChildren()) do
		if row:IsA("Frame") and row.Name ~= "Template" then
			local vp = row:FindFirstChild("ViewportFrame")
			if vp then setupViewport(vp, row.Name) end
		end
	end
end

local function onPanelOpen()
	-- Always request a fresh sync on open so equipped state is up to date
	task.spawn(function()
		local ok, data = pcall(function() return RequestSync:InvokeServer() end)
		if ok and data then
			mergeData(data)

			-- If player owns nothing, give them Default so the grid isn't empty
			if #state.owned == 0 then
				state.owned = { "Default" }
				state.equipped = "Default"
			end

			-- If equipped chair isn't in owned list somehow, reset to Default
			local equippedOwned = false
			for _, name in ipairs(state.owned) do
				if name == state.equipped then equippedOwned = true; break end
			end
			if not equippedOwned then
				state.equipped = "Default"
				-- Tell server too
				pcall(function() EquipChair:FireServer("Default") end)
			end

			queueRebuild()
		end
	end)

	-- Viewport refresh after open animation settles (0.45s = elastic anim duration)
	task.delay(0.45, function()
		if Panel.Visible then refreshViewports() end
	end)
end

-- Initial data fetch on script start
task.spawn(function()
	local ok, data = pcall(function() return RequestSync:InvokeServer() end)
	if ok and data then
		mergeData(data)
		if #state.owned == 0 then
			state.owned = { "Default" }
			state.equipped = "Default"
		end
		queueRebuild()
	end
end)

ChairSync.OnClientEvent:Connect(function(data)
	mergeData(data)
	if not Panel.Visible then
		pendingRenderRefresh = true
		return
	end
	queueRebuild()
end)

Grid:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
	updateGridLayout()
	for _, row in ipairs(Grid:GetChildren()) do
		if row:IsA("Frame") and row.Name ~= "Template" then styleRow(row) end
	end
	if Grid:IsA("ScrollingFrame") then
		Grid.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + 12)
	end
	if Panel.Visible then
		task.defer(function() task.defer(refreshViewports) end)
	end
end)

Panel:GetPropertyChangedSignal("Visible"):Connect(function()
	if not Panel.Visible then
		panelWasVisible = false
		return
	end
	panelWasVisible = true

	if pendingRenderRefresh then
		pendingRenderRefresh = false
		onPanelOpen()
		return
	end

	onPanelOpen()
end)

layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	if Grid:IsA("ScrollingFrame") then
		Grid.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + 12)
	end
end)

-- Register with animator — pass onPanelOpen as the onOpen callback
local openInvBtn = GameGui:FindFirstChild("OpenChairInvBtn")
	or GameGui:FindFirstChild("OpenInventoryBtn")
	or GameGui:FindFirstChild("OpenInvBtn")
local closeInvBtn = Panel:FindFirstChild("CloseBtn")

local t = 0
while not _G.UIWindowAnimator and t < 5 do task.wait(0.1); t += 0.1 end

if _G.UIWindowAnimator then
	_G.UIWindowAnimator.register("inventory", Panel, openInvBtn, closeInvBtn, onPanelOpen)
else
	if openInvBtn then
		openInvBtn.MouseButton1Click:Connect(function()
			Panel.Visible = not Panel.Visible
			if Panel.Visible then onPanelOpen() end
		end)
	end
	if closeInvBtn then
		closeInvBtn.MouseButton1Click:Connect(function() Panel.Visible = false end)
	end
end
