local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local HttpService = game:GetService("HttpService")

local MM2_PLACE_ID = 142823291
local MMV_PLACE_ID = 116924926476457
local IS_MM_GAME = (game.PlaceId == MM2_PLACE_ID) or (game.PlaceId == MMV_PLACE_ID)

if not IS_MM_GAME then
    local notif = Instance.new("ScreenGui")
    notif.Name = "GeloWareBlocked"
    notif.IgnoreGuiInset = true
    notif.ResetOnSpawn = false
    notif.Parent = game.CoreGui

    local box = Instance.new("Frame")
    box.Size = UDim2.new(0, 400, 0, 100)
    box.Position = UDim2.new(0.5, -200, 0.5, -50)
    box.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
    box.BorderSizePixel = 0
    box.Parent = notif
    local corner = Instance.new("UICorner") corner.CornerRadius = UDim.new(0, 12) corner.Parent = box
    local stroke = Instance.new("UIStroke") stroke.Color = Color3.fromRGB(220, 60, 60) stroke.Thickness = 1.5 stroke.Parent = box

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -20, 0, 30)
    title.Position = UDim2.new(0, 10, 0, 15)
    title.BackgroundTransparency = 1
    title.Text = "GeloWare"
    title.TextColor3 = Color3.fromRGB(235, 238, 245)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 18
    title.Parent = box

    local text = Instance.new("TextLabel")
    text.Size = UDim2.new(1, -20, 0, 40)
    text.Position = UDim2.new(0, 10, 0, 45)
    text.BackgroundTransparency = 1
    text.Text = "Скрипт работает только в MM2 / MMV"
    text.TextColor3 = Color3.fromRGB(200, 90, 90)
    text.Font = Enum.Font.GothamMedium
    text.TextSize = 13
    text.TextWrapped = true
    text.Parent = box

    task.delay(6, function() notif:Destroy() end)
    return
end

local FOLDER = "GeloWare"
local STATE_FILE = FOLDER .. "/state.json"
local WAYPOINT_FILE = FOLDER .. "/waypoints.json"
if isfolder and not isfolder(FOLDER) then pcall(function() makefolder(FOLDER) end) end

local function safeRead(path, default)
    if not readfile then return default end
    local ok, data = pcall(function() return readfile(path) end)
    if not ok or not data or data == "" then return default end
    local ok2, parsed = pcall(function() return HttpService:JSONDecode(data) end)
    if not ok2 then return default end
    return parsed
end
local function safeWrite(path, tbl)
    if not writefile then return end
    pcall(function() writefile(path, HttpService:JSONEncode(tbl)) end)
end

local Settings = {
    AutoGunLooter = false, KillAll = false,
    PlayerESP = false, NameTags = false, SeeInvisibles = false, Tracers = false,
    Fly = false, NoClip = false, AimBot = false, AimBotFOV = 100, AimBotPrediction = 50,
    AimBotOnlyMurderer = false, AimBotWallCheck = true, LockMouse = false,
    MurderNotification = false, SheriffNotification = false,
    Ambience = false, AmbienceType = "Day", Shaders = false, ShaderMode = 1,
    Particles = false,
    FlyKey = nil, AimBotKey = nil, LockMouseKey = nil, NoClipKey = nil,
}

local function SaveState()
    local data = {}
    for k, v in pairs(Settings) do
        if k ~= "LockMouse" then
            if typeof(v) == "EnumItem" then
                data[k] = tostring(v)
            else
                data[k] = v
            end
        end
    end
    safeWrite(STATE_FILE, data)
end

local KEYBIND_NAMES = { FlyKey = true, AimBotKey = true, LockMouseKey = true, NoClipKey = true }

local SavedState = safeRead(STATE_FILE, nil)
if type(SavedState) == "table" then
    for k, v in pairs(SavedState) do
        if KEYBIND_NAMES[k] then
            if type(v) == "string" then
                local keyName = v:gsub("Enum.KeyCode.", "")
                local ok, keyEnum = pcall(function() return Enum.KeyCode[keyName] end)
                if ok and keyEnum then
                    Settings[k] = keyEnum
                end
            end
        elseif Settings[k] ~= nil then
            Settings[k] = v
        end
    end
end

Settings.LockMouse = false

Waypoints = safeRead(WAYPOINT_FILE, {})

ToggleAutoGunLooter = function() end
ToggleKillAll = function() end
ToggleFly = function() end
ToggleNoClip = function() end
ToggleAimBot = function() end
ToggleLockMouse = function() end
ToggleTracers = function() end
ToggleParticles = function() end
ToggleShaders = function() end
SetShaderModeByNumber = function() end
UpdateAllVisuals = function() end
ClearAllESP = function() end
ClearAllNameTags = function() end
ClearAllInvisibleESP = function() end
ApplySkybox = function() end
RemoveSkybox = function() end
ShowNotification = function() end

local PlayerData = {}
local GameplayRemotes, GetCurrentPlayerData, PlayerDataChanged = nil, nil, nil
do
    local ok, remotes = pcall(function() return ReplicatedStorage:WaitForChild("Remotes", 10) end)
    if ok and remotes then
        local ok2, gameplay = pcall(function() return remotes:WaitForChild("Gameplay", 10) end)
        if ok2 and gameplay then
            GameplayRemotes = gameplay
            GetCurrentPlayerData = gameplay:WaitForChild("GetCurrentPlayerData", 10)
            PlayerDataChanged = gameplay:WaitForChild("PlayerDataChanged", 10)
        end
    end
end

local function GetRoleFromInfo(info)
    if not info then return nil end
    local role = tostring(info.Role or ""):lower()
    if role:find("murder") or role:find("killer") then return "Murderer" end
    if role:find("sheriff") or role:find("police") then return "Sheriff" end
    if role:find("hero") then return "Hero" end
    if role:find("innocent") or role:find("civilian") then return "Innocent" end
    return nil
end
local function UpdatePlayerData(newData)
    if type(newData) ~= "table" then return end
    PlayerData = newData
end
local function FetchPlayerData()
    if not GetCurrentPlayerData then return end
    task.spawn(function()
        local ok, data = pcall(function() return GetCurrentPlayerData:InvokeServer() end)
        if ok and type(data) == "table" then UpdatePlayerData(data) end
    end)
end
if GetCurrentPlayerData then FetchPlayerData() end
if PlayerDataChanged then
    PlayerDataChanged.OnClientEvent:Connect(function(newData)
        if type(newData) == "table" then UpdatePlayerData(newData) else FetchPlayerData() end
    end)
end
if GameplayRemotes then
    for _, remoteName in ipairs({"RoleSelect", "ShowRoleSelect", "ShowRoleSelectNew", "RoundStart"}) do
        local remote = GameplayRemotes:FindFirstChild(remoteName)
        if remote then remote.OnClientEvent:Connect(function() task.wait(0.05) FetchPlayerData() end) end
    end
    local RoundEndFade = GameplayRemotes:FindFirstChild("RoundEndFade")
    if RoundEndFade then RoundEndFade.OnClientEvent:Connect(function() PlayerData = {} end) end
end

local function GetPlayerRole(player)
    if not player then return "Lobby" end
    local info = PlayerData[player.Name]
    if not info or type(info) ~= "table" then return "Lobby" end
    if info.Dead == true then return "Lobby" end
    local role = info.Role
    if not role or role == "" then return "Lobby" end
    return GetRoleFromInfo(info) or "Innocent"
end
local function GetRoleColor(role)
    if role == "Murderer" then return Color3.fromRGB(230, 40, 40) end
    if role == "Sheriff" then return Color3.fromRGB(40, 120, 255) end
    if role == "Hero" then return Color3.fromRGB(255, 215, 0) end
    if role == "Innocent" then return Color3.fromRGB(0, 220, 40) end
    return Color3.fromRGB(200, 200, 210)
end
local function IsSheriffDead()
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local info = PlayerData[player.Name]
            if info and type(info) == "table" then
                local role = tostring(info.Role or ""):lower()
                if role:find("sheriff") or role:find("police") then
                    if info.Dead ~= true then return false end
                end
            end
        end
    end
    return true
end
local function PlayerHasGun(player)
    local char = player.Character
    if not char then return false end
    local bp = player:FindFirstChild("Backpack")
    local function check(c)
        if not c then return false end
        for _, t in pairs(c:GetChildren()) do
            if t:IsA("Tool") then
                local n = t.Name:lower()
                if n:find("gun") or n:find("revolver") or n:find("pistol") or n:find("sheriff") then return true end
            end
        end
        return false
    end
    return check(char) or check(bp)
end
local function IsHero(player)
    local role = GetPlayerRole(player)
    if role == "Sheriff" or role == "Murderer" then return false end
    if not IsSheriffDead() then return false end
    if not PlayerHasGun(player) then return false end
    return true
end

local InvisibleHighlights = {}
local ESPHighlights = {}
local NameTagGuis = {}

local function IsCharacterInvisible(player)
    local char = player.Character
    if not char then return false end
    local h = char:FindFirstChildOfClass("Humanoid")
    if not h or h.Health <= 0 then return false end
    local total, invis = 0, 0
    for _, part in pairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            total = total + 1
            if part.Transparency >= 0.9 or part.LocalTransparencyModifier >= 0.9 then invis = invis + 1 end
        end
    end
    return total > 0 and invis / total >= 0.8
end
local function UpdateInvisibleESP()
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local invis = IsCharacterInvisible(player)
            local existing = InvisibleHighlights[player]
            if invis then
                if not existing or not existing.Parent then
                    local h = Instance.new("Highlight")
                    h.FillColor = Color3.fromRGB(255,255,255) h.FillTransparency = 0.6
                    h.OutlineColor = Color3.fromRGB(255,255,255) h.OutlineTransparency = 0
                    h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                    h.Adornee = player.Character h.Parent = player.Character
                    InvisibleHighlights[player] = h
                end
            else
                if existing then existing:Destroy() InvisibleHighlights[player] = nil end
            end
        end
    end
end
ClearAllInvisibleESP = function()
    for _, h in pairs(InvisibleHighlights) do if h then h:Destroy() end end
    InvisibleHighlights = {}
end
local function CreateESP(player)
    if ESPHighlights[player] then ESPHighlights[player]:Destroy() ESPHighlights[player] = nil end
    if Settings.SeeInvisibles and IsCharacterInvisible(player) then return end
    local role = GetPlayerRole(player)
    if role == "Lobby" then return end
    local character = player.Character
    if not character then return end
    local color = GetRoleColor(role)
    if IsHero(player) then color = GetRoleColor("Hero") end
    local h = Instance.new("Highlight")
    h.FillColor = color h.FillTransparency = 0.7
    h.OutlineColor = color h.OutlineTransparency = 0
    h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    h.Adornee = character h.Parent = character
    ESPHighlights[player] = h
end
ClearAllESP = function()
    for _, h in pairs(ESPHighlights) do if h then h:Destroy() end end
    ESPHighlights = {}
end
local function CreateNameTag(player)
    if NameTagGuis[player] then NameTagGuis[player]:Destroy() end
    local character = player.Character
    if not character then return end
    local root = character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local b = Instance.new("BillboardGui")
    b.Size = UDim2.new(0, 200, 0, 50) b.StudsOffset = Vector3.new(0, 3.5, 0)
    b.AlwaysOnTop = true b.MaxDistance = 300 b.Adornee = root b.Parent = root
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, 0, 0, 18) nameLabel.BackgroundTransparency = 1
    nameLabel.Text = player.Name nameLabel.TextColor3 = Color3.fromRGB(255,255,255)
    nameLabel.TextStrokeTransparency = 0 nameLabel.TextStrokeColor3 = Color3.fromRGB(0,0,0)
    nameLabel.Font = Enum.Font.GothamBold nameLabel.TextSize = 14 nameLabel.Parent = b
    local role = GetPlayerRole(player)
    local roleColor = GetRoleColor(role)
    local roleText = role
    if IsHero(player) then roleText = "Hero" roleColor = GetRoleColor("Hero") end
    local roleLabel = Instance.new("TextLabel")
    roleLabel.Name = "RoleLabel" roleLabel.Size = UDim2.new(1, 0, 0, 14)
    roleLabel.Position = UDim2.new(0, 0, 0, 17) roleLabel.BackgroundTransparency = 1
    roleLabel.Text = roleText roleLabel.TextColor3 = roleColor
    roleLabel.TextStrokeTransparency = 0 roleLabel.TextStrokeColor3 = Color3.fromRGB(0,0,0)
    roleLabel.Font = Enum.Font.GothamSemibold roleLabel.TextSize = 12 roleLabel.Parent = b
    local invisLabel = Instance.new("TextLabel")
    invisLabel.Name = "InvisLabel" invisLabel.Size = UDim2.new(1, 0, 0, 14)
    invisLabel.Position = UDim2.new(0, 0, 0, 31) invisLabel.BackgroundTransparency = 1
    invisLabel.Text = "Invisible" invisLabel.TextColor3 = Color3.fromRGB(255,255,255)
    invisLabel.TextStrokeTransparency = 0 invisLabel.TextStrokeColor3 = Color3.fromRGB(0,0,0)
    invisLabel.Font = Enum.Font.GothamBold invisLabel.TextSize = 12 invisLabel.Visible = false invisLabel.Parent = b
    NameTagGuis[player] = b
end
ClearAllNameTags = function()
    for _, g in pairs(NameTagGuis) do if g then g:Destroy() end end
    NameTagGuis = {}
end
UpdateAllVisuals = function()
    ClearAllESP() ClearAllNameTags()
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            if Settings.PlayerESP then CreateESP(player) end
            if Settings.NameTags then CreateNameTag(player) end
        end
    end
end
local lastRoleCheck = 0
RunService.Heartbeat:Connect(function()
    if not Settings.PlayerESP and not Settings.NameTags and not Settings.SeeInvisibles then return end
    local now = tick()
    if now - lastRoleCheck < 0.1 then return end
    lastRoleCheck = now
    if Settings.SeeInvisibles then UpdateInvisibleESP() end
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local role = GetPlayerRole(player)
            local hero = IsHero(player)
            local invisible = Settings.SeeInvisibles and IsCharacterInvisible(player)
            if Settings.PlayerESP then
                local existing = ESPHighlights[player]
                if (role == "Lobby") and not invisible then
                    if existing then existing:Destroy() ESPHighlights[player] = nil end
                elseif invisible then
                    if existing then existing:Destroy() ESPHighlights[player] = nil end
                else
                    local color = hero and GetRoleColor("Hero") or GetRoleColor(role)
                    if existing then
                        if existing.FillColor ~= color then existing.FillColor = color existing.OutlineColor = color end
                    else CreateESP(player) end
                end
            end
            if Settings.NameTags then
                local gui = NameTagGuis[player]
                if not gui or not gui.Parent then CreateNameTag(player) gui = NameTagGuis[player] end
                if gui then
                    local roleLabel = gui:FindFirstChild("RoleLabel")
                    local invisLabel = gui:FindFirstChild("InvisLabel")
                    if roleLabel then
                        local roleText = hero and "Hero" or role
                        local roleColor = hero and GetRoleColor("Hero") or GetRoleColor(role)
                        if roleLabel.Text ~= roleText then roleLabel.Text = roleText end
                        if roleLabel.TextColor3 ~= roleColor then roleLabel.TextColor3 = roleColor end
                    end
                    if invisLabel then invisLabel.Visible = invisible end
                end
            end
        end
    end
end)
local function OnCharacterAdded(player, character)
    task.wait(0.2)
    if player ~= LocalPlayer then
        if Settings.PlayerESP then CreateESP(player) end
        if Settings.NameTags then CreateNameTag(player) end
    end
end
for _, player in pairs(Players:GetPlayers()) do
    player.CharacterAdded:Connect(function(c) OnCharacterAdded(player, c) end)
end
Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function(c) OnCharacterAdded(player, c) end)
end)

local NotifiedPlayers = { Murderer = {}, Sheriff = {} }
RunService.Heartbeat:Connect(function()
    if not Settings.MurderNotification and not Settings.SheriffNotification then return end
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local role = GetPlayerRole(player)
            if Settings.MurderNotification and role == "Murderer" and not NotifiedPlayers.Murderer[player] then
                NotifiedPlayers.Murderer[player] = true
                ShowNotification("MURDERER FOUND", player.Name, Color3.fromRGB(230, 40, 40))
            end
            if Settings.SheriffNotification and role == "Sheriff" and not NotifiedPlayers.Sheriff[player] then
                NotifiedPlayers.Sheriff[player] = true
                ShowNotification("SHERIFF FOUND", player.Name, Color3.fromRGB(40, 120, 255))
            end
        end
    end
end)
if GameplayRemotes then
    local RoundEndFadeReset = GameplayRemotes:FindFirstChild("RoundEndFade")
    if RoundEndFadeReset then
        RoundEndFadeReset.OnClientEvent:Connect(function()
            NotifiedPlayers.Murderer = {} NotifiedPlayers.Sheriff = {}
        end)
    end
end

local Skyboxes = {
    Day = {SkyboxBk="rbxassetid://159454299",SkyboxDn="rbxassetid://159454296",SkyboxFt="rbxassetid://159454293",SkyboxLf="rbxassetid://159454286",SkyboxRt="rbxassetid://159454300",SkyboxUp="rbxassetid://159454288",Brightness=2,ClockTime=14,Ambient=Color3.fromRGB(130,130,130),OutdoorAmbient=Color3.fromRGB(128,128,128),FogEnd=100000,FogColor=Color3.fromRGB(200,200,200)},
    Night = {SkyboxBk="rbxassetid://12064107",SkyboxDn="rbxassetid://12064152",SkyboxFt="rbxassetid://12064121",SkyboxLf="rbxassetid://12063984",SkyboxRt="rbxassetid://12064115",SkyboxUp="rbxassetid://12064130",Brightness=1,ClockTime=0,Ambient=Color3.fromRGB(30,30,50),OutdoorAmbient=Color3.fromRGB(25,25,40),FogEnd=500,FogColor=Color3.fromRGB(20,20,40)},
    Evening = {SkyboxBk="rbxassetid://271042516",SkyboxDn="rbxassetid://271077243",SkyboxFt="rbxassetid://271042556",SkyboxLf="rbxassetid://271042310",SkyboxRt="rbxassetid://271042467",SkyboxUp="rbxassetid://271077958",Brightness=1.5,ClockTime=18,Ambient=Color3.fromRGB(100,80,80),OutdoorAmbient=Color3.fromRGB(90,70,70),FogEnd=1000,FogColor=Color3.fromRGB(150,100,80)},
    Sunset = {SkyboxBk="rbxassetid://105092364",SkyboxDn="rbxassetid://105092385",SkyboxFt="rbxassetid://105092306",SkyboxLf="rbxassetid://105092413",SkyboxRt="rbxassetid://105092351",SkyboxUp="rbxassetid://105092442",Brightness=2,ClockTime=17,Ambient=Color3.fromRGB(180,120,80),OutdoorAmbient=Color3.fromRGB(160,100,60),FogEnd=2000,FogColor=Color3.fromRGB(255,140,80)},
    Anime = {SkyboxBk="rbxassetid://6444884337",SkyboxDn="rbxassetid://6444884951",SkyboxFt="rbxassetid://6444884415",SkyboxLf="rbxassetid://6444883914",SkyboxRt="rbxassetid://6444883684",SkyboxUp="rbxassetid://6444885256",Brightness=3,ClockTime=12,Ambient=Color3.fromRGB(200,200,255),OutdoorAmbient=Color3.fromRGB(180,180,255),FogEnd=5000,FogColor=Color3.fromRGB(220,220,255)},
}
local CurrentSky, SavedLighting = nil, nil
local function SaveLighting()
    if SavedLighting then return end
    SavedLighting = {Brightness=Lighting.Brightness,ClockTime=Lighting.ClockTime,Ambient=Lighting.Ambient,OutdoorAmbient=Lighting.OutdoorAmbient,FogEnd=Lighting.FogEnd,FogColor=Lighting.FogColor,EnvironmentDiffuseScale=Lighting.EnvironmentDiffuseScale,EnvironmentSpecularScale=Lighting.EnvironmentSpecularScale}
end
ApplySkybox = function(name)
    local d = Skyboxes[name]
    if not d then return end
    SaveLighting()
    if CurrentSky then CurrentSky:Destroy() end
    CurrentSky = Instance.new("Sky")
    CurrentSky.SkyboxBk = d.SkyboxBk CurrentSky.SkyboxDn = d.SkyboxDn CurrentSky.SkyboxFt = d.SkyboxFt
    CurrentSky.SkyboxLf = d.SkyboxLf CurrentSky.SkyboxRt = d.SkyboxRt CurrentSky.SkyboxUp = d.SkyboxUp
    CurrentSky.Parent = Lighting
    Lighting.Brightness = d.Brightness Lighting.ClockTime = d.ClockTime
    Lighting.Ambient = d.Ambient Lighting.OutdoorAmbient = d.OutdoorAmbient
    Lighting.FogEnd = d.FogEnd Lighting.FogColor = d.FogColor
end
RemoveSkybox = function()
    if CurrentSky then CurrentSky:Destroy() CurrentSky = nil end
    if SavedLighting then
        Lighting.Brightness = SavedLighting.Brightness
        Lighting.ClockTime = SavedLighting.ClockTime
        Lighting.Ambient = SavedLighting.Ambient
        Lighting.OutdoorAmbient = SavedLighting.OutdoorAmbient
        Lighting.FogEnd = SavedLighting.FogEnd
        Lighting.FogColor = SavedLighting.FogColor
        Lighting.EnvironmentDiffuseScale = SavedLighting.EnvironmentDiffuseScale or 1
        Lighting.EnvironmentSpecularScale = SavedLighting.EnvironmentSpecularScale or 1
        SavedLighting = nil
    end
end

local ShaderDOF = Instance.new("DepthOfFieldEffect")
ShaderDOF.FocusDistance = 5 ShaderDOF.InFocusRadius = 20 ShaderDOF.NearIntensity = 0 ShaderDOF.FarIntensity = 0 ShaderDOF.Parent = Lighting
local UltraBloom = Instance.new("BloomEffect")
UltraBloom.Intensity = 0 UltraBloom.Size = 24 UltraBloom.Threshold = 0.9 UltraBloom.Parent = Lighting
local UltraCC = Instance.new("ColorCorrectionEffect")
UltraCC.Brightness = 0 UltraCC.Contrast = 0 UltraCC.Saturation = 0 UltraCC.TintColor = Color3.fromRGB(255,255,255) UltraCC.Parent = Lighting
local UltraSun = Instance.new("SunRaysEffect")
UltraSun.Intensity = 0 UltraSun.Spread = 1 UltraSun.Parent = Lighting
local UltraAtmo = Instance.new("Atmosphere")
UltraAtmo.Density = 0 UltraAtmo.Offset = 0 UltraAtmo.Color = Color3.fromRGB(199,199,199)
UltraAtmo.Decay = Color3.fromRGB(106,112,125) UltraAtmo.Glare = 0 UltraAtmo.Haze = 0 UltraAtmo.Parent = Lighting

local function ApplyBlurShader(enabled)
    if enabled then
        TweenService:Create(ShaderDOF, TweenInfo.new(0.4), {FarIntensity = 1}):Play()
        TweenService:Create(UltraBloom, TweenInfo.new(0.4), {Intensity = 0}):Play()
        TweenService:Create(UltraCC, TweenInfo.new(0.4), {Saturation = 0, Contrast = 0, Brightness = 0}):Play()
        TweenService:Create(UltraSun, TweenInfo.new(0.4), {Intensity = 0}):Play()
        TweenService:Create(UltraAtmo, TweenInfo.new(0.4), {Density = 0, Haze = 0}):Play()
    else
        TweenService:Create(ShaderDOF, TweenInfo.new(0.4), {FarIntensity = 0}):Play()
    end
end
local function ApplyUltraRealismShader(enabled)
    if enabled then
        ShaderDOF.FocusDistance = 12 ShaderDOF.InFocusRadius = 40 ShaderDOF.NearIntensity = 0.15
        TweenService:Create(ShaderDOF, TweenInfo.new(0.6), {FarIntensity = 0.7}):Play()
        TweenService:Create(UltraBloom, TweenInfo.new(0.6), {Intensity = 0.6, Size = 28, Threshold = 0.85}):Play()
        TweenService:Create(UltraCC, TweenInfo.new(0.6), {Brightness = 0.05, Contrast = 0.15, Saturation = 0.25, TintColor = Color3.fromRGB(255,250,245)}):Play()
        TweenService:Create(UltraSun, TweenInfo.new(0.6), {Intensity = 0.12, Spread = 0.9}):Play()
        TweenService:Create(UltraAtmo, TweenInfo.new(0.6), {Density = 0.35, Haze = 1.5, Glare = 0.15, Color = Color3.fromRGB(190,195,205), Decay = Color3.fromRGB(115,120,135)}):Play()
        if not SavedLighting then
            SaveLighting()
            Lighting.OutdoorAmbient = Color3.fromRGB(80,85,95)
            Lighting.Ambient = Color3.fromRGB(70,75,85)
            Lighting.Brightness = 3
            Lighting.EnvironmentDiffuseScale = 0.6
            Lighting.EnvironmentSpecularScale = 0.8
        end
    else
        TweenService:Create(ShaderDOF, TweenInfo.new(0.6), {FarIntensity = 0, NearIntensity = 0}):Play()
        TweenService:Create(UltraBloom, TweenInfo.new(0.6), {Intensity = 0}):Play()
        TweenService:Create(UltraCC, TweenInfo.new(0.6), {Brightness = 0, Contrast = 0, Saturation = 0, TintColor = Color3.fromRGB(255,255,255)}):Play()
        TweenService:Create(UltraSun, TweenInfo.new(0.6), {Intensity = 0}):Play()
        TweenService:Create(UltraAtmo, TweenInfo.new(0.6), {Density = 0, Haze = 0, Glare = 0}):Play()
        if SavedLighting then
            Lighting.OutdoorAmbient = SavedLighting.OutdoorAmbient
            Lighting.Ambient = SavedLighting.Ambient
            Lighting.Brightness = SavedLighting.Brightness
            Lighting.EnvironmentDiffuseScale = SavedLighting.EnvironmentDiffuseScale or 1
            Lighting.EnvironmentSpecularScale = SavedLighting.EnvironmentSpecularScale or 1
            SavedLighting = nil
        end
    end
end
local ShaderModeName = "None"
local function SetShaderMode(mode)
    if ShaderModeName == mode then return end
    ShaderModeName = mode
    if mode == "None" then ApplyBlurShader(false) ApplyUltraRealismShader(false)
    elseif mode == "Blur" then ApplyUltraRealismShader(false) ApplyBlurShader(true)
    elseif mode == "Ultra" then ApplyBlurShader(false) ApplyUltraRealismShader(true) end
end
ToggleShaders = function(enabled)
    Settings.Shaders = enabled
    if enabled then
        if ShaderModeName == "None" then SetShaderMode("Blur") else SetShaderMode(ShaderModeName) end
    else SetShaderMode("None") end
end
SetShaderModeByNumber = function(num)
    if num == 1 then
        if ShaderModeName ~= "None" then SetShaderMode("Blur") else ShaderModeName = "Blur" end
    elseif num == 2 then
        if ShaderModeName ~= "None" then SetShaderMode("Ultra") else ShaderModeName = "Ultra" end
    end
end

local ParticleParts, ParticleConnection = {}, nil
local PARTICLE_COUNT = 60
local function CreateSnowflake()
    local p = Instance.new("Part")
    p.Size = Vector3.new(0.25,0.25,0.25) p.Shape = Enum.PartType.Ball p.Material = Enum.Material.Neon
    p.Color = Color3.fromRGB(220,240,255) p.Transparency = 0.2 p.Anchored = true
    p.CanCollide = false p.CanQuery = false p.CanTouch = false p.CastShadow = false p.Locked = true p.Parent = workspace
    local l = Instance.new("PointLight") l.Color = Color3.fromRGB(220,240,255) l.Range = 3 l.Brightness = 1 l.Parent = p
    return p
end
local function GetRandomParticlePosition()
    local char = LocalPlayer.Character
    local cp = Vector3.new(0,50,0)
    if char and char:FindFirstChild("HumanoidRootPart") then cp = char.HumanoidRootPart.Position end
    local a = math.random()*math.pi*2 local d = math.random(150,600)/10
    return cp + Vector3.new(math.cos(a)*d, math.random(-40,40), math.sin(a)*d)
end
local function ClearParticles()
    for _, p in pairs(ParticleParts) do if p and p.Parent then p:Destroy() end end
    ParticleParts = {}
    if ParticleConnection then ParticleConnection:Disconnect() ParticleConnection = nil end
end
local function SpawnParticles()
    ClearParticles()
    for i = 1, PARTICLE_COUNT do
        local s = CreateSnowflake() s.Position = GetRandomParticlePosition() table.insert(ParticleParts, s)
    end
end
local function StartParticleAnimation()
    if ParticleConnection then ParticleConnection:Disconnect() ParticleConnection = nil end
    local pd = {}
    for i, p in ipairs(ParticleParts) do
        pd[p] = {basePos=p.Position,phaseX=math.random()*math.pi*2,phaseY=math.random()*math.pi*2,phaseZ=math.random()*math.pi*2,speedX=math.random(5,15)/10,speedY=math.random(8,20)/10,speedZ=math.random(5,15)/10,ampX=math.random(15,40)/10,ampY=math.random(20,50)/10,ampZ=math.random(15,40)/10,rotSpeed=math.random(-30,30)/10}
    end
    local t0 = tick()
    ParticleConnection = RunService.Heartbeat:Connect(function()
        if not Settings.Particles then return end
        local e = tick() - t0
        local char = LocalPlayer.Character
        if not char or not char:FindFirstChild("HumanoidRootPart") then return end
        local pp = char.HumanoidRootPart.Position
        for i, p in ipairs(ParticleParts) do
            if not p or not p.Parent then continue end
            local d = pd[p]
            if not d then continue end
            local ox = math.sin(e*d.speedX+d.phaseX)*d.ampX
            local oy = math.cos(e*d.speedY+d.phaseY)*d.ampY
            local oz = math.sin(e*d.speedZ+d.phaseZ)*d.ampZ
            local tp = d.basePos + Vector3.new(ox,oy,oz)
            if (tp-pp).Magnitude > 120 then
                d.basePos = GetRandomParticlePosition()
                d.phaseX = math.random()*math.pi*2 d.phaseY = math.random()*math.pi*2 d.phaseZ = math.random()*math.pi*2
                tp = d.basePos
            end
            p.Position = tp
            p.CFrame = CFrame.new(p.Position) * CFrame.Angles(e*d.rotSpeed, e*d.rotSpeed*0.7, e*d.rotSpeed*0.5)
            local l = p:FindFirstChildOfClass("PointLight")
            if l then l.Brightness = 0.8 + math.sin(e*2+d.phaseX)*0.4 end
        end
    end)
end
ToggleParticles = function(enabled)
    Settings.Particles = enabled
    if enabled then SpawnParticles() StartParticleAnimation() else ClearParticles() end
end

local TracerLines = {}
local TracerConnection = nil
local function ClearAllTracers()
    for _, line in pairs(TracerLines) do if line then pcall(function() line:Remove() end) end end
    TracerLines = {}
end
local function StartTracers()
    if TracerConnection then TracerConnection:Disconnect() TracerConnection = nil end
    TracerConnection = RunService.RenderStepped:Connect(function()
        if not Settings.Tracers then return end
        if GetPlayerRole(LocalPlayer) == "Lobby" then
            for player, line in pairs(TracerLines) do
                if line then pcall(function() line:Remove() end) end
                TracerLines[player] = nil
            end
            return
        end
        local localChar = LocalPlayer.Character
        if not localChar then return end
        local localRoot = localChar:FindFirstChild("HumanoidRootPart")
        if not localRoot then return end
        local originX = Camera.ViewportSize.X / 2
        local originY = Camera.ViewportSize.Y - 10
        local activePlayers = {}
        for _, player in pairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character then
                local role = GetPlayerRole(player)
                if role ~= "Lobby" then
                    local char = player.Character
                    local root = char:FindFirstChild("HumanoidRootPart")
                    local humanoid = char:FindFirstChildOfClass("Humanoid")
                    if root and humanoid and humanoid.Health > 0 then
                        local camToPlayer = root.Position - Camera.CFrame.Position
                        local dot = camToPlayer:Dot(Camera.CFrame.LookVector)
                        if dot > 0 then
                            local screenPos, onScreen = Camera:WorldToViewportPoint(root.Position)
                            if onScreen then
                                activePlayers[player] = true
                                local line = TracerLines[player]
                                if not line then
                                    line = Drawing.new("Line")
                                    line.Thickness = 1.5 line.Transparency = 0.9
                                    TracerLines[player] = line
                                end
                                local color = GetRoleColor(role)
                                if IsHero(player) then color = GetRoleColor("Hero") end
                                line.Color = color
                                line.From = Vector2.new(originX, originY)
                                line.To = Vector2.new(screenPos.X, screenPos.Y)
                                line.Visible = true
                            end
                        end
                    end
                end
            end
        end
        for player, line in pairs(TracerLines) do
            if not activePlayers[player] then
                if line then pcall(function() line:Remove() end) end
                TracerLines[player] = nil
            end
        end
    end)
end
ToggleTracers = function(enabled)
    Settings.Tracers = enabled
    if enabled then StartTracers()
    else
        if TracerConnection then TracerConnection:Disconnect() TracerConnection = nil end
        ClearAllTracers()
    end
end

local GunLooterConnection = nil
local LastLootTime = 0
local LOOT_COOLDOWN = 0.15
local CachedGunDrops = {}
local LastCacheUpdate = 0
local CACHE_UPDATE_INTERVAL = 0.5
local function IsGunDrop(obj)
    if not obj then return false end
    if not (obj:IsA("Model") or obj:IsA("BasePart") or obj:IsA("Tool")) then return false end
    local name = obj.Name:lower()
    if name == "gundrop" or name:find("gundrop") then return true end
    if name == "knifedrop" or name:find("knifedrop") then return true end
    if name == "droppedgun" or name == "dropped_gun" then return true end
    return false
end
local function IsMineOrInHands(obj, myChar)
    if myChar and obj:IsDescendantOf(myChar) then return true end
    for _, plr in pairs(Players:GetPlayers()) do
        if plr.Character and obj:IsDescendantOf(plr.Character) then return true end
        local bp = plr:FindFirstChild("Backpack")
        if bp and obj:IsDescendantOf(bp) then return true end
    end
    return false
end
local function UpdateGunDropCache()
    local myChar = LocalPlayer.Character
    local newCache = {} local seen = {}
    for _, obj in pairs(workspace:GetChildren()) do
        if IsGunDrop(obj) and not seen[obj] then
            seen[obj] = true
            if not IsMineOrInHands(obj, myChar) then table.insert(newCache, obj) end
        end
    end
    local foldersToCheck = {"DroppedItems","Items","Drops","Weapons","Objects","Map","ItemsFolder","ToolDrops"}
    for _, folderName in ipairs(foldersToCheck) do
        local folder = workspace:FindFirstChild(folderName)
        if folder then
            for _, obj in pairs(folder:GetDescendants()) do
                if IsGunDrop(obj) and not seen[obj] then
                    seen[obj] = true
                    if not IsMineOrInHands(obj, myChar) then table.insert(newCache, obj) end
                end
            end
        end
    end
    for _, child in pairs(workspace:GetChildren()) do
        if child:IsA("Folder") or child:IsA("Model") then
            for _, obj in pairs(child:GetChildren()) do
                if IsGunDrop(obj) and not seen[obj] then
                    seen[obj] = true
                    if not IsMineOrInHands(obj, myChar) then table.insert(newCache, obj) end
                end
            end
        end
    end
    CachedGunDrops = newCache LastCacheUpdate = tick()
end
local function TeleportGunToMe(gunDrop, myRoot)
    if not gunDrop or not myRoot then return false end
    local targetCFrame = CFrame.new(myRoot.Position + Vector3.new(0, -2.5, 0))
    local moved = false
    if gunDrop:IsA("Model") then
        for _, part in pairs(gunDrop:GetDescendants()) do
            if part:IsA("BasePart") then
                if part.Anchored then pcall(function() part.Anchored = false end) end
                if part.CanCollide then pcall(function() part.CanCollide = false end) end
            end
        end
        pcall(function() gunDrop:PivotTo(targetCFrame) moved = true end)
    elseif gunDrop:IsA("BasePart") then
        if gunDrop.Anchored then pcall(function() gunDrop.Anchored = false end) end
        local ok = pcall(function() gunDrop.CFrame = targetCFrame gunDrop.Velocity = Vector3.zero end)
        if ok then moved = true end
    end
    return moved
end
local function FindNearestGunFromCache()
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return nil end
    local myPos = char.HumanoidRootPart.Position
    local nearest, nearestDist = nil, math.huge
    for _, obj in ipairs(CachedGunDrops) do
        if obj and obj.Parent then
            local pos = nil
            if obj:IsA("Model") then
                local primary = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
                if primary then pos = primary.Position end
            elseif obj:IsA("BasePart") then pos = obj.Position
            elseif obj:IsA("Tool") then
                local h = obj:FindFirstChild("Handle")
                if h and h:IsA("BasePart") then pos = h.Position end
            end
            if pos then
                local dist = (pos - myPos).Magnitude
                if dist < nearestDist then nearestDist = dist nearest = obj end
            end
        end
    end
    return nearest
end
ToggleAutoGunLooter = function(enabled)
    Settings.AutoGunLooter = enabled
    if enabled then
        UpdateGunDropCache()
        GunLooterConnection = RunService.Heartbeat:Connect(function()
            if not Settings.AutoGunLooter then return end
            local now = tick()
            if now - LastLootTime < LOOT_COOLDOWN then return end
            local char = LocalPlayer.Character
            if not char then return end
            if char:FindFirstChildOfClass("Tool") then return end
            local myRoot = char:FindFirstChild("HumanoidRootPart")
            if not myRoot then return end
            if now - LastCacheUpdate > CACHE_UPDATE_INTERVAL then UpdateGunDropCache() end
            local gun = FindNearestGunFromCache()
            if gun then LastLootTime = now TeleportGunToMe(gun, myRoot) end
        end)
    else
        if GunLooterConnection then GunLooterConnection:Disconnect() GunLooterConnection = nil end
        CachedGunDrops = {}
    end
end

local KillAllRunning = false
local function GetKnifeTool(char)
    for _, tool in pairs(char:GetChildren()) do
        if tool:IsA("Tool") then
            local n = tool.Name:lower()
            if n:find("knife") or n:find("sword") or n:find("blade") or n:find("dagger") then return tool end
        end
    end
    return nil
end
local function RunKillAll()
    if KillAllRunning then return end
    KillAllRunning = true
    pcall(function()
        local char = LocalPlayer.Character
        if not char then return end
        local myRoot = char:FindFirstChild("HumanoidRootPart")
        if not myRoot then return end
        local orig = myRoot.CFrame
        local knife = GetKnifeTool(char)
        if not knife then return end
        for _, player in pairs(Players:GetPlayers()) do
            if not Settings.KillAll then break end
            if player ~= LocalPlayer then
                local info = PlayerData[player.Name]
                if info and type(info) == "table" and info.Dead ~= true and info.Role and info.Role ~= "" then
                    local tChar = player.Character
                    if tChar then
                        local h = tChar:FindFirstChildOfClass("Humanoid")
                        local root = tChar:FindFirstChild("HumanoidRootPart")
                        if h and root and h.Health > 0 then
                            myRoot.CFrame = root.CFrame + Vector3.new(0, 3, 0)
                            task.wait(0.08)
                            myRoot.CFrame = CFrame.lookAt(myRoot.Position, root.Position)
                            pcall(function() knife:Activate() end)
                            task.wait(0.15)
                        end
                    end
                end
            end
        end
        if myRoot and myRoot.Parent then myRoot.CFrame = orig end
    end)
    KillAllRunning = false
end
ToggleKillAll = function(enabled)
    Settings.KillAll = enabled
    if enabled then
        task.spawn(function()
            while Settings.KillAll do RunKillAll() task.wait(1) end
        end)
    end
end

local FlyBV, FlyBG, FlyConnection = nil, nil, nil
ToggleFly = function(enabled)
    Settings.Fly = enabled
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChild("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    if not hum or not root then return end
    if enabled then
        hum.PlatformStand = true hum:ChangeState(Enum.HumanoidStateType.Physics)
        FlyBV = Instance.new("BodyVelocity") FlyBV.MaxForce = Vector3.new(1e5,1e5,1e5) FlyBV.P = 1250 FlyBV.Velocity = Vector3.zero FlyBV.Parent = root
        FlyBG = Instance.new("BodyGyro") FlyBG.MaxTorque = Vector3.new(1e6,1e6,1e6) FlyBG.P = 3000 FlyBG.D = 500 FlyBG.CFrame = root.CFrame FlyBG.Parent = root
        FlyConnection = RunService.RenderStepped:Connect(function()
            if not Settings.Fly or not root or not root.Parent or not FlyBV or not FlyBG then return end
            local v = Vector3.zero
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then v += Vector3.new(0,50,0) end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then v += Vector3.new(0,-50,0) end
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then v += Camera.CFrame.LookVector*50 end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then v -= Camera.CFrame.LookVector*50 end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then v -= Camera.CFrame.RightVector*50 end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then v += Camera.CFrame.RightVector*50 end
            FlyBV.Velocity = v
            local ld = Camera.CFrame.LookVector local fl = Vector3.new(ld.X,0,ld.Z)
            if fl.Magnitude > 0.01 then FlyBG.CFrame = CFrame.lookAt(root.Position, root.Position+fl.Unit) end
            root.AssemblyAngularVelocity = Vector3.zero root.RotVelocity = Vector3.zero
        end)
    else
        if FlyConnection then FlyConnection:Disconnect() FlyConnection = nil end
        if FlyBV then FlyBV:Destroy() FlyBV = nil end
        if FlyBG then FlyBG:Destroy() FlyBG = nil end
        if hum then hum.PlatformStand = false hum:ChangeState(Enum.HumanoidStateType.GettingUp) end
    end
end

local NoClipConnection = nil
ToggleNoClip = function(enabled)
    Settings.NoClip = enabled
    if enabled then
        NoClipConnection = RunService.Stepped:Connect(function()
            if not Settings.NoClip then return end
            local char = LocalPlayer.Character
            if not char then return end
            for _, part in pairs(char:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide then part.CanCollide = false end
            end
        end)
    else
        if NoClipConnection then NoClipConnection:Disconnect() NoClipConnection = nil end
        local char = LocalPlayer.Character
        if char then
            for _, part in pairs(char:GetDescendants()) do
                if part:IsA("BasePart") then part.CanCollide = true end
            end
        end
    end
end

ToggleLockMouse = function(enabled)
    Settings.LockMouse = enabled
    UserInputService.MouseBehavior = enabled and Enum.MouseBehavior.LockCenter or Enum.MouseBehavior.Default
end

local AimBotConnection
local FOVCircle = Drawing.new("Circle")
FOVCircle.Thickness = 2 FOVCircle.Radius = 100 FOVCircle.Color = Color3.fromRGB(150,100,255)
FOVCircle.Transparency = 0.8 FOVCircle.Visible = false FOVCircle.Filled = false

local function IsVisibleCheck(targetPart)
    if not Settings.AimBotWallCheck then return true end
    local origin = Camera.CFrame.Position
    local dir = (targetPart.Position - origin)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {LocalPlayer.Character, targetPart.Parent}
    return workspace:Raycast(origin, dir, params) == nil
end

ToggleAimBot = function(enabled)
    Settings.AimBot = enabled
    FOVCircle.Visible = enabled FOVCircle.Radius = Settings.AimBotFOV
    if enabled then
        AimBotConnection = RunService.RenderStepped:Connect(function()
            if not Settings.AimBot then return end
            local target, closest = nil, Settings.AimBotFOV
            for _, player in pairs(Players:GetPlayers()) do
                if player ~= LocalPlayer and player.Character then
                    local h = player.Character:FindFirstChildOfClass("Humanoid")
                    local rp = player.Character:FindFirstChild("HumanoidRootPart")
                    if h and rp and h.Health > 0 then
                        local skip = false
                        if Settings.AimBotOnlyMurderer then
                            if GetPlayerRole(player) ~= "Murderer" then skip = true end
                        end
                        if not skip then
                            if IsVisibleCheck(rp) then
                                local sp, onScreen = Camera:WorldToScreenPoint(rp.Position)
                                if onScreen then
                                    local dd = (Vector2.new(sp.X,sp.Y) - Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)).Magnitude
                                    if dd < closest then closest = dd target = rp end
                                end
                            end
                        end
                    end
                end
            end
            if target then
                local pred = target.Velocity * (Settings.AimBotPrediction/100)
                Camera.CFrame = CFrame.lookAt(Camera.CFrame.Position, target.Position + pred)
            end
        end)
    else
        if AimBotConnection then AimBotConnection:Disconnect() AimBotConnection = nil end
    end
end

RunService.RenderStepped:Connect(function()
    if FOVCircle.Visible then
        FOVCircle.Position = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
    end
end)
local function BuildGUI()
    local C = {
        WindowBg        = Color3.fromRGB(21, 21, 24),
        WindowTransp    = 0.10,
        TopBarBg        = Color3.fromRGB(21, 21, 24),
        TopBarTransp    = 0.10,
        CardBg          = Color3.fromRGB(30, 30, 34),
        CardTransp      = 0.15,
        CardStroke      = Color3.fromRGB(42, 42, 48),
        CardStrokeTr    = 0.5,
        PillBg          = Color3.fromRGB(38, 38, 43),
        PillBgActive    = Color3.fromRGB(46, 46, 53),
        PillTransp      = 0.10,
        SearchBg        = Color3.fromRGB(30, 30, 34),
        SearchTransp    = 0.15,
        Text            = Color3.fromRGB(232, 232, 236),
        TextDim         = Color3.fromRGB(138, 138, 146),
        TextMuted       = Color3.fromRGB(100, 100, 108),
        TextSection     = Color3.fromRGB(120, 120, 128),
        Accent          = Color3.fromRGB(59, 130, 246),
        AccentDim       = Color3.fromRGB(45, 100, 200),
        ToggleOn        = Color3.fromRGB(59, 130, 246),
        ToggleOff       = Color3.fromRGB(58, 58, 64),
        ToggleKnob      = Color3.fromRGB(255, 255, 255),
        SliderFill      = Color3.fromRGB(59, 130, 246),
        SliderBg        = Color3.fromRGB(45, 45, 52),
        Divider         = Color3.fromRGB(42, 42, 48),
        OverlayBg       = Color3.fromRGB(21, 21, 24),
        GroupLabelPurple= Color3.fromRGB(140, 100, 220),
        GroupLabelBlue  = Color3.fromRGB(80, 130, 240),
        Danger          = Color3.fromRGB(220, 70, 70),
        Success         = Color3.fromRGB(70, 190, 110),
    }

    local function corner(parent, r)
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, r or 8)
        c.Parent = parent
        return c
    end
    local function stroke(parent, col, tr, th)
        local s = Instance.new("UIStroke")
        s.Color = col or C.CardStroke
        s.Thickness = th or 1
        s.Transparency = tr or 0.5
        s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        s.Parent = parent
        return s
    end

    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "GeloWare"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ScreenGui.IgnoreGuiInset = true
    ScreenGui.DisplayOrder = 999
    ScreenGui.Parent = game.CoreGui

    local NotifContainer = Instance.new("Frame")
    NotifContainer.Size = UDim2.new(0, 280, 1, -40)
    NotifContainer.Position = UDim2.new(1, -300, 0, 20)
    NotifContainer.BackgroundTransparency = 1
    NotifContainer.Parent = ScreenGui
    local NotifList = Instance.new("UIListLayout")
    NotifList.SortOrder = Enum.SortOrder.LayoutOrder
    NotifList.VerticalAlignment = Enum.VerticalAlignment.Bottom
    NotifList.HorizontalAlignment = Enum.HorizontalAlignment.Right
    NotifList.Padding = UDim.new(0, 8)
    NotifList.Parent = NotifContainer

    ShowNotification = function(title, text, iconColor)
        local notif = Instance.new("Frame")
        notif.Size = UDim2.new(0, 280, 0, 60)
        notif.BackgroundColor3 = C.CardBg
        notif.BackgroundTransparency = 0.05
        notif.BorderSizePixel = 0
        notif.Position = UDim2.new(1, 380, 0, 0)
        notif.Parent = NotifContainer
        corner(notif, 10)
        stroke(notif, iconColor or C.Accent, 0.3, 1.2)

        local t = Instance.new("TextLabel")
        t.Size = UDim2.new(1, -20, 0, 16)
        t.Position = UDim2.new(0, 12, 0, 10)
        t.BackgroundTransparency = 1
        t.Text = title
        t.TextColor3 = C.Text
        t.Font = Enum.Font.GothamBold
        t.TextSize = 12
        t.TextXAlignment = Enum.TextXAlignment.Left
        t.Parent = notif

        local s = Instance.new("TextLabel")
        s.Size = UDim2.new(1, -20, 0, 16)
        s.Position = UDim2.new(0, 12, 0, 30)
        s.BackgroundTransparency = 1
        s.Text = text
        s.TextColor3 = iconColor or C.TextDim
        s.Font = Enum.Font.Gotham
        s.TextSize = 11
        s.TextXAlignment = Enum.TextXAlignment.Left
        s.Parent = notif

        TweenService:Create(notif, TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
            {Position = UDim2.new(1, -300, 0, 0)}):Play()

        task.delay(4, function()
            if notif and notif.Parent then
                local tw = TweenService:Create(notif, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.In),
                    {Position = UDim2.new(1, 380, 0, 0), BackgroundTransparency = 1})
                tw:Play()
                tw.Completed:Connect(function() notif:Destroy() end)
            end
        end)
    end

    local WINDOW_W, WINDOW_H = 620, 440

    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.Size = UDim2.new(0, WINDOW_W, 0, WINDOW_H)
    MainFrame.Position = UDim2.new(0.5, -WINDOW_W/2, 0.5, -WINDOW_H/2)
    MainFrame.BackgroundColor3 = C.WindowBg
    MainFrame.BackgroundTransparency = C.WindowTransp
    MainFrame.BorderSizePixel = 0
    MainFrame.Active = true
    MainFrame.Draggable = true
    MainFrame.Visible = false
    MainFrame.ClipsDescendants = true
    MainFrame.Parent = ScreenGui
    corner(MainFrame, 14)
    stroke(MainFrame, C.CardStroke, 0.4, 1)

    local TopBar = Instance.new("Frame")
    TopBar.Size = UDim2.new(1, 0, 0, 48)
    TopBar.Position = UDim2.new(0, 0, 0, 0)
    TopBar.BackgroundColor3 = C.TopBarBg
    TopBar.BackgroundTransparency = C.TopBarTransp
    TopBar.BorderSizePixel = 0
    TopBar.Parent = MainFrame
    corner(TopBar, 14)
    local TopBarMask = Instance.new("Frame")
    TopBarMask.Size = UDim2.new(1, 0, 0, 12)
    TopBarMask.Position = UDim2.new(0, 0, 1, -12)
    TopBarMask.BackgroundColor3 = C.TopBarBg
    TopBarMask.BackgroundTransparency = C.TopBarTransp
    TopBarMask.BorderSizePixel = 0
    TopBarMask.Parent = TopBar

    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(1, -200, 1, 0)
    Title.Position = UDim2.new(0, 18, 0, 0)
    Title.BackgroundTransparency = 1
    Title.Text = "GeloWare - MM2"
    Title.TextColor3 = C.Text
    Title.Font = Enum.Font.GothamBold
    Title.TextSize = 15
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.Parent = TopBar

    local IconSize = 26
    local function makeIconButton(xOffsetFromRight, glyph, cb)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(0, IconSize, 0, IconSize)
        b.Position = UDim2.new(1, xOffsetFromRight, 0.5, -IconSize/2)
        b.BackgroundColor3 = C.PillBg
        b.BackgroundTransparency = 1
        b.BorderSizePixel = 0
        b.Text = glyph
        b.TextColor3 = C.TextDim
        b.Font = Enum.Font.GothamBold
        b.TextSize = 13
        b.AutoButtonColor = false
        b.Parent = TopBar
        corner(b, 6)
        b.MouseEnter:Connect(function()
            TweenService:Create(b, TweenInfo.new(0.15), {
                BackgroundTransparency = 0.3,
                BackgroundColor3 = C.PillBg,
                TextColor3 = C.Text,
            }):Play()
        end)
        b.MouseLeave:Connect(function()
            TweenService:Create(b, TweenInfo.new(0.15), {
                BackgroundTransparency = 1,
                TextColor3 = C.TextDim,
            }):Play()
        end)
        if cb then b.MouseButton1Click:Connect(cb) end
        return b
    end

    local CloseBtn = makeIconButton(-14, "✕", function()
        if CloseGUI then CloseGUI() end
    end)
    CloseBtn.TextSize = 15
    CloseBtn.MouseEnter:Connect(function()
        TweenService:Create(CloseBtn, TweenInfo.new(0.15), {TextColor3 = C.Danger}):Play()
    end)
    CloseBtn.MouseLeave:Connect(function()
        TweenService:Create(CloseBtn, TweenInfo.new(0.15), {TextColor3 = C.TextDim}):Play()
    end)

    local SearchIconBtn = makeIconButton(-46, "🔍", nil)

    local SearchFrame = Instance.new("Frame")
    SearchFrame.Size = UDim2.new(0, 200, 0, 30)
    SearchFrame.Position = UDim2.new(0, 16, 0, 56)
    SearchFrame.BackgroundColor3 = C.SearchBg
    SearchFrame.BackgroundTransparency = C.SearchTransp
    SearchFrame.BorderSizePixel = 0
    SearchFrame.Visible = false
    SearchFrame.Parent = MainFrame
    corner(SearchFrame, 8)
    stroke(SearchFrame, C.CardStroke, 0.5, 1)

    local SearchBox = Instance.new("TextBox")
    SearchBox.Size = UDim2.new(1, -20, 1, 0)
    SearchBox.Position = UDim2.new(0, 10, 0, 0)
    SearchBox.BackgroundTransparency = 1
    SearchBox.Text = ""
    SearchBox.PlaceholderText = "Search..."
    SearchBox.PlaceholderColor3 = C.TextMuted
    SearchBox.TextColor3 = C.Text
    SearchBox.Font = Enum.Font.Gotham
    SearchBox.TextSize = 11
    SearchBox.TextXAlignment = Enum.TextXAlignment.Left
    SearchBox.ClearTextOnFocus = false
    SearchBox.Parent = SearchFrame

    SearchIconBtn.MouseButton1Click:Connect(function()
        SearchFrame.Visible = not SearchFrame.Visible
        if SearchFrame.Visible then
            SearchBox:CaptureFocus()
        end
    end)

    local CategoryBar = Instance.new("ScrollingFrame")
    CategoryBar.Size = UDim2.new(1, -32, 0, 36)
    CategoryBar.Position = UDim2.new(0, 16, 0, 56)
    CategoryBar.BackgroundTransparency = 1
    CategoryBar.BorderSizePixel = 0
    CategoryBar.ScrollBarThickness = 0
    CategoryBar.ScrollingDirection = Enum.ScrollingDirection.X
    CategoryBar.CanvasSize = UDim2.new(0, 0, 0, 0)
    CategoryBar.AutomaticCanvasSize = Enum.AutomaticSize.X
    CategoryBar.Parent = MainFrame

    local CategoryLayout = Instance.new("UIListLayout")
    CategoryLayout.FillDirection = Enum.FillDirection.Horizontal
    CategoryLayout.SortOrder = Enum.SortOrder.LayoutOrder
    CategoryLayout.Padding = UDim.new(0, 8)
    CategoryLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    CategoryLayout.Parent = CategoryBar

    local ContentFrame = Instance.new("Frame")
    ContentFrame.Size = UDim2.new(1, -32, 1, -160)
    ContentFrame.Position = UDim2.new(0, 16, 0, 104)
    ContentFrame.BackgroundTransparency = 1
    ContentFrame.Parent = MainFrame

    local ContentScroll = Instance.new("ScrollingFrame")
    ContentScroll.Size = UDim2.new(1, 0, 1, 0)
    ContentScroll.Position = UDim2.new(0, 0, 0, 0)
    ContentScroll.BackgroundTransparency = 1
    ContentScroll.BorderSizePixel = 0
    ContentScroll.ScrollBarThickness = 3
    ContentScroll.ScrollBarImageColor3 = C.CardStroke
    ContentScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    ContentScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    ContentScroll.Parent = ContentFrame

    local ContentPad = Instance.new("UIPadding")
    ContentPad.PaddingTop = UDim.new(0, 4)
    ContentPad.PaddingBottom = UDim.new(0, 8)
    ContentPad.PaddingLeft = UDim.new(0, 2)
    ContentPad.PaddingRight = UDim.new(0, 6)
    ContentPad.Parent = ContentScroll

    local Grid = Instance.new("UIGridLayout")
    Grid.CellSize = UDim2.new(0, 180, 0, 56)
    Grid.CellPadding = UDim2.new(0, 10, 0, 10)
    Grid.SortOrder = Enum.SortOrder.LayoutOrder
    Grid.HorizontalAlignment = Enum.HorizontalAlignment.Left
    Grid.Parent = ContentScroll

    local function CreateToggle(parent, defaultState, callback)
        local state = defaultState or false

        local wrap = Instance.new("TextButton")
        wrap.Size = UDim2.new(0, 40, 0, 22)
        wrap.BackgroundColor3 = state and C.ToggleOn or C.ToggleOff
        wrap.BackgroundTransparency = 0
        wrap.BorderSizePixel = 0
        wrap.Text = ""
        wrap.AutoButtonColor = false
        wrap.Parent = parent
        corner(wrap, 11)

        local knob = Instance.new("Frame")
        knob.Size = UDim2.new(0, 18, 0, 18)
        knob.Position = state and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9)
        knob.BackgroundColor3 = C.ToggleKnob
        knob.BorderSizePixel = 0
        knob.Parent = wrap
        corner(knob, 9)

        local function apply(instant)
            local info = TweenInfo.new(instant and 0 or 0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
            TweenService:Create(wrap, info, {BackgroundColor3 = state and C.ToggleOn or C.ToggleOff}):Play()
            TweenService:Create(knob, info, {Position = state and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9)}):Play()
        end
        apply(true)

        wrap.MouseButton1Click:Connect(function()
            state = not state
            apply(false)
            if callback then callback(state) end
            pcall(SaveState)
        end)
        return wrap
    end

    local function CreateSlider(parent, name, key, min, max, default, callback)
        local currentValue = tonumber(Settings[key])
        if currentValue == nil then currentValue = default end
        if currentValue < min then currentValue = min end
        if currentValue > max then currentValue = max end

        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, 38)
        row.BackgroundTransparency = 1
        row.Parent = parent

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -60, 0, 14)
        lbl.BackgroundTransparency = 1
        lbl.Text = name
        lbl.TextColor3 = C.Text
        lbl.Font = Enum.Font.GothamMedium
        lbl.TextSize = 11
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = row

        local valBox = Instance.new("TextLabel")
        valBox.Size = UDim2.new(0, 60, 0, 14)
        valBox.Position = UDim2.new(1, -60, 0, 0)
        valBox.BackgroundTransparency = 1
        valBox.Text = tostring(math.floor(currentValue))
        valBox.TextColor3 = C.TextDim
        valBox.Font = Enum.Font.Gotham
        valBox.TextSize = 11
        valBox.TextXAlignment = Enum.TextXAlignment.Right
        valBox.Parent = row

        local bar = Instance.new("TextButton")
        bar.Size = UDim2.new(1, 0, 0, 4)
        bar.Position = UDim2.new(0, 0, 0, 24)
        bar.BackgroundColor3 = C.SliderBg
        bar.BorderSizePixel = 0
        bar.Text = ""
        bar.AutoButtonColor = false
        bar.Parent = row
        corner(bar, 2)

        local fill = Instance.new("Frame")
        fill.Size = UDim2.new((currentValue - min) / (max - min), 0, 1, 0)
        fill.BackgroundColor3 = C.SliderFill
        fill.BorderSizePixel = 0
        fill.Parent = bar
        corner(fill, 2)

        local knob = Instance.new("Frame")
        knob.Size = UDim2.new(0, 10, 0, 10)
        knob.Position = UDim2.new((currentValue - min) / (max - min), -5, 0.5, -5)
        knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        knob.BorderSizePixel = 0
        knob.ZIndex = 2
        knob.Parent = bar
        corner(knob, 5)

        local value = currentValue
        local dragging = false

        local function update(input)
            local p = math.clamp((input.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
            value = min + (max - min) * p
            fill.Size = UDim2.new(p, 0, 1, 0)
            knob.Position = UDim2.new(p, -5, 0.5, -5)
            valBox.Text = tostring(math.floor(value))
            if key then Settings[key] = value end
            if callback then callback(value) end
        end

        bar.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                update(input)
            end
        end)
        bar.InputChanged:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                update(input)
            end
        end)
        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = false
                pcall(SaveState)
            end
        end)
        return row
    end

    local function CreateDropdown(parent, name, key, values, defaultIndex, callback)
        local currentIndex = tonumber(Settings[key]) or defaultIndex or 1
        if currentIndex < 1 then currentIndex = 1 end
        if currentIndex > #values then currentIndex = 1 end

        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, 38)
        row.BackgroundTransparency = 1
        row.Parent = parent

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -110, 0, 14)
        lbl.BackgroundTransparency = 1
        lbl.Text = name
        lbl.TextColor3 = C.Text
        lbl.Font = Enum.Font.GothamMedium
        lbl.TextSize = 11
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = row

        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, 100, 0, 24)
        btn.Position = UDim2.new(1, -100, 0, 14)
        btn.BackgroundColor3 = C.SearchBg
        btn.BackgroundTransparency = 0.1
        btn.BorderSizePixel = 0
        btn.Text = ""
        btn.AutoButtonColor = false
        btn.Parent = row
        corner(btn, 6)
        stroke(btn, C.CardStroke, 0.5, 1)

        local btnText = Instance.new("TextLabel")
        btnText.Size = UDim2.new(1, -24, 1, 0)
        btnText.Position = UDim2.new(0, 8, 0, 0)
        btnText.BackgroundTransparency = 1
        btnText.Text = tostring(values[currentIndex])
        btnText.TextColor3 = C.Text
        btnText.Font = Enum.Font.GothamMedium
        btnText.TextSize = 11
        btnText.TextXAlignment = Enum.TextXAlignment.Left
        btnText.Parent = btn

        local arrow = Instance.new("TextLabel")
        arrow.Size = UDim2.new(0, 16, 1, 0)
        arrow.Position = UDim2.new(1, -18, 0, 0)
        arrow.BackgroundTransparency = 1
        arrow.Text = "v"
        arrow.TextColor3 = C.TextDim
        arrow.Font = Enum.Font.GothamBold
        arrow.TextSize = 9
        arrow.Parent = btn

        btn.MouseButton1Click:Connect(function()
            currentIndex = currentIndex + 1
            if currentIndex > #values then currentIndex = 1 end
            btnText.Text = tostring(values[currentIndex])
            if key then Settings[key] = currentIndex end
            if callback then callback(currentIndex, values[currentIndex]) end
            pcall(SaveState)
        end)
        return row
    end

    local function CreateBind(parent, name, callback, initialKey)
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, 30)
        row.BackgroundTransparency = 1
        row.Parent = parent

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -70, 1, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = name
        lbl.TextColor3 = C.Text
        lbl.Font = Enum.Font.GothamMedium
        lbl.TextSize = 11
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = row

        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, 64, 0, 22)
        btn.Position = UDim2.new(1, -64, 0.5, -11)
        btn.BackgroundColor3 = C.SearchBg
        btn.BackgroundTransparency = 0.1
        btn.BorderSizePixel = 0
        if initialKey and typeof(initialKey) == "EnumItem" then
            btn.Text = tostring(initialKey):gsub("Enum.KeyCode.", "")
            btn.TextColor3 = C.Text
        else
            btn.Text = "Key"
            btn.TextColor3 = C.TextDim
        end
        btn.Font = Enum.Font.GothamMedium
        btn.TextSize = 10
        btn.AutoButtonColor = false
        btn.Parent = row
        corner(btn, 6)
        stroke(btn, C.CardStroke, 0.5, 1)

        local listening = false
        btn.MouseButton1Click:Connect(function()
            listening = true
            btn.Text = "..."
            btn.TextColor3 = C.Accent
        end)
        UserInputService.InputBegan:Connect(function(input, gp)
            if listening and not gp and input.UserInputType == Enum.UserInputType.Keyboard then
                listening = false
                btn.Text = tostring(input.KeyCode):gsub("Enum.KeyCode.", "")
                btn.TextColor3 = C.Text
                if callback then callback(input.KeyCode) end
                pcall(SaveState)
            end
        end)
        return row
    end

    local SIDE_W = 260
    local SIDE_GAP = 10

    local SettingsPanel = Instance.new("Frame")
    SettingsPanel.Size = UDim2.new(0, SIDE_W, 1, 0)
    SettingsPanel.Position = UDim2.new(1, SIDE_GAP, 0, 0)
    SettingsPanel.BackgroundColor3 = C.WindowBg
    SettingsPanel.BackgroundTransparency = C.WindowTransp
    SettingsPanel.BorderSizePixel = 0
    SettingsPanel.ClipsDescendants = true
    SettingsPanel.Visible = false
    SettingsPanel.ZIndex = 100
    SettingsPanel.Parent = ScreenGui
    corner(SettingsPanel, 14)
    stroke(SettingsPanel, C.CardStroke, 0.4, 1)

    local SpTitle = Instance.new("TextLabel")
    SpTitle.Size = UDim2.new(1, -24, 0, 22)
    SpTitle.Position = UDim2.new(0, 14, 0, 14)
    SpTitle.BackgroundTransparency = 1
    SpTitle.Text = "Settings"
    SpTitle.TextColor3 = C.Text
    SpTitle.Font = Enum.Font.GothamBold
    SpTitle.TextSize = 15
    SpTitle.TextXAlignment = Enum.TextXAlignment.Left
    SpTitle.ZIndex = 101
    SpTitle.Parent = SettingsPanel

    local SpFunctionName = Instance.new("TextLabel")
    SpFunctionName.Size = UDim2.new(1, -50, 0, 16)
    SpFunctionName.Position = UDim2.new(0, 14, 0, 36)
    SpFunctionName.BackgroundTransparency = 1
    SpFunctionName.Text = ""
    SpFunctionName.TextColor3 = C.TextDim
    SpFunctionName.Font = Enum.Font.GothamMedium
    SpFunctionName.TextSize = 11
    SpFunctionName.TextXAlignment = Enum.TextXAlignment.Left
    SpFunctionName.ZIndex = 101
    SpFunctionName.Parent = SettingsPanel

    local SpClose = Instance.new("TextButton")
    SpClose.Size = UDim2.new(0, 22, 0, 22)
    SpClose.Position = UDim2.new(1, -30, 0, 14)
    SpClose.BackgroundColor3 = C.PillBg
    SpClose.BackgroundTransparency = 0.3
    SpClose.BorderSizePixel = 0
    SpClose.Text = "✕"
    SpClose.TextColor3 = C.TextDim
    SpClose.Font = Enum.Font.GothamBold
    SpClose.TextSize = 11
    SpClose.AutoButtonColor = false
    SpClose.ZIndex = 101
    SpClose.Parent = SettingsPanel
    corner(SpClose, 6)

    local SpDivider = Instance.new("Frame")
    SpDivider.Size = UDim2.new(1, -28, 0, 1)
    SpDivider.Position = UDim2.new(0, 14, 0, 60)
    SpDivider.BackgroundColor3 = C.Divider
    SpDivider.BorderSizePixel = 0
    SpDivider.ZIndex = 101
    SpDivider.Parent = SettingsPanel

    local SpContent = Instance.new("ScrollingFrame")
    SpContent.Size = UDim2.new(1, -28, 1, -76)
    SpContent.Position = UDim2.new(0, 14, 0, 70)
    SpContent.BackgroundTransparency = 1
    SpContent.BorderSizePixel = 0
    SpContent.ScrollBarThickness = 3
    SpContent.ScrollBarImageColor3 = C.CardStroke
    SpContent.CanvasSize = UDim2.new(0, 0, 0, 0)
    SpContent.AutomaticCanvasSize = Enum.AutomaticSize.Y
    SpContent.ZIndex = 101
    SpContent.Parent = SettingsPanel

    local SpList = Instance.new("UIListLayout")
    SpList.SortOrder = Enum.SortOrder.LayoutOrder
    SpList.Padding = UDim.new(0, 8)
    SpList.Parent = SpContent

    local SpOpen = false
    local SpCurrentTarget = nil

    CloseSettingsPanel = function()
        if not SpOpen then return end
        SpOpen = false
        SpCurrentTarget = nil
        local tw = TweenService:Create(SettingsPanel, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.In),
            {Position = UDim2.new(0, MainFrame.AbsolutePosition.X + MainFrame.AbsoluteSize.X + SIDE_GAP + 20, 0, MainFrame.AbsolutePosition.Y)})
        tw:Play()
        tw.Completed:Connect(function()
            if not SpOpen then
                SettingsPanel.Visible = false
            end
        end)
    end

    local function PositionSettingsPanel(animateIn)
        local mainX = MainFrame.AbsolutePosition.X
        local mainY = MainFrame.AbsolutePosition.Y
        local mainW = MainFrame.AbsoluteSize.X
        local mainH = MainFrame.AbsoluteSize.Y
        local targetPos = UDim2.new(0, mainX + mainW + SIDE_GAP, 0, mainY)
        local targetSize = UDim2.new(0, SIDE_W, 0, mainH)

        SettingsPanel.Size = targetSize
        if animateIn then
            SettingsPanel.Position = UDim2.new(0, mainX + mainW + SIDE_GAP + 20, 0, mainY)
            SettingsPanel.Visible = true
            TweenService:Create(SettingsPanel, TweenInfo.new(0.28, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
                {Position = targetPos}):Play()
        else
            SettingsPanel.Position = targetPos
        end
    end

    MainFrame:GetPropertyChangedSignal("AbsolutePosition"):Connect(function()
        if SpOpen then PositionSettingsPanel(false) end
    end)
    MainFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        if SpOpen then PositionSettingsPanel(false) end
    end)

    local function OpenSettingsPanel(functionName, buildFn)
        if SpOpen and SpCurrentTarget == functionName then
            CloseSettingsPanel()
            return
        end

        for _, ch in ipairs(SpContent:GetChildren()) do
            if ch:IsA("Frame") or ch:IsA("TextLabel") or ch:IsA("TextButton") then
                ch:Destroy()
            end
        end

        SpFunctionName.Text = functionName or ""
        SpCurrentTarget = functionName

        if buildFn then buildFn(SpContent) end

        SpOpen = true
        PositionSettingsPanel(true)
    end

    SpClose.MouseButton1Click:Connect(function()
        CloseSettingsPanel()
    end)
        local function CreateFunctionCard(parent, cfg)
        local card = Instance.new("Frame")
        card.Name = (cfg.name or "Card") .. "_Card"
        card.Size = UDim2.new(0, 180, 0, 56)
        card.BackgroundColor3 = C.CardBg
        card.BackgroundTransparency = C.CardTransp
        card.BorderSizePixel = 0
        card.Parent = parent
        corner(card, 10)
        stroke(card, C.CardStroke, C.CardStrokeTr, 1)

        card.MouseEnter:Connect(function()
            TweenService:Create(card, TweenInfo.new(0.15), {
                BackgroundColor3 = Color3.fromRGB(36, 36, 41),
                BackgroundTransparency = 0.08,
            }):Play()
        end)
        card.MouseLeave:Connect(function()
            TweenService:Create(card, TweenInfo.new(0.15), {
                BackgroundColor3 = C.CardBg,
                BackgroundTransparency = C.CardTransp,
            }):Play()
        end)

        local nameLabel = Instance.new("TextLabel")
        nameLabel.Size = UDim2.new(1, -70, 0, 18)
        nameLabel.Position = UDim2.new(0, 14, 0, 12)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Text = cfg.name
        nameLabel.TextColor3 = C.Text
        nameLabel.Font = Enum.Font.GothamMedium
        nameLabel.TextSize = 13
        nameLabel.TextXAlignment = Enum.TextXAlignment.Left
        nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
        nameLabel.Parent = card

        local subLabel = Instance.new("TextLabel")
        subLabel.Size = UDim2.new(1, -70, 0, 14)
        subLabel.Position = UDim2.new(0, 14, 0, 32)
        subLabel.BackgroundTransparency = 1
        subLabel.Text = cfg.subtitle or ""
        subLabel.TextColor3 = C.TextMuted
        subLabel.Font = Enum.Font.Gotham
        subLabel.TextSize = 10
        subLabel.TextXAlignment = Enum.TextXAlignment.Left
        subLabel.TextTruncate = Enum.TextTruncate.AtEnd
        subLabel.Parent = card

        if cfg.settings and #cfg.settings > 0 then
            local dotsBtn = Instance.new("TextButton")
            dotsBtn.Size = UDim2.new(0, 22, 0, 22)
            dotsBtn.Position = UDim2.new(1, -80, 0, 12)
            dotsBtn.BackgroundTransparency = 1
            dotsBtn.Text = "···"
            dotsBtn.TextColor3 = C.TextDim
            dotsBtn.Font = Enum.Font.GothamBold
            dotsBtn.TextSize = 14
            dotsBtn.AutoButtonColor = false
            dotsBtn.Parent = card

            dotsBtn.MouseEnter:Connect(function()
                TweenService:Create(dotsBtn, TweenInfo.new(0.15), {TextColor3 = C.Text}):Play()
            end)
            dotsBtn.MouseLeave:Connect(function()
                TweenService:Create(dotsBtn, TweenInfo.new(0.15), {TextColor3 = C.TextDim}):Play()
            end)

            dotsBtn.MouseButton1Click:Connect(function()
                OpenSettingsPanel(cfg.name, function(container)
                    for i, s in ipairs(cfg.settings) do
                        local row
                        if s.type == "switch" then
                            row = Instance.new("Frame")
                            row.Size = UDim2.new(1, 0, 0, 26)
                            row.BackgroundTransparency = 1
                            row.Parent = container

                            local lbl = Instance.new("TextLabel")
                            lbl.Size = UDim2.new(1, -50, 1, 0)
                            lbl.BackgroundTransparency = 1
                            lbl.Text = s.name
                            lbl.TextColor3 = C.Text
                            lbl.Font = Enum.Font.GothamMedium
                            lbl.TextSize = 11
                            lbl.TextXAlignment = Enum.TextXAlignment.Left
                            lbl.Parent = row

                            local tog = CreateToggle(row, s.default or false, s.callback)
                            tog.Position = UDim2.new(1, -40, 0.5, -11)
                            tog.Parent = row
                        elseif s.type == "slider" then
                            row = CreateSlider(container, s.name, s.key, s.min, s.max, s.default, s.callback)
                        elseif s.type == "dropdown" then
                            row = CreateDropdown(container, s.name, s.key, s.values, s.default, s.callback)
                        elseif s.type == "bind" then
                            row = CreateBind(container, s.name, s.callback, s.initialKey)
                        end
                        if row then
                            row.LayoutOrder = i
                            row.Parent = container
                        end
                    end
                end)
            end)
        end

        local toggle = CreateToggle(card, cfg.default or false, cfg.callback)
        toggle.Position = UDim2.new(1, -50, 0, 12)
        toggle.Parent = card

        return card
    end

    local CategoryButtons = {}
    local CategoryBuilders = {}
    local CurrentCategory = "Combat"

    local function CreatePill(name, layoutOrder, callback)
        local pill = Instance.new("TextButton")
        pill.Name = name .. "_Pill"
        pill.Size = UDim2.new(0, 100, 0, 34)
        pill.BackgroundColor3 = C.PillBg
        pill.BackgroundTransparency = C.PillTransp
        pill.BorderSizePixel = 0
        pill.Text = ""
        pill.AutoButtonColor = false
        pill.LayoutOrder = layoutOrder
        pill.Parent = CategoryBar
        corner(pill, 10)

        local dot = Instance.new("Frame")
        dot.Size = UDim2.new(0, 14, 0, 14)
        dot.Position = UDim2.new(0, 10, 0.5, -7)
        dot.BackgroundColor3 = C.TextMuted
        dot.BackgroundTransparency = 0.4
        dot.BorderSizePixel = 0
        dot.Parent = pill
        corner(dot, 4)

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -32, 1, 0)
        lbl.Position = UDim2.new(0, 30, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = name
        lbl.TextColor3 = C.TextDim
        lbl.Font = Enum.Font.GothamMedium
        lbl.TextSize = 12
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = pill

        local function resize()
            local w = lbl.TextBounds.X + 48
            if w < 90 then w = 90 end
            pill.Size = UDim2.new(0, w, 0, 34)
        end
        task.defer(resize)

        CategoryButtons[name] = {button = pill, label = lbl, dot = dot}

        pill.MouseEnter:Connect(function()
            if CurrentCategory ~= name then
                TweenService:Create(pill, TweenInfo.new(0.15), {
                    BackgroundColor3 = C.PillBgActive,
                    BackgroundTransparency = 0.05,
                }):Play()
            end
        end)
        pill.MouseLeave:Connect(function()
            if CurrentCategory ~= name then
                TweenService:Create(pill, TweenInfo.new(0.15), {
                    BackgroundColor3 = C.PillBg,
                    BackgroundTransparency = C.PillTransp,
                }):Play()
            end
        end)

        pill.MouseButton1Click:Connect(function()
            if callback then callback(name) end
        end)

        return pill
    end

    local function SetActiveCategory(name)
        CurrentCategory = name
        for cn, data in pairs(CategoryButtons) do
            local active = (cn == name)
            TweenService:Create(data.button, TweenInfo.new(0.18), {
                BackgroundColor3 = active and C.PillBgActive or C.PillBg,
                BackgroundTransparency = active and 0 or C.PillTransp,
            }):Play()
            TweenService:Create(data.label, TweenInfo.new(0.18), {
                TextColor3 = active and C.Text or C.TextDim,
            }):Play()
            TweenService:Create(data.dot, TweenInfo.new(0.18), {
                BackgroundColor3 = active and C.Accent or C.TextMuted,
                BackgroundTransparency = active and 0 or 0.4,
            }):Play()
        end
        CloseSettingsPanel()
        for _, ch in ipairs(ContentScroll:GetChildren()) do
            if not ch:IsA("UIGridLayout") and not ch:IsA("UIPadding") then
                ch:Destroy()
            end
        end
        if CategoryBuilders[name] then
            CategoryBuilders[name](SearchBox.Text)
        end
    end

    local function PopulateGrid(groups, query)
        query = (query or ""):lower()
        local order = 0
        for _, group in ipairs(groups) do
            for _, cfg in ipairs(group.items) do
                if query == "" or cfg.name:lower():find(query, 1, true) then
                    local card = CreateFunctionCard(ContentScroll, cfg)
                    card.LayoutOrder = order
                    order = order + 1
                end
            end
        end
    end

    CategoryBuilders["Combat"] = function(query)
        PopulateGrid({
            {name = "Attack", items = {
                {name = "AimBot",
                 default = Settings.AimBot,
                 subtitle = "Auto-aim at nearest target",
                 callback = function(s) Settings.AimBot = s; ToggleAimBot(s) end,
                 settings = {
                    {type = "switch", name = "Only Murderer", default = Settings.AimBotOnlyMurderer, callback = function(s) Settings.AimBotOnlyMurderer = s end},
                    {type = "switch", name = "Wall Check", default = Settings.AimBotWallCheck, callback = function(s) Settings.AimBotWallCheck = s end},
                    {type = "slider", name = "FOV", key = "AimBotFOV", min = 50, max = 300, default = Settings.AimBotFOV, callback = function(v) Settings.AimBotFOV = v end},
                    {type = "slider", name = "Prediction", key = "AimBotPrediction", min = 0, max = 100, default = Settings.AimBotPrediction, callback = function(v) Settings.AimBotPrediction = v end},
                    {type = "bind", name = "AimBot Key", initialKey = Settings.AimBotKey, callback = function(k) Settings.AimBotKey = k end},
                }},
                {name = "Lock Mouse",
                 default = Settings.LockMouse,
                 subtitle = "Lock cursor to center",
                 callback = function(s) Settings.LockMouse = s; ToggleLockMouse(s) end,
                 settings = {
                    {type = "bind", name = "Lock Mouse Key", initialKey = Settings.LockMouseKey, callback = function(k) Settings.LockMouseKey = k end},
                 }},
            }},
            {name = "Automation", items = {
                {name = "KillAll",
                 default = Settings.KillAll,
                 subtitle = "Teleport-kill every alive player",
                 callback = function(s) Settings.KillAll = s; ToggleKillAll(s) end},
            }},
        }, query)
    end

    CategoryBuilders["Movement"] = function(query)
        PopulateGrid({
            {name = "Utility", items = {
                {name = "Fly",
                 default = Settings.Fly,
                 subtitle = "WASD + Space / LShift",
                 callback = function(s) Settings.Fly = s; ToggleFly(s) end,
                 settings = {
                    {type = "bind", name = "Fly Key", initialKey = Settings.FlyKey, callback = function(k) Settings.FlyKey = k end},
                 }},
                {name = "NoClip",
                 default = Settings.NoClip,
                 subtitle = "Pass through walls",
                 callback = function(s) Settings.NoClip = s; ToggleNoClip(s) end,
                 settings = {
                    {type = "bind", name = "NoClip Key", initialKey = Settings.NoClipKey, callback = function(k) Settings.NoClipKey = k end},
                 }},
            }},
        }, query)
    end

    CategoryBuilders["Visuals"] = function(query)
        PopulateGrid({
            {name = "Overlay", items = {
                {name = "Player ESP",
                 default = Settings.PlayerESP,
                 subtitle = "Highlight players by role",
                 callback = function(s)
                    Settings.PlayerESP = s
                    if s then UpdateAllVisuals() else ClearAllESP() end
                 end},
                {name = "NameTags",
                 default = Settings.NameTags,
                 subtitle = "Name + role above head",
                 callback = function(s)
                    Settings.NameTags = s
                    if s then UpdateAllVisuals() else ClearAllNameTags() end
                 end},
                {name = "See Invisibles",
                 default = Settings.SeeInvisibles,
                 subtitle = "Reveal invisible players",
                 callback = function(s)
                    Settings.SeeInvisibles = s
                    if not s then ClearAllInvisibleESP() end
                 end},
                {name = "Tracers",
                 default = Settings.Tracers,
                 subtitle = "Lines to players",
                 callback = function(s) Settings.Tracers = s; ToggleTracers(s) end},
            }},
            {name = "Environment", items = {
                {name = "Ambience",
                 default = Settings.Ambience,
                 subtitle = "Skybox + lighting preset",
                 callback = function(s)
                    Settings.Ambience = s
                    if s then ApplySkybox(Settings.AmbienceType) else RemoveSkybox() end
                 end,
                 settings = {
                    {type = "dropdown", name = "Type", key = "AmbienceType",
                     values = {"Day","Night","Evening","Sunset","Anime"}, default = 1,
                     callback = function(idx, val)
                        Settings.AmbienceType = val
                        if Settings.Ambience then ApplySkybox(val) end
                     end},
                 }},
                {name = "Shaders",
                 default = Settings.Shaders,
                 subtitle = "Post-processing effects",
                 callback = function(s) Settings.Shaders = s; ToggleShaders(s) end,
                 settings = {
                    {type = "dropdown", name = "Mode", key = "ShaderMode",
                     values = {"Blur","Ultra"}, default = 1,
                     callback = function(idx, val) Settings.ShaderMode = idx; SetShaderModeByNumber(idx) end},
                 }},
                {name = "Particles",
                 default = Settings.Particles,
                 subtitle = "Snowflake field",
                 callback = function(s) Settings.Particles = s; ToggleParticles(s) end},
            }},
        }, query)
    end

    CategoryBuilders["Player"] = function(query)
        PopulateGrid({
            {name = "Utility", items = {
                {name = "AutoGunLooter",
                 default = Settings.AutoGunLooter,
                 subtitle = "Teleport drops to you",
                 callback = function(s) Settings.AutoGunLooter = s; ToggleAutoGunLooter(s) end},
            }},
        }, query)
    end

    CategoryBuilders["Miscellaneous"] = function(query)
        PopulateGrid({
            {name = "Notifications", items = {
                {name = "Murderer Alert",
                 default = Settings.MurderNotification,
                 subtitle = "Notify when murderer revealed",
                 callback = function(s) Settings.MurderNotification = s end},
                {name = "Sheriff Alert",
                 default = Settings.SheriffNotification,
                 subtitle = "Notify when sheriff revealed",
                 callback = function(s) Settings.SheriffNotification = s end},
            }},
        }, query)
    end

    CategoryBuilders["Waypoints"] = function(query)
        query = (query or ""):lower()

        local addBtn = Instance.new("TextButton")
        addBtn.Size = UDim2.new(0, 180, 0, 56)
        addBtn.BackgroundColor3 = C.CardBg
        addBtn.BackgroundTransparency = C.CardTransp
        addBtn.BorderSizePixel = 0
        addBtn.Text = "+ Add Waypoint"
        addBtn.TextColor3 = C.Accent
        addBtn.Font = Enum.Font.GothamBold
        addBtn.TextSize = 12
        addBtn.AutoButtonColor = false
        addBtn.LayoutOrder = 0
        addBtn.Parent = ContentScroll
        corner(addBtn, 10)
        stroke(addBtn, C.Accent, 0.4, 1)

        addBtn.MouseButton1Click:Connect(function()
            local char = LocalPlayer.Character
            if not char then
                ShowNotification("Waypoint error", "No character", C.Danger)
                return
            end
            local root = char:FindFirstChild("HumanoidRootPart")
            if not root then
                ShowNotification("Waypoint error", "No root part", C.Danger)
                return
            end
            local ts = tick()
            local name = "WP_" .. tostring(math.floor(ts % 100000))
            local n = 1
            while Waypoints[name] do
                n = n + 1
                name = "WP_" .. tostring(math.floor(ts % 100000)) .. "_" .. n
            end
            Waypoints[name] = {pos = {X = root.Position.X, Y = root.Position.Y, Z = root.Position.Z}}
            safeWrite(WAYPOINT_FILE, Waypoints)
            ShowNotification("Waypoint added", name, C.Accent)
            SetActiveCategory("Waypoints")
        end)

        local clearBtn = Instance.new("TextButton")
        clearBtn.Size = UDim2.new(0, 180, 0, 56)
        clearBtn.BackgroundColor3 = Color3.fromRGB(60, 26, 26)
        clearBtn.BackgroundTransparency = 0.2
        clearBtn.BorderSizePixel = 0
        clearBtn.Text = "Clear All"
        clearBtn.TextColor3 = Color3.fromRGB(255, 180, 180)
        clearBtn.Font = Enum.Font.GothamBold
        clearBtn.TextSize = 12
        clearBtn.AutoButtonColor = false
        clearBtn.LayoutOrder = 1
        clearBtn.Parent = ContentScroll
        corner(clearBtn, 10)
        stroke(clearBtn, C.Danger, 0.3, 1)

        clearBtn.MouseButton1Click:Connect(function()
            Waypoints = {}
            safeWrite(WAYPOINT_FILE, Waypoints)
            ShowNotification("Waypoints", "Cleared all", C.Danger)
            SetActiveCategory("Waypoints")
        end)

        local order = 2
        for wpName, data in pairs(Waypoints) do
            if query == "" or wpName:lower():find(query, 1, true) then
                local card = Instance.new("Frame")
                card.Size = UDim2.new(0, 180, 0, 56)
                card.BackgroundColor3 = C.CardBg
                card.BackgroundTransparency = C.CardTransp
                card.BorderSizePixel = 0
                card.LayoutOrder = order
                order = order + 1
                card.Parent = ContentScroll
                corner(card, 10)
                stroke(card, C.CardStroke, C.CardStrokeTr, 1)

                local nm = Instance.new("TextLabel")
                nm.Size = UDim2.new(1, -50, 0, 16)
                nm.Position = UDim2.new(0, 12, 0, 10)
                nm.BackgroundTransparency = 1
                nm.Text = wpName
                nm.TextColor3 = C.Text
                nm.Font = Enum.Font.GothamMedium
                nm.TextSize = 12
                nm.TextXAlignment = Enum.TextXAlignment.Left
                nm.TextTruncate = Enum.TextTruncate.AtEnd
                nm.Parent = card

                local renameBtn = Instance.new("TextButton")
                renameBtn.Size = UDim2.new(0, 22, 0, 22)
                renameBtn.Position = UDim2.new(1, -26, 0, 6)
                renameBtn.BackgroundTransparency = 1
                renameBtn.Text = "✎"
                renameBtn.TextColor3 = C.TextDim
                renameBtn.Font = Enum.Font.GothamBold
                renameBtn.TextSize = 13
                renameBtn.AutoButtonColor = false
                renameBtn.Parent = card

                renameBtn.MouseEnter:Connect(function()
                    TweenService:Create(renameBtn, TweenInfo.new(0.15), {TextColor3 = C.Text}):Play()
                end)
                renameBtn.MouseLeave:Connect(function()
                    TweenService:Create(renameBtn, TweenInfo.new(0.15), {TextColor3 = C.TextDim}):Play()
                end)

                local coords = Instance.new("TextLabel")
                coords.Size = UDim2.new(1, -20, 0, 14)
                coords.Position = UDim2.new(0, 12, 0, 28)
                coords.BackgroundTransparency = 1
                coords.Text = string.format("%.0f, %.0f, %.0f", data.pos.X, data.pos.Y, data.pos.Z)
                coords.TextColor3 = C.TextMuted
                coords.Font = Enum.Font.Gotham
                coords.TextSize = 10
                coords.TextXAlignment = Enum.TextXAlignment.Left
                coords.Parent = card

                local tp = Instance.new("TextButton")
                tp.Size = UDim2.new(0, 44, 0, 20)
                tp.Position = UDim2.new(1, -100, 0, 28)
                tp.BackgroundColor3 = C.Accent
                tp.BackgroundTransparency = 0.1
                tp.BorderSizePixel = 0
                tp.Text = "TP"
                tp.TextColor3 = C.Text
                tp.Font = Enum.Font.GothamBold
                tp.TextSize = 10
                tp.AutoButtonColor = false
                tp.Parent = card
                corner(tp, 5)

                local del = Instance.new("TextButton")
                del.Size = UDim2.new(0, 22, 0, 20)
                del.Position = UDim2.new(1, -52, 0, 28)
                del.BackgroundColor3 = C.Danger
                del.BackgroundTransparency = 0.2
                del.BorderSizePixel = 0
                del.Text = "✕"
                del.TextColor3 = Color3.fromRGB(255, 255, 255)
                del.Font = Enum.Font.GothamBold
                del.TextSize = 10
                del.AutoButtonColor = false
                del.Parent = card
                corner(del, 5)

                local wpPos = data.pos
                local wpN = wpName
                tp.MouseButton1Click:Connect(function()
                    local char = LocalPlayer.Character
                    if not char then return end
                    local root = char:FindFirstChild("HumanoidRootPart")
                    if not root then return end
                    root.CFrame = CFrame.new(wpPos.X, wpPos.Y, wpPos.Z)
                    ShowNotification("Teleported", wpN, C.Accent)
                end)
                del.MouseButton1Click:Connect(function()
                    Waypoints[wpN] = nil
                    safeWrite(WAYPOINT_FILE, Waypoints)
                    SetActiveCategory("Waypoints")
                end)

                renameBtn.MouseButton1Click:Connect(function()
                    local ScreenGuiRef = game.CoreGui:FindFirstChild("GeloWare")
                    if not ScreenGuiRef then return end
                    if ScreenGuiRef:FindFirstChild("RenameDialog") then
                        ScreenGuiRef.RenameDialog:Destroy()
                    end

                    local dlg = Instance.new("Frame")
                    dlg.Name = "RenameDialog"
                    dlg.Size = UDim2.new(0, 260, 0, 110)
                    dlg.Position = UDim2.new(0.5, -130, 0.5, -55)
                    dlg.BackgroundColor3 = C.CardBg
                    dlg.BackgroundTransparency = 0.05
                    dlg.BorderSizePixel = 0
                    dlg.ZIndex = 200
                    dlg.Active = true
                    dlg.Draggable = true
                    dlg.Parent = ScreenGuiRef
                    corner(dlg, 10)
                    stroke(dlg, C.Accent, 0.3, 1.2)

                    local lbl = Instance.new("TextLabel")
                    lbl.Size = UDim2.new(1, -20, 0, 18)
                    lbl.Position = UDim2.new(0, 10, 0, 10)
                    lbl.BackgroundTransparency = 1
                    lbl.Text = "Rename waypoint"
                    lbl.TextColor3 = C.Text
                    lbl.Font = Enum.Font.GothamBold
                    lbl.TextSize = 12
                    lbl.TextXAlignment = Enum.TextXAlignment.Left
                    lbl.ZIndex = 201
                    lbl.Parent = dlg

                    local box = Instance.new("TextBox")
                    box.Size = UDim2.new(1, -20, 0, 28)
                    box.Position = UDim2.new(0, 10, 0, 36)
                    box.BackgroundColor3 = C.SearchBg
                    box.BackgroundTransparency = 0.1
                    box.BorderSizePixel = 0
                    box.Text = wpN
                    box.PlaceholderText = "New name..."
                    box.PlaceholderColor3 = C.TextMuted
                    box.TextColor3 = C.Text
                    box.Font = Enum.Font.Gotham
                    box.TextSize = 12
                    box.ClearTextOnFocus = false
                    box.ZIndex = 201
                    box.Parent = dlg
                    corner(box, 6)
                    stroke(box, C.CardStroke, 0.5, 1)

                    local okBtn = Instance.new("TextButton")
                    okBtn.Size = UDim2.new(0, 80, 0, 26)
                    okBtn.Position = UDim2.new(0, 10, 1, -36)
                    okBtn.BackgroundColor3 = C.Accent
                    okBtn.BackgroundTransparency = 0.1
                    okBtn.BorderSizePixel = 0
                    okBtn.Text = "OK"
                    okBtn.TextColor3 = C.Text
                    okBtn.Font = Enum.Font.GothamBold
                    okBtn.TextSize = 11
                    okBtn.AutoButtonColor = false
                    okBtn.ZIndex = 201
                    okBtn.Parent = dlg
                    corner(okBtn, 6)

                    local cancelBtn = Instance.new("TextButton")
                    cancelBtn.Size = UDim2.new(0, 80, 0, 26)
                    cancelBtn.Position = UDim2.new(1, -90, 1, -36)
                    cancelBtn.BackgroundColor3 = C.PillBg
                    cancelBtn.BackgroundTransparency = 0.2
                    cancelBtn.BorderSizePixel = 0
                    cancelBtn.Text = "Cancel"
                    cancelBtn.TextColor3 = C.Text
                    cancelBtn.Font = Enum.Font.GothamBold
                    cancelBtn.TextSize = 11
                    cancelBtn.AutoButtonColor = false
                    cancelBtn.ZIndex = 201
                    cancelBtn.Parent = dlg
                    corner(cancelBtn, 6)

                    okBtn.MouseButton1Click:Connect(function()
                        local newName = box.Text:gsub("^%s+", ""):gsub("%s+$", "")
                        if newName ~= "" and newName ~= wpN and not Waypoints[newName] then
                            local savedData = Waypoints[wpN]
                            Waypoints[wpN] = nil
                            Waypoints[newName] = savedData
                            safeWrite(WAYPOINT_FILE, Waypoints)
                        end
                        dlg:Destroy()
                        SetActiveCategory("Waypoints")
                    end)

                    cancelBtn.MouseButton1Click:Connect(function()
                        dlg:Destroy()
                    end)

                    box:CaptureFocus()
                end)
            end
        end
    end

    CreatePill("Combat", 1, SetActiveCategory)
    CreatePill("Movement", 2, SetActiveCategory)
    CreatePill("Visuals", 3, SetActiveCategory)
    CreatePill("Player", 4, SetActiveCategory)
    CreatePill("Miscellaneous", 5, SetActiveCategory)
    CreatePill("Waypoints", 6, SetActiveCategory)

    local GwButton = Instance.new("TextButton")
    GwButton.Name = "GwButton"
    GwButton.Size = UDim2.new(0, 100, 0, 40)
    GwButton.Position = UDim2.new(0, 20, 0, 20)
    GwButton.BackgroundColor3 = Color3.fromRGB(21, 21, 24)
    GwButton.BackgroundTransparency = 0.1
    GwButton.BorderSizePixel = 0
    GwButton.Text = "GW"
    GwButton.TextColor3 = Color3.fromRGB(232, 232, 236)
    GwButton.Font = Enum.Font.GothamBold
    GwButton.TextSize = 20
    GwButton.AutoButtonColor = false
    GwButton.Active = true
    GwButton.Draggable = true
    GwButton.Parent = ScreenGui
    corner(GwButton, 10)

    GwButton.MouseButton1Click:Connect(function()
        if OpenGUI and CloseGUI then
            if MainFrame.Visible then CloseGUI() else OpenGUI() end
        end
    end)
    GwButton.MouseEnter:Connect(function()
        TweenService:Create(GwButton, TweenInfo.new(0.15), {BackgroundTransparency = 0.05}):Play()
    end)
    GwButton.MouseLeave:Connect(function()
        TweenService:Create(GwButton, TweenInfo.new(0.15), {BackgroundTransparency = 0.1}):Play()
    end)

    local BlurEffect = Instance.new("BlurEffect")
    BlurEffect.Size = 0
    BlurEffect.Parent = Lighting

    local isOpen = false
    local isAnimating = false

    OpenGUI = function()
        if isAnimating or isOpen then return end
        isAnimating = true
        isOpen = true
        MainFrame.Visible = true
        MainFrame.BackgroundTransparency = 1
        MainFrame.Position = UDim2.new(0.5, -WINDOW_W/2, 0.5, -WINDOW_H/2)
        MainFrame.Size = UDim2.new(0, WINDOW_W, 0, WINDOW_H)

        TweenService:Create(MainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
            {BackgroundTransparency = C.WindowTransp}):Play()
        TweenService:Create(BlurEffect, TweenInfo.new(0.3), {Size = 12}):Play()

        task.wait(0.3)
        isAnimating = false
    end

    CloseGUI = function()
        if isAnimating or not isOpen then return end
        isAnimating = true
        isOpen = false
        CloseSettingsPanel()

        TweenService:Create(MainFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.In),
            {BackgroundTransparency = 1}):Play()
        TweenService:Create(BlurEffect, TweenInfo.new(0.25), {Size = 0}):Play()

        task.wait(0.25)
        MainFrame.Visible = false
        isAnimating = false
    end

    UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        if input.KeyCode == Enum.KeyCode.RightShift then
            if isOpen then CloseGUI() else OpenGUI() end
        end
    end)

    SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
        if CategoryBuilders[CurrentCategory] then
            CategoryBuilders[CurrentCategory](SearchBox.Text)
        end
    end)

    SetActiveCategory("Combat")
end

UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if Settings.FlyKey and input.KeyCode == Settings.FlyKey then ToggleFly(not Settings.Fly) end
    if Settings.NoClipKey and input.KeyCode == Settings.NoClipKey then ToggleNoClip(not Settings.NoClip) end
    if Settings.AimBotKey and input.KeyCode == Settings.AimBotKey then ToggleAimBot(not Settings.AimBot) end
    if Settings.LockMouseKey and input.KeyCode == Settings.LockMouseKey then ToggleLockMouse(not Settings.LockMouse) end
end)

UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.RightShift and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
        Settings.LockMouse = false
        UserInputService.MouseBehavior = Enum.MouseBehavior.Default
        ToggleLockMouse(false)
        pcall(SaveState)
        if ShowNotification then
            ShowNotification("LockMouse OFF", "Force unlocked", Color3.fromRGB(70, 190, 110))
        end
    end
end)

task.spawn(function()
    task.wait(1.5)
    if Settings.Shaders then
        SetShaderModeByNumber(Settings.ShaderMode)
        ToggleShaders(true)
    end
    if Settings.Ambience then ApplySkybox(Settings.AmbienceType) end
    if Settings.Fly then ToggleFly(true) end
    if Settings.NoClip then ToggleNoClip(true) end
    if Settings.AimBot then ToggleAimBot(true) end
    if Settings.LockMouse then ToggleLockMouse(true) end
    if Settings.Tracers then ToggleTracers(true) end
    if Settings.Particles then ToggleParticles(true) end
    if Settings.PlayerESP or Settings.NameTags then UpdateAllVisuals() end
    if Settings.AutoGunLooter then ToggleAutoGunLooter(true) end
    if Settings.KillAll then ToggleKillAll(true) end
    pcall(function() SaveState() end)
end)

Settings.LockMouse = false
UserInputService.MouseBehavior = Enum.MouseBehavior.Default

BuildGUI()
