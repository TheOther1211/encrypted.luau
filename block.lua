--// 🎵 Audio Auto Block with Toggle Button GUI
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local lp = Players.LocalPlayer
local PlayerGui = lp:WaitForChild("PlayerGui")

--// SETTINGS
local detectionRange   = 18
local detectionRangeSq = detectionRange * detectionRange
local facingCheckEnabled = true
local looseFacing = true
local doubleblocktech = false

--// Toggle state
local autoBlockAudioOn = false

--// Trigger sounds
local autoBlockTriggerSounds = {
    ["102228729296384"] = true,
    ["140242176732868"] = true,
    ["112809109188560"] = true,
    ["136323728355613"] = true,
    ["115026634746636"] = true,
    ["84116622032112"]  = true,
    ["108907358619313"] = true,
    ["127793641088496"] = true,
    ["86174610237192"]  = true,
    ["95079963655241"]  = true,
    ["101199185291628"] = true,
    ["119942598489800"] = true,
    ["84307400688050"]  = true,
    ["113037804008732"] = true,
    ["105200830849301"] = true,
    ["75330693422988"]  = true,
    ["82221759983649"]  = true,
    ["81702359653578"]  = true,
    ["108610718831698"] = true,
    ["112395455254818"] = true,
}

--// UI Button
local screenGui = Instance.new("ScreenGui", PlayerGui)
screenGui.Name = "AutoBlockGUI"

local toggleBtn = Instance.new("TextButton")
toggleBtn.Size = UDim2.new(0, 140, 0, 40)
toggleBtn.Position = UDim2.new(0.05, 0, 0.2, 0)
toggleBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
toggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleBtn.Font = Enum.Font.GothamBold
toggleBtn.TextSize = 16
toggleBtn.Text = "Audio Auto Block: OFF"
toggleBtn.Parent = screenGui
toggleBtn.Active = true
toggleBtn.Draggable = true

toggleBtn.MouseButton1Click:Connect(function()
    autoBlockAudioOn = not autoBlockAudioOn
    if autoBlockAudioOn then
        toggleBtn.Text = "Audio Auto Block: ON"
        toggleBtn.BackgroundColor3 = Color3.fromRGB(0, 170, 85)
    else
        toggleBtn.Text = "Audio Auto Block: OFF"
        toggleBtn.BackgroundColor3 = Color3.fromRGB(170, 40, 40)
    end
end)

--// Cached UI refs
local cachedPlayerGui = PlayerGui
local cachedBlockBtn, cachedCharges, cachedCooldown = nil, nil, nil

local function refreshUIRefs()
    local main = cachedPlayerGui:FindFirstChild("MainUI")
    if main then
        local ability = main:FindFirstChild("AbilityContainer")
        cachedBlockBtn = ability and ability:FindFirstChild("Block")
        local punchBtn = ability and ability:FindFirstChild("Punch")
        cachedCharges  = punchBtn and punchBtn:FindFirstChild("Charges")
        cachedCooldown = cachedBlockBtn and cachedBlockBtn:FindFirstChild("CooldownTime")
    end
end
refreshUIRefs()
cachedPlayerGui.ChildAdded:Connect(function(c)
    if c.Name == "MainUI" then task.delay(0.05, refreshUIRefs) end
end)

--// Helpers
local function fireRemoteBlock()
    ReplicatedStorage.Modules.Network.RemoteEvent:FireServer("UseActorAbility", "Block")
end

local function fireRemotePunch()
    ReplicatedStorage.Modules.Network.RemoteEvent:FireServer("UseActorAbility", "Punch")
end

local function isFacing(localRoot, targetRoot)
    if not facingCheckEnabled then return true end
    local dir = (localRoot.Position - targetRoot.Position).Unit
    local dot = targetRoot.CFrame.LookVector:Dot(dir)
    return looseFacing and dot > -0.3 or dot > 0
end

local soundHooks, soundBlockedUntil = {}, {}
local function extractNumericSoundId(sound)
    return tostring(sound.SoundId):match("%d+")
end

local function getSoundWorldPosition(sound)
    if sound.Parent:IsA("BasePart") then return sound.Parent.Position, sound.Parent end
    if sound.Parent:IsA("Attachment") and sound.Parent.Parent:IsA("BasePart") then
        return sound.Parent.Parent.Position, sound.Parent.Parent
    end
end

local function getCharacterFromDescendant(inst)
    local model = inst:FindFirstAncestorOfClass("Model")
    if model and model:FindFirstChildOfClass("Humanoid") then return model end
end

--// Core
local function attemptBlockForSound(sound)
    if not autoBlockAudioOn or not sound.IsPlaying then return end
    local id = extractNumericSoundId(sound)
    if not id or not autoBlockTriggerSounds[id] then return end

    -- throttle
    local t = tick()
    if soundBlockedUntil[sound] and t < soundBlockedUntil[sound] then return end

    local myChar = lp.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myRoot then return end

    local soundPos, soundPart = getSoundWorldPosition(sound)
    if not soundPos then return end

    local char = getCharacterFromDescendant(soundPart)
    local plr  = char and Players:GetPlayerFromCharacter(char)
    if not plr or plr == lp then return end

    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local dvec = hrp.Position - myRoot.Position
    if dvec.Magnitude^2 > detectionRangeSq then return end

    if cachedCooldown and cachedCooldown.Text ~= "" then return end
    if facingCheckEnabled and not isFacing(myRoot, hrp) then return end

    -- ✅ Block
    fireRemoteBlock()
    if doubleblocktech and cachedCharges and cachedCharges.Text == "1" then
        fireRemotePunch()
    end

    soundBlockedUntil[sound] = t + 1.2
end

--// Hook sounds
local function hookSound(sound)
    if soundHooks[sound] then return end
    local playedConn = sound.Played:Connect(function() pcall(attemptBlockForSound, sound) end)
    local propConn   = sound:GetPropertyChangedSignal("IsPlaying"):Connect(function()
        if sound.IsPlaying then pcall(attemptBlockForSound, sound) end
    end)
    local destroyConn = sound.Destroying:Connect(function()
        if playedConn.Connected then playedConn:Disconnect() end
        if propConn.Connected then propConn:Disconnect() end
        if destroyConn.Connected then destroyConn:Disconnect() end
        soundHooks[sound], soundBlockedUntil[sound] = nil, nil
    end)
    soundHooks[sound] = {playedConn, propConn, destroyConn}
end

for _, desc in ipairs(game:GetDescendants()) do
    if desc:IsA("Sound") then pcall(hookSound, desc) end
end
game.DescendantAdded:Connect(function(desc)
    if desc:IsA("Sound") then pcall(hookSound, desc) end
end)
