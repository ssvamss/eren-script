-- Services
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local ContextActionService = game:GetService("ContextActionService")
local HapticService = game:GetService("HapticService")

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
    pcall(function() LocalPlayer = Players:GetPropertyChangedSignal("LocalPlayer"):Wait() end)
    LocalPlayer = Players.LocalPlayer
end

local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")
local RootPart = Character:WaitForChild("HumanoidRootPart")

getgenv().ErenSettings = getgenv().ErenSettings or {
    SpeedEnabled = false,
    SpeedMode = "WalkSpeed",
    WalkSpeedValue = 16,
    StepsPerSecond = 20,
    
    FlyEnabled = false,
    FlySpeed = 50,
    FlyUp = false,
    FlyDown = false,
    
    GoodModeEnabled = false,
    NoclipEnabled = false,
    InfJumpEnabled = false,
    ESPEnabled = false,
    ShiftLockShowButton = false,
    ShiftLockEnabled = false,
    BypassActive = true
}
local Settings = getgenv().ErenSettings
getgenv().ErenEvents = {}

local Connections = {}
local function ClearConnections()
    for _, conn in pairs(Connections) do
        if typeof(conn) == "RBXScriptConnection" then conn:Disconnect() end
    end
    Connections = {}
end

local NaturalSpeed = math.floor(Humanoid and Humanoid.WalkSpeed or 16)

-- Metatable Bypass
local rawMetatable = getrawmetatable and getrawmetatable(game)
if rawMetatable and setreadonly and checkcaller then
    setreadonly(rawMetatable, false)
    local oldIndex = rawMetatable.__index
    local oldNewIndex = rawMetatable.__newindex
    local oldNamecall = rawMetatable.__namecall

    rawMetatable.__index = newcclosure(function(self, key)
        if Settings.BypassActive and Settings.GoodModeEnabled and not checkcaller() then
            if self:IsA("Humanoid") and key == "Health" then return self.MaxHealth end
            if self:IsA("BasePart") and (key == "Velocity" or key == "AssemblyLinearVelocity") then return Vector3.zero end
        end
        return oldIndex(self, key)
    end)

    rawMetatable.__newindex = newcclosure(function(self, key, value)
        if Settings.BypassActive and Settings.GoodModeEnabled and not checkcaller() and self:IsA("Humanoid") and key == "Health" then
            return nil
        end
        return oldNewIndex(self, key, value)
    end)

    rawMetatable.__namecall = newcclosure(function(self, ...)
        local method = getnamecallmethod()
        if Settings.BypassActive and not checkcaller() then
            if Settings.GoodModeEnabled and (method == "TakeDamage" or method == "BreakJoints") then return nil end
            if method == "FireServer" or method == "InvokeServer" then
                local remoteName = tostring(self):lower()
                if remoteName:find("ban") or remoteName:find("cheat") or remoteName:find("anticheat") then return nil end
            end
        end
        return oldNamecall(self, ...)
    end)
    setreadonly(rawMetatable, true)
end

-- ESP Engine
local TargetParent = (gethui and gethui()) or game:GetService("CoreGui") or LocalPlayer:WaitForChild("PlayerGui")
local ESPFolder = TargetParent:FindFirstChild("Eren_ESP") or Instance.new("Folder")
ESPFolder.Name = "Eren_ESP"
ESPFolder.Parent = TargetParent

local function ClearESP() ESPFolder:ClearAllChildren() end
getgenv().ErenEvents.ClearESP = ClearESP

local function UpdateESP()
    if not Settings.ESPEnabled then ClearESP() return end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then
            for _, part in ipairs(plr.Character:GetChildren()) do
                if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                    local boxName = plr.Name .. "_" .. part.Name
                    local box = ESPFolder:FindFirstChild(boxName) or Instance.new("SelectionBox")
                    box.Name = boxName
                    box.Color3 = Color3.fromRGB(255, 0, 0)
                    box.LineThickness = 0.035
                    box.Adornee = part
                    box.Parent = ESPFolder
                end
            end
        end
    end
end

-- Fly Controls Screen UI
local FlyGui = TargetParent:FindFirstChild("ErenFlyUI") or Instance.new("ScreenGui")
FlyGui.Name = "ErenFlyUI"
FlyGui.ResetOnSpawn = false
FlyGui.Parent = TargetParent

local FlyUpBtn = Instance.new("TextButton")
FlyUpBtn.Size = UDim2.new(0, 45, 0, 45)
FlyUpBtn.Position = UDim2.new(0.9, -50, 0.45, -50)
FlyUpBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
FlyUpBtn.Text = "▲"
FlyUpBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
FlyUpBtn.Visible = false
FlyUpBtn.Parent = FlyGui
Instance.new("UICorner", FlyUpBtn).CornerRadius = UDim.new(0, 8)

local FlyDownBtn = Instance.new("TextButton")
FlyDownBtn.Size = UDim2.new(0, 45, 0, 45)
FlyDownBtn.Position = UDim2.new(0.9, -50, 0.45, 5)
FlyDownBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
FlyDownBtn.Text = "▼"
FlyDownBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
FlyDownBtn.Visible = false
FlyDownBtn.Parent = FlyGui
Instance.new("UICorner", FlyDownBtn).CornerRadius = UDim.new(0, 8)

FlyUpBtn.MouseButton1Down:Connect(function() Settings.FlyUp = true end)
FlyUpBtn.MouseButton1Up:Connect(function() Settings.FlyUp = false end)
FlyDownBtn.MouseButton1Down:Connect(function() Settings.FlyDown = true end)
FlyDownBtn.MouseButton1Up:Connect(function() Settings.FlyDown = false end)

local BodyVelocity, BodyGyro
local isFlying = false

local function StopFly()
    if not isFlying then return end
    isFlying = false
    FlyUpBtn.Visible = false
    FlyDownBtn.Visible = false
    if BodyVelocity then BodyVelocity:Destroy() BodyVelocity = nil end
    if BodyGyro then BodyGyro:Destroy() BodyGyro = nil end
    if Humanoid then Humanoid.PlatformStand = false end
end

getgenv().ErenEvents.OnFlyToggled = function(state)
    if not state then StopFly() end
end

local function UpdateFly()
    if not Settings.FlyEnabled or not RootPart or not Humanoid or Humanoid.Health <= 0 then
        if isFlying then StopFly() end
        return
    end

    isFlying = true
    FlyUpBtn.Visible = true
    FlyDownBtn.Visible = true

    if not BodyVelocity or not BodyVelocity.Parent then
        BodyVelocity = Instance.new("BodyVelocity")
        BodyVelocity.MaxForce = Vector3.new(1e9, 1e9, 1e9)
        BodyVelocity.Velocity = Vector3.zero
        BodyVelocity.Parent = RootPart

        BodyGyro = Instance.new("BodyGyro")
        BodyGyro.MaxTorque = Vector3.new(1e9, 1e9, 1e9)
        BodyGyro.P = 9e4
        BodyGyro.CFrame = RootPart.CFrame
        BodyGyro.Parent = RootPart
    end

    Humanoid.PlatformStand = true
    local Camera = workspace.CurrentCamera
    local moveVec = Vector3.zero

    if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveVec = moveVec + Camera.CFrame.LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveVec = moveVec - Camera.CFrame.LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveVec = moveVec - Camera.CFrame.RightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveVec = moveVec + Camera.CFrame.RightVector end

    if Settings.FlyUp or UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveVec = moveVec + Vector3.new(0, 1, 0) end
    if Settings.FlyDown or UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then moveVec = moveVec - Vector3.new(0, 1, 0) end

    if moveVec.Magnitude > 0 then moveVec = moveVec.Unit * Settings.FlySpeed end
    BodyVelocity.Velocity = moveVec
    BodyGyro.CFrame = Camera.CFrame
end

-- Core Loops
table.insert(Connections, RunService.RenderStepped:Connect(function(deltaTime)
    if Settings.FlyEnabled then UpdateFly() end

    -- Speed Handling
    if Settings.SpeedEnabled and Character and Humanoid and RootPart and Humanoid.Health > 0 then
        if Settings.SpeedMode == "WalkSpeed" then
            Humanoid.WalkSpeed = Settings.WalkSpeedValue
        elseif Settings.SpeedMode == "Steps" then
            Humanoid.WalkSpeed = NaturalSpeed
            if Humanoid.MoveDirection.Magnitude > 0 then
                RootPart.CFrame = RootPart.CFrame + (Humanoid.MoveDirection * Settings.StepsPerSecond * deltaTime)
            end
        end
    else
        if Humanoid then Humanoid.WalkSpeed = NaturalSpeed end
    end

    if Settings.NoclipEnabled and Character then
        for _, part in ipairs(Character:GetDescendants()) do
            if part:IsA("BasePart") then part.CanCollide = false end
        end
    end

    UpdateESP()
end))

table.insert(Connections, UserInputService.JumpRequest:Connect(function()
    if Settings.InfJumpEnabled and Humanoid and Humanoid.Health > 0 then
        Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
    end
end))

-- Load UI from GitHub
loadstring(game:HttpGet("YOUR_RAW_GITHUB_URL_FOR_UI_LUA"))()
