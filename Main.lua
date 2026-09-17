-- Services
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local StatsService = game:GetService("Stats")
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

-- Memory Connections Manager
local Connections = {}
local function ClearConnections()
    for _, conn in pairs(Connections) do
        if typeof(conn) == "RBXScriptConnection" then
            conn:Disconnect()
        end
    end
    Connections = {}
end

----------------------------------------------------
-- GLOBAL SETTINGS & EVENTS SETUP
----------------------------------------------------
getgenv().ErenSettings = {
    SpeedEnabled = false,
    SpeedMode = "WalkSpeed",
    WalkSpeedValue = 999,
    StepsPerSecond = 100,
    
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
local NaturalSpeed = math.floor(Humanoid and Humanoid.WalkSpeed or 16)

----------------------------------------------------
-- SHIFT LOCK ENGINE VARIABLES
----------------------------------------------------
local UserGameSettings = UserSettings():GetService("UserGameSettings")
local OFFSET_VAL = 1.75 
local isMobile = false 
local MOUSE_SINK_ACTION = "DisableRightClickAction" 
local isCameraAnimated = false
local animatedFrameCounter = 0 
local currentTargetZoom = 12.5  
local smoothedOffset = 0  
local FIRST_PERSON_THRESHOLD = 0.999

local function SyncRotationSettings(enabled)
    pcall(function()
        if enabled then
            if UserGameSettings.RotationType ~= Enum.RotationType.CameraRelative then
                UserGameSettings.RotationType = Enum.RotationType.CameraRelative
            end
        else
            if UserGameSettings.RotationType ~= Enum.RotationType.MovementRelative then
                UserGameSettings.RotationType = Enum.RotationType.MovementRelative
            end
        end
    end)
end

local function handleRightClick(actionName, inputState, inputObject)
    return Enum.ContextActionResult.Sink
end

----------------------------------------------------
-- 1. METATABLE SPOOFING & DAMAGE BYPASS
----------------------------------------------------
local rawMetatable = getrawmetatable and getrawmetatable(game)
if rawMetatable and setreadonly and checkcaller then
    setreadonly(rawMetatable, false)
    local oldIndex = rawMetatable.__index
    local oldNewIndex = rawMetatable.__newindex
    local oldNamecall = rawMetatable.__namecall

    rawMetatable.__index = newcclosure(function(self, key)
        if Settings.BypassActive and Settings.GoodModeEnabled and not checkcaller() then
            if self:IsA("Humanoid") and key == "Health" then
                return self.MaxHealth
            elseif self:IsA("BasePart") then
                if key == "Velocity" or key == "AssemblyLinearVelocity" then return Vector3.zero end
                if key == "CanCollide" then return true end
            end
        end
        return oldIndex(self, key)
    end)

    rawMetatable.__newindex = newcclosure(function(self, key, value)
        if Settings.BypassActive and Settings.GoodModeEnabled and not checkcaller() then
            if self:IsA("Humanoid") and key == "Health" then
                return nil
            end
        end
        return oldNewIndex(self, key, value)
    end)

    rawMetatable.__namecall = newcclosure(function(self, ...)
        local method = getnamecallmethod()
        if Settings.BypassActive and not checkcaller() then
            if Settings.GoodModeEnabled and (method == "TakeDamage" or method == "BreakJoints") then
                return nil
            end
            if method == "FireServer" or method == "InvokeServer" then
                local remoteName = tostring(self):lower()
                if remoteName:find("ban") or remoteName:find("cheat") or remoteName:find("check") or remoteName:find("anticheat") or remoteName:find("speed") or remoteName:find("walk") or (Settings.GoodModeEnabled and (remoteName:find("kill") or remoteName:find("die") or remoteName:find("damage") or remoteName:find("reset"))) then
                    return nil
                end
            end
        end
        return oldNamecall(self, ...)
    end)

    setreadonly(rawMetatable, true)
end

----------------------------------------------------
-- 2. DYNAMIC SHIELD ENGINE
----------------------------------------------------
local function ProcessGoodModeShield()
    if not Settings.GoodModeEnabled or not Character or not RootPart then return end

    if Humanoid then
        Humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
        Humanoid.BreakJointsOnDeath = false
        if Humanoid.Health < Humanoid.MaxHealth and Humanoid.Health > 0 then
            Humanoid.Health = Humanoid.MaxHealth
        end
    end

    local currentSpeed = RootPart.AssemblyLinearVelocity.Magnitude
    local dynamicRadius = math.clamp(7 + (currentSpeed * 0.25), 7, 35)

    local overlapParams = OverlapParams.new()
    overlapParams.FilterType = Enum.RaycastFilterType.Exclude
    overlapParams.FilterDescendantsInstances = {Character}

    local nearbyParts = workspace:GetPartBoundsInRadius(RootPart.Position, dynamicRadius, overlapParams)
    local isNearHazard = false
    local isNearCheckpoint = false

    for _, part in ipairs(nearbyParts) do
        if part:IsA("BasePart") then
            local name = part.Name:lower()
            local color = part.Color
            local hasTouchInterest = part:FindFirstChildOfClass("TouchInterest") ~= nil

            local isCheckpointName = name:find("checkpoint") or name:find("stage") or name:find("spawn") or name:find("save") or name:find("flag")
            local isSafeColor = (color.G > 0.5 and color.R < 0.4) or (color.B > 0.5 and color.R < 0.4)

            if isCheckpointName or isSafeColor then
                local dist = (part.Position - RootPart.Position).Magnitude
                if dist < 6 then isNearCheckpoint = true end
            end

            local isRed = (color.R > 0.45 and color.G < 0.35 and color.B < 0.35) or part.BrickColor.Name:lower():find("red")
            local isKillName = name:find("kill") or name:find("lava") or name:find("laser") 
                            or name:find("dead") or name:find("death") or name:find("hurt") 
                            or name:find("danger") or name:find("hazard") or name:find("spike")
                            or name:find("damage") or name:find("harm") or name:find("saw") or name:find("spinner")

            if isRed or isKillName or (hasTouchInterest and not isCheckpointName and not isSafeColor and part.Transparency > 0.5) then
                isNearHazard = true
            end
        end
    end

    for _, part in ipairs(Character:GetDescendants()) do
        if part:IsA("BasePart") then
            if isNearHazard and not isNearCheckpoint then
                part.CanTouch = false
            else
                if not Settings.NoclipEnabled then part.CanTouch = true end
            end
        end
    end
end

----------------------------------------------------
-- 3. ESP ENGINE
----------------------------------------------------
local TargetParent = (gethui and gethui()) or game:GetService("CoreGui") or LocalPlayer:WaitForChild("PlayerGui")
local ESPFolder = TargetParent:FindFirstChild("ESP_Storage") or Instance.new("Folder")
ESPFolder.Name = "ESP_Storage"
ESPFolder.Parent = TargetParent

local function ClearESP()
    ESPFolder:ClearAllChildren()
end

local function UpdateESP()
    if not Settings.ESPEnabled then
        ClearESP()
        return
    end

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then
            local char = plr.Character
            for _, part in ipairs(char:GetChildren()) do
                if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                    local boxName = plr.Name .. "_" .. part.Name
                    local box = ESPFolder:FindFirstChild(boxName)
                    if not box then
                        box = Instance.new("SelectionBox")
                        box.Name = boxName
                        box.Color3 = Color3.fromRGB(255, 0, 0)
                        box.LineThickness = 0.035
                        box.SurfaceTransparency = 1
                        box.Parent = ESPFolder
                    end
                    box.Adornee = part
                end
            end
        end
    end
end

----------------------------------------------------
-- 4. FLY ENGINE
----------------------------------------------------
local BodyVelocity, BodyGyro
local isFlying = false

local function StopFly()
    if not isFlying and not BodyVelocity and not BodyGyro then return end
    isFlying = false

    if BodyVelocity then BodyVelocity:Destroy() BodyVelocity = nil end
    if BodyGyro then BodyGyro:Destroy() BodyGyro = nil end

    if Humanoid and RootPart then 
        Humanoid.PlatformStand = false 
        RootPart.AssemblyLinearVelocity = Vector3.zero
        RootPart.AssemblyAngularVelocity = Vector3.zero

        Humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
        Humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, true)
        Humanoid:ChangeState(Enum.HumanoidStateType.Landed)
        task.defer(function()
            if Humanoid then Humanoid:ChangeState(Enum.HumanoidStateType.Running) end
        end)
    end
end

local function UpdateFly()
    if not Settings.FlyEnabled or not RootPart or not Humanoid or Humanoid.Health <= 0 then
        if isFlying then StopFly() end
        return
    end

    isFlying = true

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

    if Humanoid.MoveDirection.Magnitude > 0 and moveVec.Magnitude == 0 then
        local lookXZ = Vector3.new(Camera.CFrame.LookVector.X, 0, Camera.CFrame.LookVector.Z)
        local rightXZ = Vector3.new(Camera.CFrame.RightVector.X, 0, Camera.CFrame.RightVector.Z)
        
        if lookXZ.Magnitude > 0 then lookXZ = lookXZ.Unit end
        if rightXZ.Magnitude > 0 then rightXZ = rightXZ.Unit end
        
        local forwardComp = Humanoid.MoveDirection:Dot(lookXZ)
        local rightComp = Humanoid.MoveDirection:Dot(rightXZ)
        
        moveVec = (Camera.CFrame.LookVector * forwardComp) + (Camera.CFrame.RightVector * rightComp)
    end

    if Settings.FlyUp or UserInputService:IsKeyDown(Enum.KeyCode.Space) then
        moveVec = moveVec + Vector3.new(0, 1, 0)
    end
    if Settings.FlyDown or UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
        moveVec = moveVec - Vector3.new(0, 1, 0)
    end

    if moveVec.Magnitude > 0 then
        moveVec = moveVec.Unit * Settings.FlySpeed
    end

    BodyVelocity.Velocity = moveVec
    BodyGyro.CFrame = Camera.CFrame
end

----------------------------------------------------
-- 5. SHIFT LOCK ENGINE & OVERLAY
----------------------------------------------------
local LockButton, Crosshair

local function EnforceShiftLock(deltaTime)
    deltaTime = deltaTime or 0.016
    local cam = workspace.CurrentCamera
    if not cam then return end

    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")

    local isDeadState = (not char or not hum or hum.Health <= 0 or not root)
    local isCurrentlyAnimated = false

    if not isDeadState then
        if cam.CameraType == Enum.CameraType.Scriptable or cam.CameraSubject ~= hum then
            isCurrentlyAnimated = true
        end
    end
    
    if isCurrentlyAnimated then
        animatedFrameCounter = 0 
        isCameraAnimated = true
    else
        if animatedFrameCounter > 0 then
            animatedFrameCounter = animatedFrameCounter - 1
            isCameraAnimated = true 
        else
            isCameraAnimated = false 
        end
    end

    if Settings.ShiftLockEnabled then
        UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
        SyncRotationSettings(true)
        if Crosshair then Crosshair.Visible = (isCameraAnimated == false) end
        
        pcall(function()
            if LocalPlayer.DevCameraOcclusionMode ~= Enum.DevCameraOcclusionMode.Invisicam then
                LocalPlayer.DevCameraOcclusionMode = Enum.DevCameraOcclusionMode.Invisicam
            end
        end)
    else
        if Crosshair then Crosshair.Visible = false end
    end

    local dynamicInvisicamDistance = currentTargetZoom
    if cam.Focus then
        dynamicInvisicamDistance = (cam.Focus.p - cam.CFrame.p).Magnitude
    end

    local isFirstPerson = (dynamicInvisicamDistance < FIRST_PERSON_THRESHOLD)
    local targetOffset = (Settings.ShiftLockEnabled and not isFirstPerson and not isCameraAnimated) and OFFSET_VAL or 0
    
    smoothedOffset = targetOffset

    if smoothedOffset ~= 0 or Settings.ShiftLockEnabled then 
        local shiftedCFrame = cam.CFrame * CFrame.new(smoothedOffset, 0, 0)
        cam.CFrame = shiftedCFrame
        cam.Focus = shiftedCFrame * CFrame.new(0, 0, -dynamicInvisicamDistance)
    end
end

local function ToggleShiftLock(forceState)
    if forceState ~= nil then 
        Settings.ShiftLockEnabled = forceState 
    else 
        Settings.ShiftLockEnabled = not Settings.ShiftLockEnabled 
    end

    task.spawn(function()
        local gamepad = Enum.UserInputType.Gamepad1 
        if HapticService:IsVibrationSupported(gamepad) then
            pcall(function() 
                HapticService:SetMotor(gamepad, Enum.VibrationMotor.Large, 0.4) 
                task.wait(0.05) 
                HapticService:SetMotor(gamepad, Enum.VibrationMotor.Large, 0) 
            end)
        end
    end)
    
    if Settings.ShiftLockEnabled then
        if LockButton then LockButton.Image = "rbxasset://textures/ui/mouseLock_on@2x.png" end
        pcall(function() LocalPlayer:GetMouse().Icon = "rbxasset://textures/MouseLockedCursor.png" end)
        SyncRotationSettings(true)
        
        if not isMobile then
            ContextActionService:BindActionAtPriority(
                MOUSE_SINK_ACTION, handleRightClick, false, 
                Enum.ContextActionPriority.High.Value + 100, Enum.UserInputType.MouseButton2
            )
        end
        
        pcall(function()
            UserGameSettings.ComputerCameraMovementMode = Enum.ComputerCameraMovementMode.Classic
            UserGameSettings.TouchCameraMovementMode = Enum.TouchCameraMovementMode.Classic
        end)
    else
        if LockButton then LockButton.Image = "rbxasset://textures/ui/mouseLock_off@2x.png" end
        pcall(function() LocalPlayer:GetMouse().Icon = "" end)
        ContextActionService:UnbindAction(MOUSE_SINK_ACTION)
        SyncRotationSettings(false)
        UserInputService.MouseBehavior = Enum.MouseBehavior.Default
        
        pcall(function()
            LocalPlayer.DevCameraOcclusionMode = Enum.DevCameraOcclusionMode.Zoom
        end)
    end
end

----------------------------------------------------
-- 6. HUD OVERLAYS & FLY BUTTONS
----------------------------------------------------
if TargetParent:FindFirstChild("ErenOverlays") then TargetParent.ErenOverlays:Destroy() end

local OverlayGui = Instance.new("ScreenGui")
OverlayGui.Name = "ErenOverlays"
OverlayGui.ResetOnSpawn = false
OverlayGui.Parent = TargetParent

LockButton = Instance.new("ImageButton")
LockButton.Name = "LockButton"
LockButton.Parent = OverlayGui
LockButton.AnchorPoint = Vector2.new(0.5, 0.5)
LockButton.Position = UDim2.new(0.83, 0, 0.83, 0)
LockButton.Size = UDim2.new(0.045, 0, 0.045, 0) 
LockButton.BackgroundTransparency = 1 
LockButton.Image = "rbxasset://textures/ui/mouseLock_off@2x.png"
LockButton.Visible = false

local UIAspect = Instance.new("UIAspectRatioConstraint")
UIAspect.AspectRatio = 1
UIAspect.AspectType = Enum.AspectType.ScaleWithParentSize
UIAspect.Parent = LockButton

Crosshair = Instance.new("ImageLabel")
Crosshair.Name = "Crosshair"
Crosshair.Parent = OverlayGui
Crosshair.AnchorPoint = Vector2.new(0.5, 0.5)
Crosshair.Position = UDim2.new(0.5, 0, 0.5, -29)
Crosshair.Size = UDim2.new(0, 32, 0, 32) 
Crosshair.BackgroundTransparency = 1
Crosshair.Image = "rbxasset://textures/MouseLockedCursor.png"
Crosshair.Visible = false

LockButton.MouseButton1Click:Connect(function() ToggleShiftLock() end)

local StatsFrame = Instance.new("Frame")
StatsFrame.Size = UDim2.new(0, 195, 0, 22)
StatsFrame.Position = UDim2.new(1, -205, 0, 10)
StatsFrame.BackgroundColor3 = Color3.fromRGB(14, 14, 18)
StatsFrame.BackgroundTransparency = 0.2
StatsFrame.Parent = OverlayGui
Instance.new("UICorner", StatsFrame).CornerRadius = UDim.new(0, 6)

local StatsLabel = Instance.new("TextLabel")
StatsLabel.Size = UDim2.new(1, 0, 1, 0)
StatsLabel.BackgroundTransparency = 1
StatsLabel.Text = "FPS: 60 | Ping: 0ms | Speed: 0"
StatsLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
StatsLabel.Font = Enum.Font.GothamMedium
StatsLabel.TextSize = 10
StatsLabel.Parent = StatsFrame

local FlyUpBtn = Instance.new("TextButton")
FlyUpBtn.Size = UDim2.new(0, 42, 0, 42)
FlyUpBtn.Position = UDim2.new(0.9, -45, 0.5, -45)
FlyUpBtn.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
FlyUpBtn.Text = "▲"
FlyUpBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
FlyUpBtn.Font = Enum.Font.GothamBold
FlyUpBtn.TextSize = 14
FlyUpBtn.Visible = false
FlyUpBtn.Parent = OverlayGui
Instance.new("UICorner", FlyUpBtn).CornerRadius = UDim.new(0, 8)

local FlyDownBtn = Instance.new("TextButton")
FlyDownBtn.Size = UDim2.new(0, 42, 0, 42)
FlyDownBtn.Position = UDim2.new(0.9, -45, 0.5, 5)
FlyDownBtn.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
FlyDownBtn.Text = "▼"
FlyDownBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
FlyDownBtn.Font = Enum.Font.GothamBold
FlyDownBtn.TextSize = 14
FlyDownBtn.Visible = false
FlyDownBtn.Parent = OverlayGui
Instance.new("UICorner", FlyDownBtn).CornerRadius = UDim.new(0, 8)

FlyUpBtn.MouseButton1Down:Connect(function() Settings.FlyUp = true end)
FlyUpBtn.MouseButton1Up:Connect(function() Settings.FlyUp = false end)
FlyDownBtn.MouseButton1Down:Connect(function() Settings.FlyDown = true end)
FlyDownBtn.MouseButton1Up:Connect(function() Settings.FlyDown = false end)

----------------------------------------------------
-- 7. EVENTS SYSTEM SETUP
----------------------------------------------------
getgenv().ErenEvents = {
    OnFlyToggled = function(Value)
        FlyUpBtn.Visible = Value
        FlyDownBtn.Visible = Value
        if not Value then StopFly() end
    end,
    ClearESP = function()
        ClearESP()
    end,
    OnShiftLockToggled = function(Value)
        if LockButton then LockButton.Visible = Value end
        if not Value and Settings.ShiftLockEnabled then ToggleShiftLock(false) end
    end
}

----------------------------------------------------
-- 8. RAYFIELD UI INTEGRATION
----------------------------------------------------
local Rayfield = loadstring(game:HttpGet("https://sirius.menu/gen2"))()

local Window = Rayfield:CreateWindow({
    Name = "Eren",
    Subtitle = "Gen2 Suite",
    SidebarLayout = true
})

-- Speed Tab
local SpeedTab = Window:CreateTab({ Name = "Speed", Icon = 0 })

SpeedTab:CreateToggle({
    Name = "Enable Speed",
    CurrentValue = Settings.SpeedEnabled,
    Callback = function(Value) Settings.SpeedEnabled = Value end
})

SpeedTab:CreateDropdown({
    Name = "Speed Mode",
    Options = {"WalkSpeed", "Steps"},
    CurrentOption = {Settings.SpeedMode},
    MultipleOptions = false,
    Callback = function(Option)
        if typeof(Option) == "table" then
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
    Callback = function(Value) Settings.WalkSpeedValue = Value end
})

SpeedTab:CreateSlider({
    Name = "Steps/s Value",
    Range = {1, 999},
    Increment = 1,
    CurrentValue = Settings.StepsPerSecond,
    Callback = function(Value) Settings.StepsPerSecond = Value end
})

-- Flight Tab
local FlightTab = Window:CreateTab({ Name = "Flight", Icon = 0 })

FlightTab:CreateToggle({
    Name = "Enable Fly",
    CurrentValue = Settings.FlyEnabled,
    Callback = function(Value)
        Settings.FlyEnabled = Value
        if getgenv().ErenEvents and getgenv().ErenEvents.OnFlyToggled then
            getgenv().ErenEvents.OnFlyToggled(Value)
        end
    end
})

FlightTab:CreateSlider({
    Name = "Fly Speed",
    Range = {10, 500},
    Increment = 5,
    CurrentValue = Settings.FlySpeed,
    Callback = function(Value) Settings.FlySpeed = Value end
})

-- General Tab
local GeneralTab = Window:CreateTab({ Name = "General & ESP", Icon = 0 })

GeneralTab:CreateToggle({
    Name = "Godmode",
    CurrentValue = Settings.GoodModeEnabled,
    Callback = function(Value) Settings.GoodModeEnabled = Value end
})

GeneralTab:CreateToggle({
    Name = "Noclip",
    CurrentValue = Settings.NoclipEnabled,
    Callback = function(Value) Settings.NoclipEnabled = Value end
})

GeneralTab:CreateToggle({
    Name = "Infinite Jump",
    CurrentValue = Settings.InfJumpEnabled,
    Callback = function(Value) Settings.InfJumpEnabled = Value end
})

GeneralTab:CreateToggle({
    Name = "Player ESP",
    CurrentValue = Settings.ESPEnabled,
    Callback = function(Value)
        Settings.ESPEnabled = Value
        if not Value and getgenv().ErenEvents and getgenv().ErenEvents.ClearESP then
            getgenv().ErenEvents.ClearESP()
        end
    end
})

GeneralTab:CreateToggle({
    Name = "Shift Lock Button",
    CurrentValue = Settings.ShiftLockShowButton,
    Callback = function(Value)
        Settings.ShiftLockShowButton = Value
        if getgenv().ErenEvents and getgenv().ErenEvents.OnShiftLockToggled then
            getgenv().ErenEvents.OnShiftLockToggled(Value)
        end
    end
})

Rayfield:Notify({
    Title = "Eren Loaded",
    Content = "UI Initialized Successfully.",
    Duration = 3
})

----------------------------------------------------
-- 9. CORE LOOPS & ACCURATE STEP SPEED ENGINE
----------------------------------------------------
local lastPos = RootPart and RootPart.Position or Vector3.zero
local currentRealSpeed = 0
local lastTime = os.clock()
local stepAccumulator = 0

local function SetupLoopConnections()
    table.insert(Connections, RunService.Stepped:Connect(function()
        if Settings.NoclipEnabled and Character then
            for _, part in ipairs(Character:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                    part.CanTouch = false
                end
            end
        end
        ProcessGoodModeShield()
    end))

    table.insert(Connections, RunService.RenderStepped:Connect(function(deltaTime)
        if Settings.FlyEnabled then UpdateFly() end
        
        -- Multi-mode Speed Processing
        if Settings.SpeedEnabled and Character and Humanoid and RootPart and Humanoid.Health > 0 then
            if Humanoid.MoveDirection.Magnitude > 0 then
                if Settings.SpeedMode == "WalkSpeed" then
                    local extraSpeed = math.max(0, Settings.WalkSpeedValue - NaturalSpeed)
                    RootPart.CFrame = RootPart.CFrame + (Humanoid.MoveDirection * extraSpeed * deltaTime)
                elseif Settings.SpeedMode == "Steps" then
                    local stepsPerSec = math.clamp(Settings.StepsPerSecond, 1, 999)
                    local stepInterval = 1 / stepsPerSec
                    local stepDistance = Settings.WalkSpeedValue / stepsPerSec

                    stepAccumulator = stepAccumulator + deltaTime
                    local stepsToTake = math.floor(stepAccumulator / stepInterval)
                    if stepsToTake > 0 then
                        stepAccumulator = stepAccumulator - (stepsToTake * stepInterval)
                        stepsToTake = math.min(stepsToTake, 10)
                        RootPart.CFrame = RootPart.CFrame + (Humanoid.MoveDirection * stepDistance * stepsToTake)
                    end
                end
            end
        end

        if RootPart and deltaTime > 0 then
            local nowPos = RootPart.Position
            local dist = (nowPos - lastPos).Magnitude
            currentRealSpeed = math.floor(dist / deltaTime)
            lastPos = nowPos
        end

        -- Update Stats Bar
        local currentTime = os.clock()
        local fps = math.floor(1 / math.max(0.001, currentTime - lastTime))
        lastTime = currentTime
        local ping = 0
        pcall(function() ping = math.floor(StatsService.Network.ServerStatsItem["Data Ping"]:GetValue()) end)
        StatsLabel.Text = string.format("FPS: %d | Ping: %dms | Speed: %d", fps, ping, currentRealSpeed)

        UpdateESP()
        EnforceShiftLock(deltaTime)
    end))

    table.insert(Connections, UserInputService.JumpRequest:Connect(function()
        if Settings.InfJumpEnabled and Humanoid and Humanoid.Health > 0 then
            Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end))

    table.insert(Connections, UserInputService.PointerAction:Connect(function(wheelDelta)
        if wheelDelta ~= 0 then
            currentTargetZoom = wheelDelta > 0 and math.max(0.6, currentTargetZoom - 1.5) or math.min(LocalPlayer.CameraMaxZoomDistance, currentTargetZoom + 1.5)
        end
    end))

    table.insert(Connections, UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if not isMobile and (input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift) then
            ToggleShiftLock()
        end
    end))

    table.insert(Connections, UserInputService.LastInputTypeChanged:Connect(function(lastInputType)
        isMobile = (lastInputType == Enum.UserInputType.Touch)
        LocalPlayer.DevEnableMouseLock = false 

        if LockButton then
            LockButton.Visible = Settings.ShiftLockShowButton
            if not isMobile and Settings.ShiftLockEnabled then
                ContextActionService:BindActionAtPriority(
                    MOUSE_SINK_ACTION, handleRightClick, false, 
                    Enum.ContextActionPriority.High.Value + 100, Enum.UserInputType.MouseButton2
                )
            end
        end
    end))
end

SetupLoopConnections()

local function BindCharacterEvents()
    if Humanoid then
        NaturalSpeed = math.floor(Humanoid.WalkSpeed)
        table.insert(Connections, Humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
            NaturalSpeed = math.floor(Humanoid.WalkSpeed)
            if not Settings.SpeedEnabled then Settings.WalkSpeedValue = NaturalSpeed end
        end))

        table.insert(Connections, Humanoid.HealthChanged:Connect(function(newHealth)
            if Settings.GoodModeEnabled and newHealth < Humanoid.MaxHealth then
                Humanoid.Health = Humanoid.MaxHealth
            end
        end))
    end
end
BindCharacterEvents()

LocalPlayer.CharacterAdded:Connect(function(newChar)
    ClearConnections()
    Character = newChar
    Humanoid = Character:WaitForChild("Humanoid")
    RootPart = Character:WaitForChild("HumanoidRootPart")
    lastPos = RootPart.Position
    isFlying = false
    currentTargetZoom = 12.5
    smoothedOffset = 0
    stepAccumulator = 0
    task.wait(0.3)
    BindCharacterEvents()
    SetupLoopConnections()

    if Settings.ShiftLockEnabled then
        pcall(function() LocalPlayer:GetMouse().Icon = "rbxasset://textures/MouseLockedCursor.png" end)
        SyncRotationSettings(true)
        if not isMobile then
            ContextActionService:BindActionAtPriority(MOUSE_SINK_ACTION, handleRightClick, false, Enum.ContextActionPriority.High.Value + 100, Enum.UserInputType.MouseButton2)
        end
    else
        SyncRotationSettings(false)
        UserInputService.MouseBehavior = Enum.MouseBehavior.Default
    end
end)
