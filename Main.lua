-- Services
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

-- Global Settings Setup
getgenv().ErenSettings = {
    SpeedEnabled = false,
    SpeedMode = "WalkSpeed",
    WalkSpeedValue = 16,
    StepsPerSecond = 20,
    
    FlyEnabled = false,
    FlySpeed = 50,
    FlyUp = false,
    FlyDown = false,
    
    NoclipEnabled = false,
    InfJumpEnabled = false
}

local Settings = getgenv().ErenSettings

-- Dynamic Character Helper
local function GetCharacter()
    local char = LocalPlayer.Character
    if not char then return nil, nil, nil end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    return char, hum, root
end

-- Load Rayfield UI
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
    Name = "Eren Suite",
    LoadingTitle = "Eren Script Loading...",
    LoadingSubtitle = "by Eren",
    ConfigurationSaving = { Enabled = false },
    KeySystem = false
})

-- Create Tabs
local SpeedTab = Window:CreateTab("Speed", 4483362458)
local FlightTab = Window:CreateTab("Flight", 4483362458)
local GeneralTab = Window:CreateTab("General", 4483362458)

-- 1. Speed Controls
SpeedTab:CreateToggle({
    Name = "Enable Speed",
    CurrentValue = Settings.SpeedEnabled,
    Callback = function(Value)
        Settings.SpeedEnabled = Value
    end
})

SpeedTab:CreateDropdown({
    Name = "Speed Mode",
    Options = {"WalkSpeed", "Steps"},
    CurrentOption = Settings.SpeedMode,
    Callback = function(Option)
        if type(Option) == "table" then
            Settings.SpeedMode = Option[1]
        else
            Settings.SpeedMode = Option
        end
    end
})

SpeedTab:CreateSlider({
    Name = "WalkSpeed Value",
    Range = {16, 999},
    Increment = 1,
    CurrentValue = Settings.WalkSpeedValue,
    Callback = function(Value)
        Settings.WalkSpeedValue = Value
    end
})

SpeedTab:CreateSlider({
    Name = "Steps/s Value",
    Range = {1, 999},
    Increment = 1,
    CurrentValue = Settings.StepsPerSecond,
    Callback = function(Value)
        Settings.StepsPerSecond = Value
    end
})

-- 2. Flight Controls
FlightTab:CreateToggle({
    Name = "Enable Fly",
    CurrentValue = Settings.FlyEnabled,
    Callback = function(Value)
        Settings.FlyEnabled = Value
    end
})

FlightTab:CreateSlider({
    Name = "Fly Speed",
    Range = {10, 500},
    Increment = 5,
    CurrentValue = Settings.FlySpeed,
    Callback = function(Value)
        Settings.FlySpeed = Value
    end
})

-- 3. General Controls
GeneralTab:CreateToggle({
    Name = "Noclip",
    CurrentValue = Settings.NoclipEnabled,
    Callback = function(Value)
        Settings.NoclipEnabled = Value
    end
})

GeneralTab:CreateToggle({
    Name = "Infinite Jump",
    CurrentValue = Settings.InfJumpEnabled,
    Callback = function(Value)
        Settings.InfJumpEnabled = Value
    end
})

-- On-Screen Flight Buttons GUI
local TargetParent = (gethui and gethui()) or game:GetService("CoreGui") or LocalPlayer:WaitForChild("PlayerGui")
local FlyGui = TargetParent:FindFirstChild("ErenFlyUI") or Instance.new("ScreenGui")
FlyGui.Name = "ErenFlyUI"
FlyGui.ResetOnSpawn = false
FlyGui.Parent = TargetParent

local FlyUpBtn = FlyGui:FindFirstChild("FlyUpBtn") or Instance.new("TextButton")
FlyUpBtn.Name = "FlyUpBtn"
FlyUpBtn.Size = UDim2.new(0, 50, 0, 50)
FlyUpBtn.Position = UDim2.new(0.85, 0, 0.4, 0)
FlyUpBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
FlyUpBtn.Text = "▲"
FlyUpBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
FlyUpBtn.Visible = false
FlyUpBtn.Parent = FlyGui

local FlyDownBtn = FlyGui:FindFirstChild("FlyDownBtn") or Instance.new("TextButton")
FlyDownBtn.Name = "FlyDownBtn"
FlyDownBtn.Size = UDim2.new(0, 50, 0, 50)
FlyDownBtn.Position = UDim2.new(0.85, 0, 0.5, 0)
FlyDownBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
FlyDownBtn.Text = "▼"
FlyDownBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
FlyDownBtn.Visible = false
FlyDownBtn.Parent = FlyGui

FlyUpBtn.MouseButton1Down:Connect(function() Settings.FlyUp = true end)
FlyUpBtn.MouseButton1Up:Connect(function() Settings.FlyUp = false end)
FlyDownBtn.MouseButton1Down:Connect(function() Settings.FlyDown = true end)
FlyDownBtn.MouseButton1Up:Connect(function() Settings.FlyDown = false end)

-- Main Physical Execution Loop
local BodyVelocity, BodyGyro

RunService.RenderStepped:Connect(function(deltaTime)
    local Character, Humanoid, RootPart = GetCharacter()

    -- Speed Logic
    if Settings.SpeedEnabled and Character and Humanoid and RootPart and Humanoid.Health > 0 then
        if Settings.SpeedMode == "WalkSpeed" then
            Humanoid.WalkSpeed = Settings.WalkSpeedValue
        elseif Settings.SpeedMode == "Steps" then
            Humanoid.WalkSpeed = 16
            if Humanoid.MoveDirection.Magnitude > 0 then
                RootPart.CFrame = RootPart.CFrame + (Humanoid.MoveDirection * Settings.StepsPerSecond * deltaTime)
            end
        end
    elseif Humanoid and not Settings.SpeedEnabled then
        Humanoid.WalkSpeed = 16
    end

    -- Fly Logic
    if Settings.FlyEnabled and Character and Humanoid and RootPart and Humanoid.Health > 0 then
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

        if Settings.FlyUp then moveVec = moveVec + Vector3.new(0, 1, 0) end
        if Settings.FlyDown then moveVec = moveVec - Vector3.new(0, 1, 0) end

        if moveVec.Magnitude > 0 then moveVec = moveVec.Unit * Settings.FlySpeed end
        BodyVelocity.Velocity = moveVec
        BodyGyro.CFrame = Camera.CFrame
    else
        FlyUpBtn.Visible = false
        FlyDownBtn.Visible = false
        if BodyVelocity then BodyVelocity:Destroy() BodyVelocity = nil end
        if BodyGyro then BodyGyro:Destroy() BodyGyro = nil end
        if Humanoid then Humanoid.PlatformStand = false end
    end

    -- Noclip Logic
    if Settings.NoclipEnabled and Character then
        for _, part in ipairs(Character:GetDescendants()) do
            if part:IsA("BasePart") then part.CanCollide = false end
        end
    end
end)

-- Infinite Jump Request
UserInputService.JumpRequest:Connect(function()
    local _, Humanoid, _ = GetCharacter()
    if Settings.InfJumpEnabled and Humanoid and Humanoid.Health > 0 then
        Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
    end
end)
