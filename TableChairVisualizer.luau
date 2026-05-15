local ReplicatedStorage = game:GetService("ReplicatedStorage")

local chairsRoot = ReplicatedStorage:WaitForChild("Chairs")
local equippable = chairsRoot:WaitForChild("EquippableChairs")
local tablesFolder = workspace:WaitForChild("Tables")

local FLOOR_OFFSET = -1.65

local function setBasicChairVisibility(tableModel, slot, visible)
	local basic = tableModel:FindFirstChild("BasicChair" .. slot)
	if not basic then return end
	for _, part in ipairs(basic:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Transparency = visible and 0 or 1
		end
	end
end
local function applyRainbowEffect(model)
	task.spawn(function()
		while model and model.Parent do
			local h = (tick() * 0.2) % 1
			local c = Color3.fromHSV(h, 1, 1)
			for _, d in ipairs(model:GetDescendants()) do
				if d:IsA("BasePart") then
					d.Color = c
				end
			end
			task.wait(0.06)
		end
	end)
end
local function spawnChair(tableModel, slot, chairName)
	local playerChairs = tableModel:FindFirstChild("PlayerChairs")
	if not playerChairs then
		playerChairs = Instance.new("Folder")
		playerChairs.Name = "PlayerChairs"
		playerChairs.Parent = tableModel
	end

	local existing = playerChairs:FindFirstChild(slot .. "_Chair")
	if existing then existing:Destroy() end

	local seat = tableModel:FindFirstChild("Seat" .. slot)
	if not seat then return end

	if not chairName or chairName == "Default" then
		setBasicChairVisibility(tableModel, slot, true)
		return
	end

	local source = equippable:FindFirstChild(chairName)
	if not source then
		setBasicChairVisibility(tableModel, slot, true)
		return
	end

	setBasicChairVisibility(tableModel, slot, false)

	local clone = source:Clone()
	clone.Name = slot .. "_Chair"

	-- Remove scripts/seats from cloned chair assets for safety.
	for _, item in ipairs(clone:GetDescendants()) do
		if item:IsA("LuaSourceContainer") or item:IsA("Seat") then
			item:Destroy()
		end
	end

	clone.Parent = playerChairs

	local _, size = clone:GetBoundingBox()
	clone:PivotTo(seat.CFrame * CFrame.new(0, FLOOR_OFFSET + (size.Y / 2), 0))

	local primary = clone.PrimaryPart or clone:FindFirstChildWhichIsA("BasePart")
	if primary then
		primary.Anchored = false
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = primary
		weld.Part1 = seat
		weld.Parent = primary
	end
	if chairName == "Rainbow" then
		applyRainbowEffect(clone)
	end
end

task.spawn(function()
	local lastState = {}

	while true do
		task.wait(0.5)

		if not _G.SeatManager or not _G.GetEquippedChair then
			continue
		end

		local allTables = _G.SeatManager.getAllTables and _G.SeatManager.getAllTables() or {}
		for tableId, tableState in pairs(allTables) do
			lastState[tableId] = lastState[tableId] or {
				A = { player = nil, equipped = "" },
				B = { player = nil, equipped = "" },
			}

			for _, slot in ipairs({ "A", "B" }) do
				local seatState = tableState.seats[slot]
				local player = seatState and seatState.player
				local equipped = player and _G.GetEquippedChair(player) or "Default"

				local cache = lastState[tableId][slot]
				if cache.player ~= player or cache.equipped ~= equipped then
					cache.player = player
					cache.equipped = equipped
					spawnChair(tableState.model, slot, equipped)
				end
			end
		end
	end
end)

print("[TableChairVisualizer] Multi-table ready")
