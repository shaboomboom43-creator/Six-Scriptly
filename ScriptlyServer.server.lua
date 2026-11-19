-- SCRIPTLY - 628 | SERVER CONTROLLER  (build 6.28.1)
-- Install as a normal Script in ServerScriptService. Works in any experience you own.
--
-- Who is allowed to use it (checked on the server, never trusted from the client):
--   1. Anyone, while running inside Roblox Studio.
--   2. The owner of a user-owned experience.
--   3. Any UserId listed in DEVELOPER_IDS.
--   4. Group members at or above MIN_GROUP_RANK, for a group-owned experience
--      (or for GROUP_ID, if you set it - handy for a studio group that owns several games).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")

local DEVELOPER_IDS = {
    -- [1234567] = true,   -- add your studio's developer UserIds here
}
local GROUP_ID = 0          -- 0 = use the group that owns this experience (if it is group-owned)
local MIN_GROUP_RANK = 255  -- 255 = group owner only. Lower it (e.g. 200) to let your dev ranks in.
local MAX_COMMANDS_PER_SECOND = 12
local DEFAULT_GRAVITY = workspace.Gravity
local DEFAULT_CLOCK_TIME = Lighting.ClockTime
local frozen = {}
local ghosted = {}
local ghostTransparency = {}

local folder = ReplicatedStorage:FindFirstChild("Scriptly628Remotes") or Instance.new("Folder")
folder.Name = "Scriptly628Remotes"
folder.Parent = ReplicatedStorage
local command = folder:FindFirstChild("Command") or Instance.new("RemoteEvent")
command.Name = "Command"
command.Parent = folder
local access = folder:FindFirstChild("CheckAccess") or Instance.new("RemoteFunction")
access.Name = "CheckAccess"
access.Parent = folder

local rankCache = {}   -- [userId] = { rank = number, at = os.clock() }

local function groupRank(player)
    local groupId = GROUP_ID
    if groupId == 0 and game.CreatorType == Enum.CreatorType.Group then groupId = game.CreatorId end
    if groupId == 0 then return 0 end
    local cached = rankCache[player.UserId]
    if cached and os.clock() - cached.at < 60 then return cached.rank end
    local ok, rank = pcall(function() return player:GetRankInGroup(groupId) end)
    rank = ok and tonumber(rank) or 0
    rankCache[player.UserId] = { rank = rank, at = os.clock() }
    return rank
end

local function allowed(player)
    if RunService:IsStudio() then return true end
    if DEVELOPER_IDS[player.UserId] == true then return true end
    if game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId then return true end
    return groupRank(player) >= MIN_GROUP_RANK
end
access.OnServerInvoke = allowed

-- Simple per-player rate limit so a client cannot flood the controller.
local buckets = {}
local function withinRate(player)
    local now = os.clock()
    local b = buckets[player] or { start = now, count = 0 }
    if now - b.start >= 1 then b.start, b.count = now, 0 end
    b.count = b.count + 1
    buckets[player] = b
    return b.count <= MAX_COMMANDS_PER_SECOND
end

local function characterParts(player)
    local char = player.Character
    if not char then return nil,nil,nil end
    return char, char:FindFirstChildOfClass("Humanoid"), char:FindFirstChild("HumanoidRootPart")
end
local function notice(player,message)
    command:FireClient(player,"Announcement",{message=message,by="SCRIPTLY SERVER"})
end
local function spawnCFrame()
    local spawn = workspace:FindFirstChildWhichIsA("SpawnLocation",true)
    if spawn then return spawn.CFrame + Vector3.new(0,4,0) end
    local named = workspace:FindFirstChild("Spawn",true)
    if named and named:IsA("BasePart") then return named.CFrame + Vector3.new(0,4,0) end
    return CFrame.new(0,8,0)
end
local function setFrozen(player,on)
    local _,hum = characterParts(player)
    if not hum then return end
    if on then
        if frozen[player] then return end
        frozen[player]={WalkSpeed=hum.WalkSpeed,JumpPower=hum.JumpPower,JumpHeight=hum.JumpHeight,UseJumpPower=hum.UseJumpPower,AutoRotate=hum.AutoRotate}
        hum.WalkSpeed=0; hum.JumpPower=0; hum.JumpHeight=0; hum.AutoRotate=false
    else
        local old=frozen[player]
        if not old then return end
        hum.WalkSpeed=old.WalkSpeed; hum.JumpPower=old.JumpPower; hum.JumpHeight=old.JumpHeight
        hum.UseJumpPower=old.UseJumpPower; hum.AutoRotate=old.AutoRotate
        frozen[player]=nil
    end
end
local function setGhost(player,on)
    local char=player.Character
    if not char then return end
    if on then
        if ghosted[player] then return end
        ghosted[player]=true; ghostTransparency[player]={}
        for _,obj in ipairs(char:GetDescendants()) do
            if obj:IsA("BasePart") or obj:IsA("Decal") or obj:IsA("Texture") then
                ghostTransparency[player][obj]=obj.Transparency
                obj.Transparency=0.78
            end
        end
    else
        ghosted[player]=nil
        for obj,value in pairs(ghostTransparency[player] or {}) do
            if obj and obj.Parent then obj.Transparency=value end
        end
        ghostTransparency[player]=nil
    end
end
local function findPlayer(name)
    if typeof(name)~="string" then return nil end
    local wanted=string.lower(string.sub(name,1,32))
    for _,p in ipairs(Players:GetPlayers()) do
        if string.lower(p.Name)==wanted or string.lower(p.DisplayName)==wanted then return p end
    end
end

command.OnServerEvent:Connect(function(player,action,data)
    if not withinRate(player) then return end
    if not allowed(player) then
        warn("[Scriptly 628] Rejected unauthorised command from "..player.Name)
        return
    end
    if typeof(action)~="string" then return end
    if typeof(data)~="table" then data={} end
    local char,hum,root=characterParts(player)

    if action=="SetMovement" then
        if not hum then return end
        hum.UseJumpPower=true
        hum.WalkSpeed=math.clamp(tonumber(data.speed) or 16,0,150)
        hum.JumpPower=math.clamp(tonumber(data.jump) or 50,0,200)
    elseif action=="ResetMovement" then
        if hum then hum.UseJumpPower=true; hum.WalkSpeed=16; hum.JumpPower=50; hum.JumpHeight=7.2 end
    elseif action=="TeleportSpawn" then
        if root then root.CFrame=spawnCFrame(); root.AssemblyLinearVelocity=Vector3.zero end
    elseif action=="TeleportToPlayer" then
        if not root then return end
        local target=findPlayer(data.target)
        local targetRoot=target and target.Character and target.Character:FindFirstChild("HumanoidRootPart")
        if targetRoot and target~=player then root.CFrame=targetRoot.CFrame*CFrame.new(3,0,0); root.AssemblyLinearVelocity=Vector3.zero
        else notice(player,"Target player not found.") end
    elseif action=="Heal" then
        if hum then hum.Health=hum.MaxHealth end
    elseif action=="Respawn" then
        player:LoadCharacter()
    elseif action=="FreezeSelf" then
        setFrozen(player,true)
    elseif action=="UnfreezeSelf" then
        setFrozen(player,false)
    elseif action=="GhostSelf" then
        setGhost(player,true)
    elseif action=="UnghostSelf" then
        setGhost(player,false)
    elseif action=="LaunchSelf" then
        if root then root:ApplyImpulse(Vector3.new(0,root.AssemblyMass*125,0)) end
    elseif action=="LowGravityGlobal" then
        workspace.Gravity=55
        command:FireAllClients("Announcement",{message="GLOBAL GRAVITY: LOW",by="SCRIPTLY SERVER"})
    elseif action=="ResetGravityGlobal" then
        workspace.Gravity=DEFAULT_GRAVITY
        command:FireAllClients("Announcement",{message="Gravity restored.",by="SCRIPTLY SERVER"})
    elseif action=="Day" then
        Lighting.ClockTime=14
    elseif action=="Night" then
        Lighting.ClockTime=0
    elseif action=="ResetTime" then
        Lighting.ClockTime=DEFAULT_CLOCK_TIME
    elseif action=="ForceField" then
        if char and not char:FindFirstChildOfClass("ForceField") then
            local ff=Instance.new("ForceField"); ff.Parent=char; Debris:AddItem(ff,12)
        end
    elseif action=="FlopSelf" then
        if hum then
            hum:ChangeState(Enum.HumanoidStateType.Physics); hum.PlatformStand=true
            task.delay(2,function() if hum and hum.Parent then hum.PlatformStand=false; hum:ChangeState(Enum.HumanoidStateType.GettingUp) end end)
        end
    elseif action=="ServerJumpscare" then
        command:FireAllClients("Jumpscare",{by=player.DisplayName})
    elseif action=="ServerConfetti" then
        command:FireAllClients("Confetti",{by=player.DisplayName})
    elseif action=="ServerAnnouncement" then
        local message=data.message
        if typeof(message)~="string" then return end
        message=string.sub(message,1,110):gsub("[%c]"," ")
        if message:gsub("%s","")=="" then return end
        command:FireAllClients("Announcement",{message=message,by=player.DisplayName})
    end
end)

Players.PlayerRemoving:Connect(function(p)
    frozen[p]=nil; ghosted[p]=nil; ghostTransparency[p]=nil
    buckets[p]=nil; rankCache[p.UserId]=nil
end)
print("[Scriptly 628] Server controller ready.")
