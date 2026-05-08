local RS = game:GetService("ReplicatedStorage")
local Equippable = RS:WaitForChild("Chairs"):WaitForChild("EquippableChairs")
local Table = workspace:WaitForChild("Table")
local PlayerChairsFolder = Table:WaitForChild("PlayerChairs")

local FLOOR_OFFSET = -1.65 

local function spawnChair(slot, name)
	local existing = PlayerChairsFolder:FindFirstChild(slot.."_Chair")
	if existing then existing:Destroy() end
	local seat = Table:FindFirstChild("Seat"..slot)
	local basic = Table:FindFirstChild("BasicChair"..slot)

	if name == "Default" or not name then
		if basic then for _, p in ipairs(basic:GetDescendants()) do if p:IsA("BasePart") then p.Transparency = 0 end end end
		return
	end

	if basic then for _, p in ipairs(basic:GetDescendants()) do if p:IsA("BasePart") then p.Transparency = 1 end end end
	local m = Equippable:FindFirstChild(name)
	if not m then return end

	local clone = m:Clone()
	clone.Name = slot.."_Chair"
	-- STRIP SCRIPTS (Fixed your character skin bug)
	for _, d in ipairs(clone:GetDescendants()) do 
		if d:IsA("LuaSourceContainer") or d:IsA("Seat") then d:Destroy() end 
	end
	clone.Parent = PlayerChairsFolder

	local _, size = clone:GetBoundingBox()
	clone:PivotTo(seat.CFrame * CFrame.new(0, FLOOR_OFFSET + (size.Y/2), 0))

	local primary = clone.PrimaryPart or clone:FindFirstChildWhichIsA("BasePart")
	if primary then
		primary.Anchored = false
		local w = Instance.new("WeldConstraint")
		w.Part0 = primary; w.Part1 = seat; w.Parent = primary
	end
end

task.spawn(function()
	local lastP = {A=nil, B=nil}
	local lastE = {A="", B=""}
	while true do
		task.wait(0.5)
		if _G.SeatManager and _G.GetEquippedChair then
			local s = _G.SeatManager.getSeats()
			for _, v in ipairs({"A", "B"}) do
				local p = s[v] and s[v].player
				local eq = p and _G.GetEquippedChair(p) or "Default"
				if p ~= lastP[v] or eq ~= lastE[v] then
					lastP[v] = p
					lastE[v] = eq
					spawnChair(v, eq)
				end
			end
		end
	end
end)