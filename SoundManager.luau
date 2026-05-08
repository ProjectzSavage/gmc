-- StarterGui/SoundManager
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Preload sounds
local SOUNDS = {
	Click  = playerGui:WaitForChild("GameGui"):WaitForChild("ClickSound"),
	Claim  = playerGui:WaitForChild("GameGui"):WaitForChild("ClaimSound"),
	Hover  = playerGui:WaitForChild("GameGui"):WaitForChild("BuyHover"),
	BuyRobux = playerGui:WaitForChild("GameGui"):WaitForChild("RobuxBuy"),
}

local function playSound(name)
	local s = SOUNDS[name]
	if s then
		s:Stop()
		s.TimePosition = 0
		s:Play()
	end
end

-- Hook into all buttons in GameGui
local function hookGui(gui)
	for _, btn in ipairs(gui:GetDescendants()) do
		if btn:IsA("TextButton") or btn:IsA("ImageButton") then
			btn.MouseButton1Click:Connect(function()
				-- Detect if this is a robux purchase or standard click
				local isRobux = (btn.Name:lower():find("buy") or btn.Text:lower():find("robux") or btn.Text:lower():find("r$"))
				if isRobux then
					playSound("BuyRobux")
				else
					playSound("Click")
				end
			end)

			btn.MouseEnter:Connect(function()
				playSound("Hover")
			end)
		end
	end
end

hookGui(playerGui:WaitForChild("GameGui"))

-- Global API for other scripts to trigger Claim sound
_G.PlayClaimSound = function() playSound("Claim") end
_G.PlayClickSound = function() playSound("Click") end
_G.PlayRobuxSound = function() playSound("BuyRobux") end

print("[SoundManager] Ready")