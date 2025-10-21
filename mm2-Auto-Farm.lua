-- Clean Auto Farm Coins Script with Config System
-- Auto-start, bottom-right toggle notification, full-body noclip
-- Resets player when CoinCollected remote args 2 and 3 are equal
-- Only farms if player is alive
-- Auto-reexecute support

--[[
    CONFIGURATION EXAMPLE (Set before loadstring):
    
    getgenv().AutoFarm = {
        Enabled = true,
        AutoReexecute = true,
        TweenSpeed = 22
    }
    
    loadstring(game:HttpGet("https://raw.githubusercontent.com/ReflexInCs/Auto-Coin-Farm/refs/heads/main/mm2-Auto-Farm.lua"))()
]]

--// Configuration System (with defaults)
if not getgenv().AutoFarm then
    getgenv().AutoFarm = {
        Enabled = true,
        AutoReexecute = true,
        TweenSpeed = 22
    }
end

local config = getgenv().AutoFarm

--// Services
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--// Variables
local player = Players.LocalPlayer
local farmEnabled = config.Enabled
local noclipConnection = nil
local currentTween = nil
local usedCoinContainer = nil
local monitoring = true
local CoinCollected = ReplicatedStorage.Remotes.Gameplay.CoinCollected
local roles = nil

--// Auto-Reexecute System
if config.AutoReexecute then
    if queue_on_teleport then
        queue_on_teleport([[
            repeat task.wait() until game:IsLoaded()
            task.wait(2)
            loadstring(game:HttpGet("https://raw.githubusercontent.com/ReflexInCs/Auto-Coin-Farm/refs/heads/main/mm2-Auto-Farm.lua"))()
        ]])
    end
end

--// IsAlive check function
local function IsAlive(Player)
    for i, v in pairs(roles or {}) do
        if Player.Name == i then
            return not v.Killed and not v.Dead
        end
    end
    return false
end

--// Update roles data
local function updateRoles()
    local getData = ReplicatedStorage:FindFirstChild("GetPlayerData", true)
    if getData then
        pcall(function()
            roles = getData:InvokeServer()
        end)
    end
end

--// Create bottom-right toggle notification
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AutoFarmNotification"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 220, 0, 70)
frame.Position = UDim2.new(1, -230, 1, -90)
frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
frame.BorderSizePixel = 0
frame.Parent = screenGui
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -10, 0, 36)
title.Position = UDim2.new(0, 10, 0, 6)
title.BackgroundTransparency = 1
title.Text = "Auto Farm: " .. (config.Enabled and "ENABLED" or "DISABLED")
title.TextColor3 = Color3.new(1, 1, 1)
title.TextSize = 15
title.Font = Enum.Font.GothamBold
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = frame

local toggleButton = Instance.new("TextButton")
toggleButton.Size = UDim2.new(0.9, 0, 0, 28)
toggleButton.Position = UDim2.new(0.05, 0, 0, 36)
toggleButton.BackgroundColor3 = config.Enabled and Color3.fromRGB(220, 60, 60) or Color3.fromRGB(60, 200, 80)
toggleButton.Text = config.Enabled and "Disable" or "Enable"
toggleButton.TextColor3 = Color3.new(1, 1, 1)
toggleButton.Font = Enum.Font.GothamBold
toggleButton.TextSize = 14
toggleButton.BorderSizePixel = 0
toggleButton.Parent = frame
Instance.new("UICorner", toggleButton).CornerRadius = UDim.new(0, 8)

--// Noclip handler (active only during farm)
local function setNoclip(state)
	if state and not noclipConnection then
		noclipConnection = RunService.Stepped:Connect(function()
			local char = player.Character
			if char then
				for _, part in pairs(char:GetDescendants()) do
					if part:IsA("BasePart") then
						part.CanCollide = false
					end
				end
			end
		end)
	elseif not state and noclipConnection then
		noclipConnection:Disconnect()
		noclipConnection = nil
	end
end

--// Find CoinContainer in map
local function findCoinContainer()
	for _, mapObj in pairs(Workspace:GetChildren()) do
		local container = mapObj:FindFirstChild("CoinContainer")
		if container then
			return container
		end
	end
	return nil
end

--// Farming Logic
local function farmCoins()
	setNoclip(true)

	while farmEnabled do
		-- Update roles and check if player is alive
		updateRoles()
		if not IsAlive(player) then
			task.wait(0.5)
			continue
		end

		local character = player.Character
		if not character then
			task.wait(0.5)
			continue
		end

		local HRP = character:FindFirstChild("HumanoidRootPart")
		if not HRP then
			task.wait(0.5)
			continue
		end

		local CoinContainer = findCoinContainer()
		if not CoinContainer then
			task.wait(0.3)
			continue
		end
		usedCoinContainer = CoinContainer

		-- Find nearest coin
		local coin, magnitude = nil, 9999999
		for _, v in pairs(CoinContainer:GetChildren()) do
			if v.Name == "Coin_Server" and v:IsA("BasePart") then
				local magn = (v.Position - HRP.Position).Magnitude
				if magn > 3 and magn < magnitude then
					magnitude = magn
					coin = v
				end
			end
		end

		if coin then
			local distance = magnitude
			local speed = config.TweenSpeed
			local tweenTime = math.max(0.05, distance / speed)

			if currentTween then
				pcall(function() currentTween:Cancel() end)
				currentTween = nil
			end

			local tweenInfo = TweenInfo.new(tweenTime, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut)
			currentTween = TweenService:Create(HRP, tweenInfo, { CFrame = CFrame.new(coin.Position) })
			pcall(function() currentTween:Play() end)

			local startTime = tick()
			while farmEnabled do
				if not coin or not coin.Parent then break end
				local currentDist = (coin.Position - HRP.Position).Magnitude
				if currentDist < 1.5 then break end
				if tick() - startTime > tweenTime + 1.2 then break end
				task.wait(0.03)
			end

			if coin and coin.Parent then
				pcall(function() coin:Destroy() end)
			end

			if currentTween then
				pcall(function() currentTween:Cancel() end)
				currentTween = nil
			end
		else
			task.wait(0.1)
		end
	end

	setNoclip(false)
	if currentTween then
		pcall(function() currentTween:Cancel() end)
		currentTween = nil
	end
end

--// Remote listener for bag full (args 2 and 3 are equal)
CoinCollected.OnClientEvent:Connect(function(arg1, arg2, arg3, arg4)
	if type(arg2) == "number" and type(arg3) == "number" and arg2 >= arg3 then
		print("[AutoFarm] Coin bag full (" .. tostring(arg2) .. "/" .. tostring(arg3) .. ")")

		-- Stop farming immediately
		farmEnabled = false
		setNoclip(false)
		if currentTween then
			pcall(function() currentTween:Cancel() end)
			currentTween = nil
		end

		-- Respawn player
		task.wait(0.2)
		local character = player.Character
		if character then
			local humanoid = character:FindFirstChild("Humanoid")
			if humanoid then
				humanoid.Health = 0
			end
		end

		-- Wait for next round (new CoinContainer)
		task.spawn(function()
			print("[AutoFarm] Waiting for next round...")
			repeat
				task.wait(2)
			until findCoinContainer()

			print("[AutoFarm] New round detected, resuming farm.")
			farmEnabled = true
			task.spawn(farmCoins)
		end)
	end
end)

--// Toggle button
toggleButton.MouseButton1Click:Connect(function()
	farmEnabled = not farmEnabled

	if farmEnabled then
		title.Text = "Auto Farm: ENABLED"
		toggleButton.Text = "Disable"
		toggleButton.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
		task.spawn(farmCoins)
	else
		title.Text = "Auto Farm: DISABLED"
		toggleButton.Text = "Enable"
		toggleButton.BackgroundColor3 = Color3.fromRGB(60, 200, 80)
		setNoclip(false)
		if currentTween then
			pcall(function() currentTween:Cancel() end)
			currentTween = nil
		end
	end
end)

--// Check player count on join
checkPlayerCount()

--// Monitor player count
Players.PlayerAdded:Connect(function()
    checkPlayerCount()
end)

--// Auto-start farming
task.spawn(farmCoins)
print("✅ Auto Farm started with config system")
print("Config: AutoReexecute=" .. tostring(config.AutoReexecute) .. 
      ", AutoHop=" .. tostring(config.AutoHopIfMorePlayer) .. 
      ", MaxPlayers=" .. tostring(config.MaxPlayers))
