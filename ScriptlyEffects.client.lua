-- SCRIPTLY // 628  -  CLIENT-WIDE EFFECT RECEIVER  (build 6.28.1)
-- Install as a LocalScript in StarterPlayer > StarterPlayerScripts.
-- Renders the server-wide announcement / jumpscare / confetti sent by ScriptlyServer.server.lua
-- so every player in your experience sees them, in the same retro-cyber style as the hub.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local old = playerGui:FindFirstChild("Scriptly628Effects")
if old then old:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "Scriptly628Effects"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 950
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local CYAN = Color3.fromRGB(0, 240, 255)
local PINK = Color3.fromRGB(255, 46, 176)
local PANEL = Color3.fromRGB(10, 12, 27)
local TEXT = Color3.fromRGB(226, 233, 255)
local RED = Color3.fromRGB(255, 40, 70)

local function font(name, fallback)
    local ok, f = pcall(function() return Enum.Font[name] end)
    return (ok and f) or fallback
end
local HEAD = font("Sarpanch", Enum.Font.Code)
local LOGO = font("Arcade", Enum.Font.Code)

local function stroke(parent, color, thickness)
    local s = Instance.new("UIStroke")
    s.Color = color
    s.Thickness = thickness or 1
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = parent
    return s
end

local function label(parent, text, props)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1
    l.BorderSizePixel = 0
    l.Text = text
    l.Font = Enum.Font.Code
    l.TextSize = 13
    l.TextColor3 = TEXT
    l.TextXAlignment = Enum.TextXAlignment.Left
    for k, v in pairs(props or {}) do l[k] = v end
    l.Parent = parent
    return l
end

-- Announcement banner (top centre).
local function announce(message, by)
    message = tostring(message or "")
    local card = Instance.new("Frame")
    card.AnchorPoint = Vector2.new(0.5, 0)
    card.Position = UDim2.new(0.5, 0, 0, -90)
    card.Size = UDim2.fromOffset(480, 72)
    card.BackgroundColor3 = PANEL
    card.BorderSizePixel = 0
    card.Parent = gui
    stroke(card, CYAN, 1.5)
    local bar = Instance.new("Frame")
    bar.BackgroundColor3 = PINK
    bar.BorderSizePixel = 0
    bar.Size = UDim2.new(0, 4, 1, 0)
    bar.Parent = card
    label(card, string.upper(tostring(by or "SCRIPTLY SERVER")), {
        Font = HEAD, TextSize = 13, TextColor3 = CYAN,
        Position = UDim2.fromOffset(16, 6), Size = UDim2.new(1, -28, 0, 18),
    })
    label(card, message, {
        TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top,
        Position = UDim2.fromOffset(16, 26), Size = UDim2.new(1, -28, 1, -32),
    })
    TweenService:Create(card, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Position = UDim2.new(0.5, 0, 0, 18),
    }):Play()
    task.delay(3.6, function()
        if card.Parent then
            TweenService:Create(card, TweenInfo.new(0.25), { Position = UDim2.new(0.5, 0, 0, -90) }):Play()
            task.wait(0.3)
            card:Destroy()
        end
    end)
end

local function jumpscare(by)
    local root = Instance.new("Frame")
    root.Name = "ScriptlyJumpscare"
    root.Size = UDim2.fromScale(1, 1)
    root.BackgroundColor3 = Color3.fromRGB(20, 0, 6)
    root.BorderSizePixel = 0
    root.ZIndex = 10
    root.Parent = gui

    local face = "\u{25C9}     \u{25C9}\n\n   \u{2584}\u{2584}\u{2584}\n  \u{2580}\u{2588}\u{2588}\u{2588}\u{2588}\u{2588}\u{2580}"
    local layers = {
        { RED, 0.5, -3 }, { CYAN, 0.55, 3 }, { Color3.fromRGB(255, 235, 235), 0, 0 },
    }
    for _, layer in ipairs(layers) do
        label(root, face, {
            Font = Enum.Font.Code, TextSize = 52, TextColor3 = layer[1], TextTransparency = layer[2],
            TextXAlignment = Enum.TextXAlignment.Center,
            AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, layer[3], 0.42, 0),
            Size = UDim2.new(1, 0, 0.6, 0), ZIndex = 11,
        })
    end
    label(root, "YOU HAVE BEEN SCRIPTLY'D  //  628", {
        Font = LOGO, TextSize = 24, TextColor3 = RED, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center,
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.78), Size = UDim2.new(1, -30, 0, 40), ZIndex = 11,
    })
    label(root, "TRIGGERED BY " .. string.upper(tostring(by or "628")), {
        TextSize = 11, TextColor3 = Color3.fromRGB(190, 95, 105), TextXAlignment = Enum.TextXAlignment.Center,
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.86), Size = UDim2.new(1, -30, 0, 20), ZIndex = 11,
    })
    task.delay(1.8, function()
        if root.Parent then
            TweenService:Create(root, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
            task.wait(0.35)
            root:Destroy()
        end
    end)
end

local function confetti()
    local palette = { CYAN, PINK, Color3.new(1, 1, 1), CYAN:Lerp(Color3.new(1, 1, 1), 0.5), PINK:Lerp(Color3.new(1, 1, 1), 0.5) }
    for _ = 1, 46 do
        local p = Instance.new("Frame")
        p.BorderSizePixel = 0
        p.BackgroundColor3 = palette[math.random(1, #palette)]
        p.Size = UDim2.fromOffset(math.random(3, 7), math.random(8, 16))
        p.Position = UDim2.new(math.random(), 0, -0.08, 0)
        p.Rotation = math.random(0, 180)
        p.Parent = gui
        local endX = p.Position.X.Scale + (math.random(-15, 15) / 100)
        TweenService:Create(p, TweenInfo.new(math.random(18, 32) / 10, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Position = UDim2.new(endX, 0, 1.12, 0),
            Rotation = p.Rotation + math.random(240, 620),
        }):Play()
        task.delay(3.4, function() p:Destroy() end)
    end
end

local remotes = ReplicatedStorage:WaitForChild("Scriptly628Remotes", 30)
if not remotes then
    warn("[Scriptly 628 Effects] Server bridge not found. Is ScriptlyServer.server.lua installed?")
    return
end
local event = remotes:WaitForChild("Command", 10)
if not event then
    warn("[Scriptly 628 Effects] Command event missing.")
    return
end

event.OnClientEvent:Connect(function(action, data)
    if typeof(data) ~= "table" then data = {} end
    if action == "Announcement" then
        announce(data.message, data.by)
    elseif action == "Jumpscare" then
        jumpscare(data.by)
    elseif action == "Confetti" then
        confetti()
    end
end)
print("[Scriptly 628 Effects] Receiver ready for " .. player.Name)
