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

local function getChairModel(name)
	return ShopChairs:FindFirstChild(name) or EquippableChairs:FindFirstChild(name)
end

local function clearViewport(vp)
	for _, c in ipairs(vp:GetChildren()) do
		c:Destroy()
	end
end

local function setupViewport(vp, chairName)
	clearViewport(vp)

	local model = getChairModel(chairName)
	if not model then return end

	local world = Instance.new("WorldModel")
	world.Parent = vp

	local clone = model:Clone()
	clone.Parent = world

	for _, d in ipairs(clone:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
		end
	end

	local cam = Instance.new("Camera")
	cam.Parent = vp
	vp.CurrentCamera = cam

	local cf, size = clone:GetBoundingBox()
	local center = cf.Position
	local radius = math.max(size.X, size.Y, size.Z)
	local dist = math.max(radius * 1.45, 3)

	cam.CFrame = CFrame.new(center + Vector3.new(dist, dist * 0.55, dist), center)
end

local function updateGridLayout()
	local width = Grid.AbsoluteSize.X
	local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

	local padding = 10
	local columns

	-- Force 2 columns on mobile so you don't get 1-per-row
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
	local cellW = layout.CellSize.X.Offset
	local cellH = layout.CellSize.Y.Offset

	local vp = row:FindFirstChild("ViewportFrame")
	if not vp then
		vp = Instance.new("ViewportFrame")
		vp.Name = "ViewportFrame"
		vp.Parent = row
	end

	vp.BackgroundTransparency = 1
	vp.BorderSizePixel = 0
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

local function rebuildUI()
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

		local vp = row:FindFirstChild("ViewportFrame")
		if vp then
			setupViewport(vp, chairName)
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

	if Grid:IsA("ScrollingFrame") then
		task.defer(function()
			Grid.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + 12)
		end)
	end
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

task.spawn(function()
	local ok, data = pcall(function()
		return RequestSync:InvokeServer()
	end)
	if ok then
		mergeData(data)
		rebuildUI()
	end
end)

ChairSync.OnClientEvent:Connect(function(data)
	mergeData(data)
	rebuildUI()
end)

Grid:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
	updateGridLayout()
	for _, row in ipairs(Grid:GetChildren()) do
		if row:IsA("Frame") and row.Name ~= "Template" then
			styleRow(row)
		end
	end
	if Grid:IsA("ScrollingFrame") then
		Grid.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + 12)
	end
end)

layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	if Grid:IsA("ScrollingFrame") then
		Grid.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + 12)
	end
end)
