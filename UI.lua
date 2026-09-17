local Rayfield = loadstring(game:HttpGet("https://sirius.menu/gen2"))()

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
    Callback = function(Option) Settings.SpeedMode = Option[1] end
})

SpeedTab:CreateSlider({
    Name = "WalkSpeed Value",
    Range = {16, 300},
    Increment = 1,
    CurrentValue = Settings.WalkSpeedValue,
    Callback = function(Value) Settings.WalkSpeedValue = Value end
})

SpeedTab:CreateSlider({
    Name = "Steps/s Value",
    Range = {1, 100},
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
    Range = {10, 300},
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
