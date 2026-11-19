-- ============================================================================
--  SCRIPTLY // 628  -  DEV CONSOLE   (retro-cyber build 6.28.1)
-- ============================================================================
--  Run as a LocalScript (StarterPlayerScripts) or paste into your executor.
--  Built for experiences you own or are authorised to test:
--    * local tools run for the experience owner, in Studio, or for developers
--      confirmed by ScriptlyServer.server.lua (user allowlist / group rank);
--    * aim assist only targets parts/models tagged "ScriptlyTarget";
--    * server actions are a fixed, validated list - no arbitrary Lua runs.
-- ============================================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local CollectionService = game:GetService("CollectionService")
local Stats = game:GetService("Stats")

local player = Players.LocalPlayer
if not player then
    warn("[Scriptly 628] LocalPlayer is unavailable. Run this from a client context.")
    return
end

-- Running the script again replaces the previous copy instead of stacking up.
pcall(function()
    if type(_G) == "table" and type(_G.Scriptly628_Cleanup) == "function" then
        _G.Scriptly628_Cleanup()
    end
end)

local playerGui = player:WaitForChild("PlayerGui")
local previousGui = playerGui:FindFirstChild("Scriptly628")
if previousGui then previousGui:Destroy() end

local CFG = {
    VERSION = "6.28.1",
    REMOTES = "Scriptly628Remotes",
    TAG = "ScriptlyTarget",
    TOGGLE_KEY = Enum.KeyCode.RightShift,
    DESIGN_W = 840,
    DESIGN_H = 548,
}

-- Shared state. Everything mutable lives here to keep the top-level local count low.
local S = {
    alive = true,
    gui = nil, scroller = nil, main = nil,
    conns = {}, tabConns = {},
    tab = "MOVEMENT", visible = true,
    fly = false, flySpeed = 58, flyUp = false, flyDown = false,
    noclip = false, noclipParts = {}, bunny = false, spin = false,
    esp = false, npcEsp = false, aim = false, fullbright = false,
    freeze = false, ghost = false,
    playerHL = {}, npcHL = {}, toasts = {}, toastId = 0, glitch = {},
    fps = 60, defaultFov = 70,
}

local function track(conn)
    S.conns[#S.conns + 1] = conn
    return conn
end

-- ---------------------------------------------------------------------------
--  Access + server link
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
--  Palette, fonts, theme bindings
-- ---------------------------------------------------------------------------
local C = {
    bg = Color3.fromRGB(6, 7, 16),
    panel = Color3.fromRGB(10, 12, 27),
    card = Color3.fromRGB(14, 17, 37),
    cardHi = Color3.fromRGB(22, 27, 56),
    line = Color3.fromRGB(34, 40, 78),
    text = Color3.fromRGB(226, 233, 255),
    muted = Color3.fromRGB(118, 128, 170),
    white = Color3.fromRGB(255, 255, 255),
    ok = Color3.fromRGB(60, 255, 150),
    warn = Color3.fromRGB(255, 196, 64),
    bad = Color3.fromRGB(255, 72, 104),
}

-- Theme: a = primary neon, b = secondary neon.
local T = { a = Color3.fromRGB(0, 240, 255), b = Color3.fromRGB(255, 46, 176) }

local function pickFont(name, fallback)
    local ok, font = pcall(function() return Enum.Font[name] end)
    if ok and font then return font end
    return fallback
end
local F = {
    logo = pickFont("Arcade", Enum.Font.Code),
    head = pickFont("Sarpanch", Enum.Font.Code),
    body = pickFont("RobotoMono", Enum.Font.Code),
    code = Enum.Font.Code,
}

local THEME_KEYS = { a = true, b = true, grad = true, loop = true, dim = true, dimb = true }
local NON_COLOR_KEYS = { Text = true, Name = true, PlaceholderText = true }
local bindings = {}

local function themeValue(which)
    if which == "a" then
        return T.a
    elseif which == "b" then
        return T.b
    elseif which == "grad" then
        return ColorSequence.new(T.a, T.b)
    elseif which == "loop" then
        return ColorSequence.new({
            ColorSequenceKeypoint.new(0, T.a),
            ColorSequenceKeypoint.new(0.5, T.b),
            ColorSequenceKeypoint.new(1, T.a),
        })
    elseif which == "dim" then
        return T.a:Lerp(C.bg, 0.84)
    elseif which == "dimb" then
        return T.b:Lerp(C.bg, 0.84)
    end
    return T.a
end

local function bind(inst, prop, which)
    bindings[#bindings + 1] = { inst, prop, which }
    inst[prop] = themeValue(which)
    return inst
end

-- Instance factory. A property value of "a" / "b" / "grad" / "loop" / "dim" /
-- "dimb" is bound to the active theme and follows theme changes.
local function new(class, props, parent)
    local inst = Instance.new(class)
    if props then
        for key, value in pairs(props) do
            if type(value) == "string" and THEME_KEYS[value] and not NON_COLOR_KEYS[key] then
                bind(inst, key, value)
            else
                inst[key] = value
            end
        end
    end
    if parent then inst.Parent = parent end
    return inst
end

local function applyTheme(a, b)
    T.a, T.b = a, b
    local alive = {}
    for _, item in ipairs(bindings) do
        local inst = item[1]
        if S.gui and inst.Parent ~= nil and inst:IsDescendantOf(S.gui) then
            inst[item[2]] = themeValue(item[3])
            alive[#alive + 1] = item
        end
    end
    bindings = alive
end

local function tween(inst, seconds, props, style, direction)
    local info = TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out)
    local t = TweenService:Create(inst, info, props)
    t:Play()
    return t
end

-- ---------------------------------------------------------------------------
--  Root gui
-- ---------------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "Six Scriptly"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 900
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui
S.gui = gui

-- ---------------------------------------------------------------------------
--  UI primitives
-- ---------------------------------------------------------------------------
local UI = {}

function UI.viewport()
    local cam = workspace.CurrentCamera
    if cam and cam.ViewportSize then return cam.ViewportSize end
    return Vector2.new(1280, 720)
end

function UI.fitScale()
    local vp = UI.viewport()
    return math.clamp(math.min(vp.X / (CFG.DESIGN_W + 40), vp.Y / (CFG.DESIGN_H + 40)), 0.5, 1)
end

function UI.stroke(parent, color, transparency, thickness)
    return new("UIStroke", {
        Color = color,
        Transparency = transparency or 0,
        Thickness = thickness or 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, parent)
end

function UI.frame(parent, props)
    local p = { BackgroundColor3 = C.card, BorderSizePixel = 0 }
    for key, value in pairs(props or {}) do p[key] = value end
    return new("Frame", p, parent)
end

function UI.text(parent, text, props)
    local p = {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Text = text,
        Font = F.body,
        TextSize = 13,
        TextColor3 = C.text,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        Size = UDim2.new(1, 0, 0, 20),
    }
    for key, value in pairs(props or {}) do p[key] = value end
    return new("TextLabel", p, parent)
end

-- HUD corner brackets that sit just outside the parent's edge.
function UI.brackets(parent, length, thickness, offset, color)
    local corners = { { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } }
    for _, c in ipairs(corners) do
        local ax, ay = c[1], c[2]
        local ox = (ax == 0) and -offset or offset
        local oy = (ay == 0) and -offset or offset
        new("Frame", {
            BorderSizePixel = 0, BackgroundColor3 = color,
            AnchorPoint = Vector2.new(ax, ay),
            Position = UDim2.new(ax, ox, ay, oy),
            Size = UDim2.fromOffset(length, thickness),
        }, parent)
        new("Frame", {
            BorderSizePixel = 0, BackgroundColor3 = color,
            AnchorPoint = Vector2.new(ax, ay),
            Position = UDim2.new(ax, ox, ay, oy),
            Size = UDim2.fromOffset(thickness, length),
        }, parent)
    end
end

-- CRT scanlines (thin horizontal bars) clipped to the parent.
function UI.scanlines(parent, count, transparency, color)
    local holder = new("Frame", {
        Name = "Scanlines", BackgroundTransparency = 1, BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1), ClipsDescendants = true, ZIndex = 40,
    }, parent)
    for i = 0, count - 1 do
        new("Frame", {
            BorderSizePixel = 0, BackgroundColor3 = color or C.white,
            BackgroundTransparency = transparency,
            Size = UDim2.new(1, 0, 0, 1), Position = UDim2.new(0, 0, i / count, 0),
        }, holder)
    end
    return holder
end

-- Slow light band that sweeps down a panel.
function UI.sweep(parent)
    local holder = new("Frame", {
        Name = "Sweep", BackgroundTransparency = 1, BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1), ClipsDescendants = true, ZIndex = 41,
    }, parent)
    local bar = new("Frame", {
        BorderSizePixel = 0, BackgroundColor3 = "a",
        Size = UDim2.new(1, 0, 0.22, 0), Position = UDim2.fromScale(0, -0.3),
    }, holder)
    new("UIGradient", {
        Rotation = 90,
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(0.5, 0.93),
            NumberSequenceKeypoint.new(1, 1),
        }),
    }, bar)
    local info = TweenInfo.new(5.5, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1, false, 1.2)
    TweenService:Create(bar, info, { Position = UDim2.fromScale(0, 1.1) }):Play()
    return holder
end

-- Chromatic-aberration text: two tinted copies sit behind the main label and
-- jitter apart every few seconds.
function UI.glitch(parent, text, textSize, font, align, props)
    local holder = new("Frame", {
        BackgroundTransparency = 1, BorderSizePixel = 0,
        Size = props.Size, Position = props.Position, AnchorPoint = props.AnchorPoint or Vector2.new(0, 0),
    }, parent)
    local function layer(color, transparency, dx)
        return UI.text(holder, text, {
            Font = font, TextSize = textSize, TextColor3 = color, TextTransparency = transparency,
            TextXAlignment = align, Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(dx, 0),
        })
    end
    local c1 = layer("a", 0.45, -1)
    local c2 = layer("b", 0.45, 1)
    local main = layer(C.white, 0, 0)
    S.glitch[#S.glitch + 1] = { main = main, c1 = c1, c2 = c2 }
    return holder, main
end

function UI.button(parent, text, size, position, anchor)
    local b = new("TextButton", {
        AutoButtonColor = false, Text = text, Font = F.head, TextSize = 14,
        TextColor3 = "a", BackgroundColor3 = "dim", BorderSizePixel = 0,
        Size = size, Position = position, AnchorPoint = anchor or Vector2.new(0, 0),
    }, parent)
    local st = UI.stroke(b, "a", 0.4, 1)
    b.MouseEnter:Connect(function()
        tween(b, 0.1, { BackgroundColor3 = T.a:Lerp(C.bg, 0.62) })
        tween(st, 0.1, { Transparency = 0 })
    end)
    b.MouseLeave:Connect(function()
        tween(b, 0.14, { BackgroundColor3 = themeValue("dim") })
        tween(st, 0.14, { Transparency = 0.4 })
    end)
    b.MouseButton1Down:Connect(function()
        tween(b, 0.05, { BackgroundColor3 = T.a:Lerp(C.bg, 0.4) })
    end)
    b.MouseButton1Up:Connect(function()
        tween(b, 0.12, { BackgroundColor3 = themeValue("dim") })
    end)
    return b
end

-- ---------------------------------------------------------------------------
--  Toast notifications (top-right stack)
-- ---------------------------------------------------------------------------
local toastRoot = new("Frame", {
    Name = "Toasts", BackgroundTransparency = 1, BorderSizePixel = 0,
    AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 16),
    Size = UDim2.new(0, 330, 1, -32), ZIndex = 300,
}, gui)
new("UIListLayout", {
    Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder,
    HorizontalAlignment = Enum.HorizontalAlignment.Right,
    VerticalAlignment = Enum.VerticalAlignment.Top,
}, toastRoot)

local function toast(message, kind, title, seconds)
    if not S.alive then return end
    message = tostring(message or "")
    seconds = seconds or 3.6
    local color = "a"
    if kind == "ok" then color = C.ok elseif kind == "warn" then color = C.warn elseif kind == "bad" then color = C.bad end

    local lines = math.min(3, math.max(1, math.ceil(#message / 38)))
    local height = 36 + lines * 15
    S.toastId = S.toastId + 1

    local holder = new("Frame", {
        BackgroundTransparency = 1, BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, height), LayoutOrder = S.toastId,
    }, toastRoot)
    local card = new("Frame", {
        BackgroundColor3 = C.panel, BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1), Position = UDim2.new(1, 60, 0, 0),
    }, holder)
    UI.stroke(card, color, 0.25, 1)
    new("Frame", { BackgroundColor3 = color, BorderSizePixel = 0, Size = UDim2.new(0, 3, 1, 0) }, card)
    UI.text(card, string.upper(tostring(title or "SCRIPTLY 628")), {
        Font = F.head, TextSize = 12, TextColor3 = color,
        Position = UDim2.fromOffset(14, 5), Size = UDim2.new(1, -24, 0, 16),
    })
    UI.text(card, message, {
        TextSize = 12, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top,
        Position = UDim2.fromOffset(14, 23), Size = UDim2.new(1, -24, 1, -28),
    })
    local bar = new("Frame", {
        BackgroundColor3 = color, BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 2),
    }, card)

    tween(card, 0.3, { Position = UDim2.new(0, 0, 0, 0) }, Enum.EasingStyle.Back)
    tween(bar, seconds, { Size = UDim2.new(0, 0, 0, 2) }, Enum.EasingStyle.Linear)

    S.toasts[#S.toasts + 1] = holder
    while #S.toasts > 5 do
        local oldest = table.remove(S.toasts, 1)
        if oldest then oldest:Destroy() end
    end

    task.delay(seconds, function()
        if holder.Parent then
            tween(card, 0.25, { Position = UDim2.new(1, 60, 0, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
            task.wait(0.28)
            holder:Destroy()
        end
        for i = #S.toasts, 1, -1 do
            if S.toasts[i] == holder then table.remove(S.toasts, i) end
        end
    end)
end

-- ---------------------------------------------------------------------------
--  Screen effects
-- ---------------------------------------------------------------------------
local FX = {}

function FX.flash()
    local f = new("Frame", {
        Name = "ScriptlyFlash", Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.white,
        BackgroundTransparency = 0.02, BorderSizePixel = 0, ZIndex = 600,
    }, gui)
    tween(f, 1.1, { BackgroundTransparency = 1 })
    task.delay(1.2, function() f:Destroy() end)
end

function FX.confetti()
    local palette = { T.a, T.b, C.white, T.a:Lerp(C.white, 0.55), T.b:Lerp(C.white, 0.55) }
    for _ = 1, 46 do
        local piece = new("Frame", {
            BorderSizePixel = 0, BackgroundColor3 = palette[math.random(1, #palette)],
            Size = UDim2.fromOffset(math.random(3, 7), math.random(8, 16)),
            Position = UDim2.new(math.random(), 0, -0.08, 0),
            Rotation = math.random(0, 180), ZIndex = 550,
        }, gui)
        local endX = piece.Position.X.Scale + (math.random(-15, 15) / 100)
        tween(piece, math.random(18, 32) / 10, {
            Position = UDim2.new(endX, 0, 1.12, 0),
            Rotation = piece.Rotation + math.random(240, 620),
        }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
        task.delay(3.4, function() piece:Destroy() end)
    end
end

function FX.jumpscare(by)
    local red = Color3.fromRGB(255, 40, 70)
    local root = new("Frame", {
        Name = "ScriptlyJumpscare", Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.fromRGB(20, 0, 6), BorderSizePixel = 0, ZIndex = 700,
    }, gui)
    UI.scanlines(root, 96, 0.9, red)

    local glow = new("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.44),
        Size = UDim2.fromOffset(340, 250), BackgroundColor3 = Color3.fromRGB(60, 0, 12), BorderSizePixel = 0,
    }, root)
    UI.stroke(glow, red, 0, 3)
    UI.brackets(glow, 26, 3, 8, red)
    local face = "\u{25C9}     \u{25C9}\n\n   \u{2584}\u{2584}\u{2584}\n  \u{2580}\u{2588}\u{2588}\u{2588}\u{2588}\u{2588}\u{2580}"
    for _, layer in ipairs({ { red, 0.5, -3 }, { Color3.fromRGB(0, 240, 255), 0.55, 3 }, { Color3.fromRGB(255, 235, 235), 0, 0 } }) do
        UI.text(glow, face, {
            Font = F.code, TextSize = 44, TextColor3 = layer[1], TextTransparency = layer[2],
            TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1),
            Position = UDim2.fromOffset(layer[3], 0),
        })
    end
    UI.text(root, "haha! u just got pwned and now u leaked ur address and network and webcam and everythinggg", {
        Font = F.logo, TextSize = 24, TextColor3 = red, TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Center,
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.78), Size = UDim2.new(1, -30, 0, 40),
    })
    UI.text(root, "TRIGGERED BY " .. string.upper(tostring(by or "628")), {
        Font = F.code, TextSize = 11, TextColor3 = Color3.fromRGB(190, 95, 105),
        TextXAlignment = Enum.TextXAlignment.Center,
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.86), Size = UDim2.new(1, -30, 0, 20),
    })

    task.spawn(function()
        for _ = 1, 14 do
            if not glow.Parent then return end
            glow.Position = UDim2.new(0.5, math.random(-9, 9), 0.44, math.random(-9, 9))
            task.wait(0.05)
        end
    end)
    task.delay(1.75, function()
        if root.Parent then
            tween(root, 0.35, { BackgroundTransparency = 1 })
            task.wait(0.4)
            root:Destroy()
        end
    end)
end

-- ---------------------------------------------------------------------------
--  Movement (local, client-side tests)
-- ---------------------------------------------------------------------------
local M = {}

function M.parts()
    local character = player.Character
    if not character then return nil, nil end
    return character:FindFirstChildOfClass("Humanoid"), character:FindFirstChild("HumanoidRootPart")
end

function M.setSpeedJump(speed, jumpPower)
    local humanoid = M.parts()
    if not humanoid then
        toast("Character is not ready yet.", "warn")
        return false
    end
    humanoid.UseJumpPower = true
    if speed ~= nil then humanoid.WalkSpeed = math.clamp(tonumber(speed) or 16, 0, 150) end
    if jumpPower ~= nil then humanoid.JumpPower = math.clamp(tonumber(jumpPower) or 50, 0, 200) end
    return true
end

function M.stopFly()
    S.fly = false
    S.flyUp, S.flyDown = false, false
    if S.flyConn then S.flyConn:Disconnect() S.flyConn = nil end
    for _, key in ipairs({ "flyVel", "flyOri", "flyAtt" }) do
        if S[key] then S[key]:Destroy() S[key] = nil end
    end
    local humanoid = M.parts()
    if humanoid then
        humanoid.AutoRotate = S.flyAutoRotate ~= false
        humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
    end
    if S.flyPad then S.flyPad.Visible = false end
end

function M.flyStep()
    if not S.fly or not S.flyVel or not S.flyOri then return end
    local cam = workspace.CurrentCamera
    if not cam then return end

    local look, right = cam.CFrame.LookVector, cam.CFrame.RightVector
    local flatLook = Vector3.new(look.X, 0, look.Z)
    if flatLook.Magnitude < 0.01 then flatLook = Vector3.new(0, 0, -1) end
    flatLook = flatLook.Unit
    local flatRight = Vector3.new(right.X, 0, right.Z)
    if flatRight.Magnitude < 0.01 then flatRight = Vector3.new(1, 0, 0) end
    flatRight = flatRight.Unit

    local horizontal = Vector3.zero
    local vertical = Vector3.zero
    if not UserInputService:GetFocusedTextBox() then
        local down = function(code) return UserInputService:IsKeyDown(code) end
        if down(Enum.KeyCode.W) then horizontal = horizontal + flatLook end
        if down(Enum.KeyCode.S) then horizontal = horizontal - flatLook end
        if down(Enum.KeyCode.D) then horizontal = horizontal + flatRight end
        if down(Enum.KeyCode.A) then horizontal = horizontal - flatRight end
        if down(Enum.KeyCode.Space) then vertical = vertical + Vector3.yAxis end
        if down(Enum.KeyCode.LeftControl) or down(Enum.KeyCode.LeftShift) then vertical = vertical - Vector3.yAxis end
    end
    if S.flyUp then vertical = vertical + Vector3.yAxis end
    if S.flyDown then vertical = vertical - Vector3.yAxis end

    -- Thumbstick / gamepad / touch movement comes through Humanoid.MoveDirection.
    if horizontal.Magnitude < 0.01 then
        local humanoid = M.parts()
        if humanoid then
            local md = humanoid.MoveDirection
            horizontal = Vector3.new(md.X, 0, md.Z)
        end
    end

    local direction = horizontal + vertical
    if direction.Magnitude > 0 then
        direction = direction.Unit * S.flySpeed
    end
    S.flyVel.VectorVelocity = direction
    S.flyOri.CFrame = CFrame.lookAt(Vector3.zero, flatLook)
end

function M.startFly()
    local humanoid, root = M.parts()
    if not humanoid or not root then
        toast("Character is not ready yet.", "warn")
        return false
    end
    local autoRotate = humanoid.AutoRotate
    if S.fly then autoRotate = S.flyAutoRotate end
    M.stopFly()
    S.fly = true
    S.flyAutoRotate = autoRotate
    humanoid.AutoRotate = false

    S.flyAtt = new("Attachment", { Name = "ScriptlyFlyAttachment" }, root)
    S.flyVel = new("LinearVelocity", {
        Name = "ScriptlyFlyVelocity", Attachment0 = S.flyAtt,
        RelativeTo = Enum.ActuatorRelativeTo.World,
        VelocityConstraintMode = Enum.VelocityConstraintMode.Vector,
        VectorVelocity = Vector3.zero, MaxForce = 1000000,
    }, root)
    S.flyOri = new("AlignOrientation", {
        Name = "ScriptlyFlyOrientation", Attachment0 = S.flyAtt,
        Mode = Enum.OrientationAlignmentMode.OneAttachment,
        Responsiveness = 18, MaxTorque = 1000000,
    }, root)
    humanoid:ChangeState(Enum.HumanoidStateType.Physics)
    S.flyConn = RunService.RenderStepped:Connect(M.flyStep)
    if S.flyPad and UserInputService.TouchEnabled then S.flyPad.Visible = true end
    return true
end

function M.setFly(on)
    if on then M.startFly() else M.stopFly() end
end

function M.setNoclip(on)
    S.noclip = on
    if S.noclipConn then S.noclipConn:Disconnect() S.noclipConn = nil end
    if on then
        S.noclipParts = {}
        S.noclipConn = RunService.Stepped:Connect(function()
            local character = player.Character
            if not character then return end
            for _, item in ipairs(character:GetDescendants()) do
                if item:IsA("BasePart") then
                    if S.noclipParts[item] == nil then S.noclipParts[item] = item.CanCollide end
                    item.CanCollide = false
                end
            end
        end)
    else
        for part, old in pairs(S.noclipParts) do
            if part and part.Parent then part.CanCollide = old end
        end
        S.noclipParts = {}
    end
end

function M.setBunny(on)
    S.bunny = on
    if S.bunnyConn then S.bunnyConn:Disconnect() S.bunnyConn = nil end
    if on then
        local last = 0
        S.bunnyConn = RunService.Heartbeat:Connect(function()
            local humanoid = M.parts()
            if humanoid and humanoid.FloorMaterial ~= Enum.Material.Air and os.clock() - last > 0.22 then
                humanoid.Jump = true
                last = os.clock()
            end
        end)
    end
end

function M.setSpin(on)
    S.spin = on
    if S.spinAng then S.spinAng:Destroy() S.spinAng = nil end
    if S.spinAtt then S.spinAtt:Destroy() S.spinAtt = nil end
    if on then
        local _, root = M.parts()
        if not root then
            S.spin = false
            toast("Character is not ready yet.", "warn")
            return
        end
        S.spinAtt = new("Attachment", {}, root)
        S.spinAng = new("AngularVelocity", {
            Attachment0 = S.spinAtt, RelativeTo = Enum.ActuatorRelativeTo.World,
            AngularVelocity = Vector3.new(0, 13, 0), MaxTorque = 1000000,
        }, root)
    end
end

function M.launch()
    local _, root = M.parts()
    if root then root:ApplyImpulse(Vector3.new(0, root.AssemblyMass * 125, 0)) end
end

function M.resetAll()
    M.setSpeedJump(16, 50)
    if S.fly then M.stopFly() end
    if S.noclip then M.setNoclip(false) end
    if S.bunny then M.setBunny(false) end
    if S.spin then M.setSpin(false) end
    if link.authorized then sendServer("ResetMovement") end
end

-- ---------------------------------------------------------------------------
--  Visuals (ESP / NPC aim / lighting / FOV)
-- ---------------------------------------------------------------------------
local V = {}

local hlFolder = new("Folder", { Name = "Highlights" }, gui)

local function clearHighlights(map)
    for key, highlight in pairs(map) do
        if highlight then highlight:Destroy() end
        map[key] = nil
    end
end

function V.addPlayerHighlight(target)
    local character = target.Character
    if not character or S.playerHL[character] then return end
    S.playerHL[character] = new("Highlight", {
        Name = "ScriptlyPlayerESP", Adornee = character,
        FillColor = "b", OutlineColor = "a",
        FillTransparency = 0.82, OutlineTransparency = 0.05,
        DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
    }, hlFolder)
end

function V.setPlayerEsp(on)
    S.esp = on
    clearHighlights(S.playerHL)
    if on then
        for _, other in ipairs(Players:GetPlayers()) do
            if other ~= player then V.addPlayerHighlight(other) end
        end
    end
end

function V.refreshNpcEsp()
    clearHighlights(S.npcHL)
    if not S.npcEsp then return end
    for _, target in ipairs(CollectionService:GetTagged(CFG.TAG)) do
        local model = target:IsA("Model") and target or target:FindFirstAncestorOfClass("Model")
        if model and not S.npcHL[model] then
            S.npcHL[model] = new("Highlight", {
                Name = "ScriptlyNpcESP", Adornee = model,
                FillColor = C.ok, OutlineColor = Color3.fromRGB(190, 255, 215),
                FillTransparency = 0.82, OutlineTransparency = 0,
                DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
            }, hlFolder)
        end
    end
end

function V.setNpcEsp(on)
    S.npcEsp = on
    V.refreshNpcEsp()
end

-- Only models/parts explicitly tagged ScriptlyTarget are considered. Players never are.
function V.setAim(on)
    S.aim = on
    if S.aimConn then S.aimConn:Disconnect() S.aimConn = nil end
    if not on then return end
    S.aimConn = RunService.RenderStepped:Connect(function()
        local cam = workspace.CurrentCamera
        if not cam then return end
        local bestPart = nil
        local bestAngle = math.rad(24)
        local origin = cam.CFrame.Position
        local currentLook = cam.CFrame.LookVector

        for _, target in ipairs(CollectionService:GetTagged(CFG.TAG)) do
            local model = target:IsA("Model") and target or target:FindFirstAncestorOfClass("Model")
            local part = nil
            if model then
                part = model:FindFirstChild("Head") or model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")
            elseif target:IsA("BasePart") then
                part = target
            end
            if part and part:IsA("BasePart") then
                local offset = part.Position - origin
                if offset.Magnitude <= 350 and offset.Magnitude > 0 then
                    local angle = math.acos(math.clamp(currentLook:Dot(offset.Unit), -1, 1))
                    if angle < bestAngle then
                        bestAngle = angle
                        bestPart = part
                    end
                end
            end
        end

        if bestPart then
            local desired = CFrame.lookAt(origin, bestPart.Position)
            cam.CFrame = cam.CFrame:Lerp(desired, 0.16)
        end
    end)
end

function V.setFullbright(on)
    S.fullbright = on
    if on then
        if not S.savedLighting then
            S.savedLighting = {
                Brightness = Lighting.Brightness, Ambient = Lighting.Ambient,
                OutdoorAmbient = Lighting.OutdoorAmbient, ClockTime = Lighting.ClockTime,
                FogEnd = Lighting.FogEnd, GlobalShadows = Lighting.GlobalShadows,
            }
        end
        Lighting.Brightness = 3
        Lighting.Ambient = Color3.fromRGB(210, 230, 255)
        Lighting.OutdoorAmbient = Color3.fromRGB(210, 230, 255)
        Lighting.ClockTime = 14
        Lighting.FogEnd = 100000
        Lighting.GlobalShadows = false
    elseif S.savedLighting then
        for property, value in pairs(S.savedLighting) do
            Lighting[property] = value
        end
        S.savedLighting = nil
    end
end

function V.setFov(value)
    local cam = workspace.CurrentCamera
    if cam then cam.FieldOfView = value end
end

function V.getFov()
    local cam = workspace.CurrentCamera
    return cam and cam.FieldOfView or S.defaultFov
end

do
    local cam = workspace.CurrentCamera
    S.defaultFov = cam and cam.FieldOfView or 70
end

-- ---------------------------------------------------------------------------
--  Boot sequence (synthwave horizon + terminal log). Click or press any key to skip.
-- ---------------------------------------------------------------------------
local function runBoot()
    local vp = UI.viewport()
    local boot = new("CanvasGroup", {
        Name = "BootScreen", BackgroundColor3 = Color3.fromRGB(8, 4, 20), BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1), ZIndex = 1000, GroupTransparency = 0,
    }, gui)
    new("UIGradient", {
        Rotation = 90,
        Color = ColorSequence.new(Color3.fromRGB(32, 8, 60), Color3.fromRGB(5, 3, 14)),
    }, boot)

    -- Sun, cut by stripes.
    local horizonY = 0.58
    local sunSize = math.clamp(vp.Y * 0.34, 110, 300)
    local sun = new("Frame", {
        BorderSizePixel = 0, BackgroundColor3 = C.white, ZIndex = 1,
        AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, horizonY, 36),
        Size = UDim2.fromOffset(sunSize, sunSize),
    }, boot)
    new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, sun)
    new("UIGradient", {
        Rotation = 90,
        Color = ColorSequence.new(Color3.fromRGB(255, 214, 80), Color3.fromRGB(255, 40, 160)),
    }, sun)
    local stripes = { { 0.60, 0.012 }, { 0.68, 0.02 }, { 0.76, 0.03 }, { 0.84, 0.042 }, { 0.92, 0.055 } }
    for _, s in ipairs(stripes) do
        local f, h = s[1], s[2]
        local chord = 2 * math.sqrt(math.max(0, 1 - (2 * f - 1) ^ 2))
        new("Frame", {
            BorderSizePixel = 0, BackgroundColor3 = Color3.fromRGB(26, 7, 50), ZIndex = 2,
            AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, f),
            Size = UDim2.new(chord, 2, h, 0),
        }, sun)
    end

    -- Ground with perspective grid.
    local ground = new("Frame", {
        BorderSizePixel = 0, BackgroundColor3 = Color3.fromRGB(14, 5, 34), ZIndex = 3,
        Position = UDim2.fromScale(0, horizonY), Size = UDim2.fromScale(1, 1 - horizonY), ClipsDescendants = true,
    }, boot)
    new("UIGradient", {
        Rotation = 90,
        Color = ColorSequence.new(Color3.fromRGB(30, 8, 62), Color3.fromRGB(5, 3, 14)),
    }, ground)
    local groundH = vp.Y * (1 - horizonY)
    for i = 1, 10 do
        local y = (i / 10) ^ 2.2
        new("Frame", {
            BorderSizePixel = 0, BackgroundColor3 = "a", BackgroundTransparency = 0.55 + (1 - y) * 0.25,
            Position = UDim2.new(0, 0, y, 0), Size = UDim2.new(1, 0, 0, 1),
        }, ground)
    end
    for k = -14, 14 do
        local dx = k * (vp.X / 9)
        local length = math.sqrt(dx * dx + groundH * groundH)
        new("Frame", {
            BorderSizePixel = 0, BackgroundColor3 = "a", BackgroundTransparency = 0.7,
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromOffset(vp.X / 2 + dx / 2, groundH / 2),
            Size = UDim2.fromOffset(1, length),
            Rotation = -math.deg(math.atan2(dx, groundH)),
        }, ground)
    end
    new("Frame", { BorderSizePixel = 0, BackgroundColor3 = "a", BackgroundTransparency = 0.8, Size = UDim2.new(1, 0, 0, 7) }, ground)
    new("Frame", { BorderSizePixel = 0, BackgroundColor3 = "a", Size = UDim2.new(1, 0, 0, 2) }, ground)

    -- Logo.
    local logoSize = math.clamp(math.floor(vp.Y / 11), 26, 64)
    UI.glitch(boot, "SCRIPTLY", logoSize, F.logo, Enum.TextXAlignment.Center, {
        AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.1), Size = UDim2.new(0.9, 0, 0, logoSize + 10),
    })
    UI.text(boot, "//  6 2 8  //  DEV CONSOLE  //  BUILD " .. CFG.VERSION, {
        Font = F.head, TextSize = 14, TextColor3 = "a", TextXAlignment = Enum.TextXAlignment.Center,
        AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.1, logoSize + 14), Size = UDim2.new(0.9, 0, 0, 20),
    })

    -- Terminal log.
    local logBox = new("Frame", {
        BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 5,
        AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 24, 1, -64), Size = UDim2.new(0, 440, 0, 118),
    }, boot)
    new("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Bottom,
    }, logBox)
    local logCount = 0
    local function log(tag, message, color)
        logCount = logCount + 1
        local line = UI.text(logBox, "", {
            Font = F.body, TextSize = 12, RichText = true, Size = UDim2.new(1, 0, 0, 17), LayoutOrder = logCount,
        })
        local hex = string.format("#%02X%02X%02X", math.floor(color.R * 255), math.floor(color.G * 255), math.floor(color.B * 255))
        line.Text = string.format('<font color="%s">[%s]</font> %s', hex, tag, message)
    end

    -- Progress bar (segmented).
    local total = 28
    local barBox = new("Frame", {
        BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 5,
        AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -26), Size = UDim2.new(0, 420, 0, 14),
    }, boot)
    new("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder,
    }, barBox)
    local segments = {}
    for i = 1, total do
        segments[i] = new("Frame", {
            BorderSizePixel = 0, BackgroundColor3 = C.line, LayoutOrder = i,
            Size = UDim2.new(1 / total, -3, 1, 0),
        }, barBox)
    end
    local percent = UI.text(boot, "000%", {
        Font = F.head, TextSize = 14, TextColor3 = "a", ZIndex = 5, TextXAlignment = Enum.TextXAlignment.Left,
        AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0.5, 230, 1, -24), Size = UDim2.fromOffset(60, 18),
    })
    UI.text(boot, "628 SYSTEMS  //  PRIVATE TEST BUILD  //  CLICK OR PRESS ANY KEY TO SKIP", {
        Font = F.code, TextSize = 10, TextColor3 = C.muted, ZIndex = 5, TextXAlignment = Enum.TextXAlignment.Center,
        AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -6), Size = UDim2.new(0.9, 0, 0, 14),
    })
    UI.scanlines(boot, 110, 0.94, C.white)

    local skip = false
    local skipConn = UserInputService.InputBegan:Connect(function(input)
        local t = input.UserInputType
        if t == Enum.UserInputType.Keyboard or t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
            skip = true
        end
    end)

    local rig = "UNKNOWN"
    local humanoid = M.parts()
    if humanoid then rig = tostring(humanoid.RigType):gsub("Enum.HumanoidRigType.", "") end

        end,
        [10] = function() log(" OK ", "place " .. tostring(game.PlaceId) .. " // rig " .. string.upper(rig), C.ok) end,
        [15] = function()
            if link.authorized then
                log(" OK ", "server controller linked", C.ok)
            else
                log("WARN", "server controller offline // client mode", C.warn)
            end
        end,
        [20] = function() log(" OK ", string.format("interface calibrated // scale %.2f", UI.fitScale()), C.ok) end,
        [26] = function() log(" OK ", "SCRIPTLY-628 ready", T.a) end,
    }

    for i = 1, total do
        if skip then
            for j = i, total do segments[j].BackgroundColor3 = T.a end
            break
        end
        segments[i].BackgroundColor3 = T.a
        if lines[i] then lines[i]() end
        percent.Text = string.format("%03d%%", math.floor(i / total * 100))
        task.wait(0.058)
    end
    percent.Text = "100%"
    skipConn:Disconnect()
    task.wait(skip and 0.05 or 0.3)

    tween(boot, 0.4, { GroupTransparency = 1 })
    task.wait(0.42)
    boot:Destroy()
end

-- ---------------------------------------------------------------------------
--  Main window
-- ---------------------------------------------------------------------------
local W = {}   -- window parts + helpers

W.main = new("Frame", {
    Name = "MainWindow", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(CFG.DESIGN_W, CFG.DESIGN_H), BackgroundColor3 = C.bg,
    BorderSizePixel = 0, ZIndex = 10, Visible = false,
}, gui)
local main = W.main
S.main = main
W.scale = new("UIScale", { Scale = UI.fitScale() }, main)

local mainStroke = UI.stroke(main, "a", 0, 1.5)
W.borderGrad = new("UIGradient", { Color = "loop" }, mainStroke)
UI.brackets(main, 22, 2, 5, "a")
UI.scanlines(main, 54, 0.955, C.white)
UI.sweep(main)

-- Title bar ------------------------------------------------------------------
local titleBar = new("Frame", {
    Name = "TitleBar", BackgroundColor3 = C.panel, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 56),
}, main)
local titleLine = new("Frame", {
    BackgroundColor3 = C.white, BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 1),
    Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 2),
}, titleBar)
new("UIGradient", { Color = "grad" }, titleLine)

local logoBox = new("Frame", {
    BackgroundColor3 = "dim", BorderSizePixel = 0, Position = UDim2.fromOffset(14, 10), Size = UDim2.fromOffset(38, 36),
}, titleBar)
UI.stroke(logoBox, "a", 0, 1)
UI.text(logoBox, "628", {
    Font = F.logo, TextSize = 16, TextColor3 = "a", TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1),
})
UI.glitch(titleBar, "SCRIPTLY", 24, F.logo, Enum.TextXAlignment.Left, {
    Position = UDim2.fromOffset(64, 6), Size = UDim2.fromOffset(240, 28),
})
UI.text(titleBar, "DEV CONSOLE  //  BUILD " .. CFG.VERSION, {
    Font = F.code, TextSize = 10, TextColor3 = C.muted, Position = UDim2.fromOffset(65, 35), Size = UDim2.fromOffset(240, 14),
})

-- Status chip.
local chip = new("Frame", {
    BackgroundColor3 = C.bg, BorderSizePixel = 0, AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -58, 0.5, 0), Size = UDim2.fromOffset(222, 26),
}, titleBar)
local chipStroke = UI.stroke(chip, C.ok, 0.45, 1)
local chipDot = new("Frame", {
    BackgroundColor3 = C.ok, BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 0.5),
    Position = UDim2.new(0, 10, 0.5, 0), Size = UDim2.fromOffset(8, 8),
}, chip)
local chipText = UI.text(chip, "CHECKING", {
    Font = F.head, TextSize = 12, TextColor3 = C.ok, Position = UDim2.fromOffset(26, 0), Size = UDim2.new(1, -32, 1, 0),
    TextTruncate = Enum.TextTruncate.AtEnd,
})
TweenService:Create(chipDot, TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
    BackgroundTransparency = 0.7,
}):Play()

local closeBtn = new("TextButton", {
    AutoButtonColor = false, Text = "X", Font = F.head, TextSize = 16, TextColor3 = C.muted,
    BackgroundColor3 = C.bg, BorderSizePixel = 0, AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.fromOffset(32, 32),
}, titleBar)
local closeStroke = UI.stroke(closeBtn, C.line, 0, 1)
closeBtn.MouseEnter:Connect(function()
    tween(closeBtn, 0.1, { TextColor3 = C.bad })
    tween(closeStroke, 0.1, { Color = C.bad })
end)
closeBtn.MouseLeave:Connect(function()
    tween(closeBtn, 0.12, { TextColor3 = C.muted })
    tween(closeStroke, 0.12, { Color = C.line })
end)

local function updateBadge()
    local color, label
    if link.authorized then
        color, label = C.ok, "SERVER ONLINE"
    elseif userOwns then
        color, label = C.warn, "CLIENT MODE  /  SERVER OFFLINE"
    end
    chipText.Text = label
    chipText.TextColor3 = color
    chipDot.BackgroundColor3 = color
    chipStroke.Color = color
    if W.modeLabel then
        W.modeLabel.Text = "MODE   " .. (link.authorized and "SERVER" or (userOwns and "CLIENT" or "LOCKED"))
    end
end

-- Dragging (mouse + touch) ----------------------------------------------------
do
    local dragging, dragStart, startCenter = false, nil, nil
    titleBar.InputBegan:Connect(function(input)
        local t = input.UserInputType
        if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
            dragging = true
            dragStart = Vector2.new(input.Position.X, input.Position.Y)
            startCenter = main.AbsolutePosition + main.AbsoluteSize / 2
        end
    end)
    track(UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        local t = input.UserInputType
        if t == Enum.UserInputType.MouseMovement or t == Enum.UserInputType.Touch then
            local delta = Vector2.new(input.Position.X, input.Position.Y) - dragStart
            local vp = UI.viewport()
            local cx = math.clamp(startCenter.X + delta.X, 40, vp.X - 40)
            local cy = math.clamp(startCenter.Y + delta.Y, 40, vp.Y - 40)
            main.Position = UDim2.fromOffset(cx, cy)
        end
    end))
    track(UserInputService.InputEnded:Connect(function(input)
        local t = input.UserInputType
        if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then dragging = false end
    end))
end

-- Sidebar ---------------------------------------------------------------------
local sidebar = new("Frame", {
    Name = "Sidebar", BackgroundColor3 = C.panel, BorderSizePixel = 0,
    Position = UDim2.fromOffset(0, 56), Size = UDim2.new(0, 176, 1, -82),
}, main)
new("Frame", {
    BackgroundColor3 = C.line, BorderSizePixel = 0, AnchorPoint = Vector2.new(1, 0),
    Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0, 1, 1, 0),
}, sidebar)
UI.text(sidebar, "//  MODULES", {
    Font = F.head, TextSize = 12, TextColor3 = "a", Position = UDim2.fromOffset(16, 12), Size = UDim2.new(1, -24, 0, 18),
})

local TABS = {
    { id = "MOVEMENT", index = "01", title = "MOVEMENT", sub = "LOCOMOTION AND PHYSICS TESTS" },
    { id = "VISUALS", index = "02", title = "VISUALS", sub = "ESP, NPC TARGETING, LIGHTING, CAMERA" },
    { id = "SERVER", index = "03", title = "SERVER", sub = "SERVER-AUTHORITATIVE DEVELOPER ACTIONS" },
    { id = "WORLD + FUN", index = "04", title = "WORLD + FUN", sub = "LOCAL EFFECTS AND SERVER-WIDE CONTROLS" },
    { id = "THEMES", index = "05", title = "THEMES", sub = "INTERFACE COLOUR CUSTOMISATION" },
}
local navButtons = {}
for i, tab in ipairs(TABS) do
    local b = new("TextButton", {
        AutoButtonColor = false, Text = "", BackgroundColor3 = C.cardHi, BackgroundTransparency = 1,
        BorderSizePixel = 0, Position = UDim2.fromOffset(0, 40 + (i - 1) * 44), Size = UDim2.new(1, -1, 0, 42),
    }, sidebar)
    local activeBg = new("Frame", {
        BackgroundColor3 = "dim", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1),
    }, b)
    local bar = new("Frame", {
        BackgroundColor3 = "a", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(0, 3, 1, 0),
    }, b)
    local idx = UI.text(b, tab.index, {
        Font = F.code, TextSize = 11, TextColor3 = "a", TextTransparency = 0.55, Position = UDim2.fromOffset(16, 0),
        Size = UDim2.fromOffset(24, 42),
    })
    local name = UI.text(b, tab.title, {
        Font = F.head, TextSize = 15, TextTransparency = 0.3, Position = UDim2.fromOffset(44, 0), Size = UDim2.new(1, -50, 1, 0),
    })
    b.MouseEnter:Connect(function()
        if S.tab ~= tab.id then tween(b, 0.1, { BackgroundTransparency = 0.6 }) end
    end)
    b.MouseLeave:Connect(function()
        tween(b, 0.12, { BackgroundTransparency = 1 })
    end)
    navButtons[tab.id] = { button = b, bg = activeBg, bar = bar, idx = idx, name = name }
end

local info = UI.frame(sidebar, {
    BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, -8), Size = UDim2.new(1, 0, 0, 62),
})
new("Frame", { BackgroundColor3 = C.line, BorderSizePixel = 0, Size = UDim2.new(1, -1, 0, 1) }, info)
local function infoLine(y, text)
    return UI.text(info, text, {
        Font = F.code, TextSize = 10, TextColor3 = C.muted, Position = UDim2.fromOffset(16, y), Size = UDim2.new(1, -24, 0, 14),
        TextTruncate = Enum.TextTruncate.AtEnd,
    })
end
infoLine(8, "USER   " .. string.upper(player.Name))
infoLine(24, "PLACE  " .. tostring(game.PlaceId))
W.modeLabel = infoLine(40, "MODE   ...")

-- Page area ---------------------------------------------------------------------
local page = new("Frame", {
    Name = "Page", BackgroundTransparency = 1, BorderSizePixel = 0,
    Position = UDim2.fromOffset(176, 56), Size = UDim2.new(1, -176, 1, -82),
}, main)
W.pageTitle = UI.text(page, "MOVEMENT", {
    Font = F.logo, TextSize = 24, TextColor3 = "a", Position = UDim2.fromOffset(20, 10), Size = UDim2.new(1, -40, 0, 30),
})
W.pageSub = UI.text(page, "", {
    Font = F.code, TextSize = 11, TextColor3 = C.muted, Position = UDim2.fromOffset(21, 42), Size = UDim2.new(1, -40, 0, 16),
})
local pageLine = new("Frame", {
    BackgroundColor3 = C.white, BorderSizePixel = 0, Position = UDim2.fromOffset(20, 64), Size = UDim2.new(1, -40, 0, 1),
}, page)
new("UIGradient", {
    Color = "grad",
    Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }),
}, pageLine)

S.scroller = new("ScrollingFrame", {
    Name = "Content", BackgroundTransparency = 1, BorderSizePixel = 0,
    Position = UDim2.fromOffset(0, 72), Size = UDim2.new(1, 0, 1, -72),
    ScrollBarThickness = 4, ScrollBarImageColor3 = "a", CanvasSize = UDim2.new(0, 0, 0, 0),
    AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y,
    ElasticBehavior = Enum.ElasticBehavior.Never,
}, page)
new("UIPadding", {
    PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 14),
    PaddingLeft = UDim.new(0, 20), PaddingRight = UDim.new(0, 20),
}, S.scroller)
new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, S.scroller)

-- Status bar ------------------------------------------------------------------
local statusBar = new("Frame", {
    BackgroundColor3 = C.panel, BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 1),
    Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 26),
}, main)
new("Frame", { BackgroundColor3 = C.line, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 1) }, statusBar)
UI.text(statusBar, "[RSHIFT] TOGGLE HUB   //   DRAG TITLE BAR TO MOVE", {
    Font = F.code, TextSize = 10, TextColor3 = C.muted, Position = UDim2.fromOffset(16, 0), Size = UDim2.new(0.55, 0, 1, 0),
})
W.stats = UI.text(statusBar, "", {
    Font = F.code, TextSize = 10, TextColor3 = "a", TextXAlignment = Enum.TextXAlignment.Right,
    AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 0), Size = UDim2.new(0.45, 0, 1, 0),
})

-- Launcher (reopens the hub; also the way back in on touch devices) -----------
W.launcher = new("TextButton", {
    Name = "Launcher", AutoButtonColor = false, Text = "628", Font = F.logo, TextSize = 14, TextColor3 = "a",
    BackgroundColor3 = C.panel, BorderSizePixel = 0, AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(48, 40), ZIndex = 20, Visible = false,
}, gui)
UI.stroke(W.launcher, "a", 0.1, 1.5)
UI.brackets(W.launcher, 8, 2, 3, "b")

-- Touch fly pad ----------------------------------------------------------------
S.flyPad = new("Frame", {
    Name = "FlyPad", BackgroundTransparency = 1, BorderSizePixel = 0, AnchorPoint = Vector2.new(1, 1),
    Position = UDim2.new(1, -24, 1, -110), Size = UDim2.fromOffset(72, 150), ZIndex = 30, Visible = false,
}, gui)
for i, spec in ipairs({ { "UP", "flyUp" }, { "DN", "flyDown" } }) do
    local b = new("TextButton", {
        AutoButtonColor = false, Text = spec[1], Font = F.head, TextSize = 18, TextColor3 = "a",
        BackgroundColor3 = C.panel, BackgroundTransparency = 0.15, BorderSizePixel = 0,
        Position = UDim2.fromOffset(0, (i - 1) * 78), Size = UDim2.fromOffset(72, 72),
    }, S.flyPad)
    UI.stroke(b, "a", 0.1, 1.5)
    b.InputBegan:Connect(function(input)
        local t = input.UserInputType
        if t == Enum.UserInputType.Touch or t == Enum.UserInputType.MouseButton1 then S[spec[2]] = true end
    end)
    b.InputEnded:Connect(function(input)
        local t = input.UserInputType
        if t == Enum.UserInputType.Touch or t == Enum.UserInputType.MouseButton1 then S[spec[2]] = false end
    end)
end

function W.setVisible(visible)
    S.visible = visible
    main.Visible = visible
    W.launcher.Visible = not visible
end
closeBtn.MouseButton1Click:Connect(function() W.setVisible(false) end)
W.launcher.MouseButton1Click:Connect(function() W.setVisible(true) end)

-- ---------------------------------------------------------------------------
--  Row builders (cards inside the scroller)
-- ---------------------------------------------------------------------------
local rowIndex = 0

local function tabConn(signal, fn)
    local conn = signal:Connect(fn)
    S.tabConns[#S.tabConns + 1] = conn
    return conn
end

local function hoverStroke(target, stroke)
    target.MouseEnter:Connect(function()
        tween(stroke, 0.12, { Color = T.a:Lerp(C.line, 0.55) })
    end)
    target.MouseLeave:Connect(function()
        tween(stroke, 0.14, { Color = C.line })
    end)
end

function UI.card(height)
    rowIndex = rowIndex + 1
    local holder = new("Frame", {
        BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, height), LayoutOrder = rowIndex,
    }, S.scroller)
    local card = new("Frame", {
        BackgroundColor3 = C.card, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(18, 0),
    }, holder)
    local stroke = UI.stroke(card, C.line, 0, 1)
    local notch = new("Frame", {
        BackgroundColor3 = "a", BackgroundTransparency = 0.85, BorderSizePixel = 0, Size = UDim2.new(0, 3, 1, 0),
    }, card)
    task.delay(math.min(rowIndex * 0.03, 0.3), function()
        if card.Parent then tween(card, 0.22, { Position = UDim2.fromOffset(0, 0) }) end
    end)
    return card, notch, stroke
end

function UI.heading(card, title, desc, rightPad, xOff, singleLine)
    xOff = xOff or 16
    UI.text(card, title, {
        Font = F.head, TextSize = 15, Position = UDim2.fromOffset(xOff, 8), Size = UDim2.new(1, -(rightPad + xOff), 0, 18),
        TextTruncate = Enum.TextTruncate.AtEnd,
    })
    if desc and desc ~= "" then
        UI.text(card, desc, {
            TextSize = 11, TextColor3 = C.muted, TextWrapped = not singleLine, TextYAlignment = Enum.TextYAlignment.Top,
            Position = UDim2.fromOffset(xOff, 28), Size = UDim2.new(1, -(rightPad + xOff), 0, singleLine and 14 or 30),
            TextTruncate = singleLine and Enum.TextTruncate.AtEnd or Enum.TextTruncate.None,
        })
    end
end

function UI.section(text)
    rowIndex = rowIndex + 1
    local holder = new("Frame", {
        BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 26), LayoutOrder = rowIndex,
    }, S.scroller)
    UI.text(holder, "//  " .. text, {
        Font = F.head, TextSize = 13, TextColor3 = "a", Position = UDim2.fromOffset(0, 2), Size = UDim2.new(1, 0, 0, 18),
    })
    local line = new("Frame", {
        BackgroundColor3 = C.white, BorderSizePixel = 0, Position = UDim2.new(0, 0, 1, -3), Size = UDim2.new(1, 0, 0, 1),
    }, holder)
    new("UIGradient", {
        Color = "grad",
        Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) }),
    }, line)
end

function UI.banner(text, kind, buttonText, callback)
    local color = (kind == "bad" and C.bad) or (kind == "ok" and C.ok) or C.warn
    local card, notch, stroke = UI.card(52)
    notch.BackgroundColor3 = color
    notch.BackgroundTransparency = 0
    stroke.Color = color
    stroke.Transparency = 0.55
    UI.text(card, text, {
        TextSize = 12, TextColor3 = color, TextWrapped = true,
        Position = UDim2.fromOffset(16, 0), Size = UDim2.new(1, buttonText and -150 or -32, 1, 0),
    })
    if buttonText then
        local b = UI.button(card, buttonText, UDim2.fromOffset(100, 28), UDim2.new(1, -14, 0.5, 0), Vector2.new(1, 0.5))
        b.MouseButton1Click:Connect(callback)
    end
end

function UI.action(title, desc, buttonText, callback, open)
    local card, notch, stroke = UI.card(64)
    UI.heading(card, title, desc, 140)
    local b = UI.button(card, buttonText, UDim2.fromOffset(112, 30), UDim2.new(1, -16, 0.5, 0), Vector2.new(1, 0.5))
    hoverStroke(b, stroke)
    b.MouseButton1Click:Connect(function()
        if not open and not gate() then return end
        callback()
        tween(notch, 0.05, { BackgroundTransparency = 0 })
        tween(notch, 0.4, { BackgroundTransparency = 0.85 })
    end)
    return b
end

function UI.buttons(title, desc, list)
    local card, _, stroke = UI.card(88)
    UI.heading(card, title, desc, 16, nil, true)
    local x = 16
    for _, spec in ipairs(list) do
        local b = UI.button(card, spec[1], UDim2.fromOffset(spec[3] or 124, 30), UDim2.fromOffset(x, 48))
        x = x + (spec[3] or 124) + 10
        b.MouseButton1Click:Connect(function()
            if not gate() then return end
            spec[2]()
        end)
    end
    hoverStroke(card, stroke)
end

function UI.toggle(title, desc, get, set)
    local card, notch, stroke = UI.card(64)
    UI.heading(card, title, desc, 96)

    local track = new("Frame", {
        BackgroundColor3 = C.bg, BorderSizePixel = 0, AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -16, 0.5, 0), Size = UDim2.fromOffset(60, 26),
    }, card)
    UI.stroke(track, C.line, 0, 1)
    local fill = new("Frame", {
        BackgroundColor3 = "a", BackgroundTransparency = 0.7, BorderSizePixel = 0, Size = UDim2.new(0, 0, 1, 0),
    }, track)
    local knob = new("Frame", {
        BackgroundColor3 = "a", BackgroundTransparency = 0.5, BorderSizePixel = 0,
        Position = UDim2.fromOffset(3, 3), Size = UDim2.fromOffset(20, 20),
    }, track)
    local label = UI.text(track, "OFF", {
        Font = F.code, TextSize = 10, TextColor3 = C.muted, Position = UDim2.fromOffset(27, 0),
        Size = UDim2.fromOffset(30, 26), TextXAlignment = Enum.TextXAlignment.Center,
    })

    local function render(on, instant)
        local t = instant and 0 or 0.14
        tween(knob, t, { Position = UDim2.fromOffset(on and 37 or 3, 3), BackgroundTransparency = on and 0 or 0.5 })
        tween(fill, t, { Size = UDim2.new(on and 1 or 0, 0, 1, 0) })
        tween(notch, t, { BackgroundTransparency = on and 0 or 0.85 })
        label.Text = on and "ON" or "OFF"
        label.Position = UDim2.fromOffset(on and 4 or 27, 0)
        label.TextColor3 = on and C.white or C.muted
    end
    render(get() and true or false, true)

    local hit = new("TextButton", {
        Text = "", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 5,
    }, card)
    hoverStroke(hit, stroke)
    hit.MouseButton1Click:Connect(function()
        if not gate() then return end
        set(not get())
        render(get() and true or false, false)
    end)
end

function UI.slider(title, desc, min, max, get, onChange, format)
    local card, _, stroke = UI.card(80)
    UI.heading(card, title, desc, 120, nil, true)
    hoverStroke(card, stroke)

    local valueLabel = UI.text(card, "", {
        Font = F.head, TextSize = 17, TextColor3 = "a", TextXAlignment = Enum.TextXAlignment.Right,
        AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 8), Size = UDim2.fromOffset(100, 22),
    })
    local hit = new("TextButton", {
        Text = "", BackgroundTransparency = 1, BorderSizePixel = 0,
        Position = UDim2.fromOffset(16, 48), Size = UDim2.new(1, -32, 0, 26),
    }, card)
    local track = new("Frame", {
        BackgroundColor3 = C.bg, BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.new(1, 0, 0, 6),
    }, hit)
    UI.stroke(track, C.line, 0, 1)
    local fill = new("Frame", {
        BackgroundColor3 = "a", BorderSizePixel = 0, Size = UDim2.new(0, 0, 1, 0),
    }, track)
    local knob = new("Frame", {
        BackgroundColor3 = C.white, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.fromOffset(10, 18),
    }, track)
    UI.stroke(knob, "a", 0, 1)

    local function show(fraction)
        fraction = math.clamp(fraction, 0, 1)
        local value = math.floor(min + (max - min) * fraction + 0.5)
        fill.Size = UDim2.new(fraction, 0, 1, 0)
        knob.Position = UDim2.new(fraction, 0, 0.5, 0)
        valueLabel.Text = format and format(value) or tostring(value)
        return value
    end
    show((get() - min) / (max - min))

    local dragging = false
    local function fromInput(input)
        local width = math.max(track.AbsoluteSize.X, 1)
        local value = show((input.Position.X - track.AbsolutePosition.X) / width)
        onChange(value)
    end
    hit.InputBegan:Connect(function(input)
        local t = input.UserInputType
        if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
            if not gate() then return end
            dragging = true
            fromInput(input)
        end
    end)
    tabConn(UserInputService.InputChanged, function(input)
        if not dragging then return end
        local t = input.UserInputType
        if t == Enum.UserInputType.MouseMovement or t == Enum.UserInputType.Touch then fromInput(input) end
    end)
    tabConn(UserInputService.InputEnded, function(input)
        local t = input.UserInputType
        if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then dragging = false end
    end)
end

function UI.input(title, placeholder, buttonText, onSubmit)
    local card, _, stroke = UI.card(72)
    UI.text(card, title, {
        Font = F.head, TextSize = 15, Position = UDim2.fromOffset(16, 8), Size = UDim2.new(1, -32, 0, 18),
    })
    local box = new("TextBox", {
        ClearTextOnFocus = false, PlaceholderText = placeholder, Text = "", Font = F.body, TextSize = 12,
        TextColor3 = C.text, PlaceholderColor3 = C.muted, BackgroundColor3 = C.bg, BorderSizePixel = 0,
        TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(16, 34),
        Size = UDim2.new(1, buttonText and -148 or -32, 0, 30),
    }, card)
    new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }, box)
    local boxStroke = UI.stroke(box, C.line, 0, 1)
    box.Focused:Connect(function() tween(boxStroke, 0.1, { Color = T.a }) end)
    box.FocusLost:Connect(function(enterPressed)
        tween(boxStroke, 0.12, { Color = C.line })
        if enterPressed and onSubmit then onSubmit(box) end
    end)
    if buttonText and onSubmit then
        local b = UI.button(card, buttonText, UDim2.fromOffset(104, 30), UDim2.new(1, -16, 0, 34), Vector2.new(1, 0))
        b.MouseButton1Click:Connect(function() onSubmit(box) end)
    end
    hoverStroke(card, stroke)
    return box
end

function UI.themeRow(name, desc, a, b)
    local card, _, stroke = UI.card(64)
    local swatch = new("Frame", {
        BackgroundColor3 = C.white, BorderSizePixel = 0, Position = UDim2.fromOffset(16, 16), Size = UDim2.fromOffset(56, 32),
    }, card)
    new("UIGradient", { Color = ColorSequence.new(a, b) }, swatch)
    UI.stroke(swatch, C.line, 0, 1)
    UI.heading(card, name, desc, 140, 88)
    local button = UI.button(card, "APPLY", UDim2.fromOffset(112, 30), UDim2.new(1, -16, 0.5, 0), Vector2.new(1, 0.5))
    hoverStroke(button, stroke)
    button.MouseButton1Click:Connect(function()
        applyTheme(a, b)
        toast(name .. " applied.", "ok", "THEME")
    end)
end

-- ---------------------------------------------------------------------------
--  Tabs
-- ---------------------------------------------------------------------------
local Tabs = {}

Tabs["MOVEMENT"] = function()
    UI.section("FLIGHT AND PHYSICS")
    UI.toggle("FLIGHT MODE", "WASD / thumbstick to move, Space to rise, Ctrl or Shift to descend.", function() return S.fly end, M.setFly)
    UI.slider("FLIGHT SPEED", "Studs per second while flight is enabled.", 10, 150, function() return S.flySpeed end, function(v) S.flySpeed = v end)
    UI.toggle("NOCLIP", "Locally disables character-part collisions for movement testing.", function() return S.noclip end, M.setNoclip)
    UI.toggle("BUNNY HOP", "Automatically jumps whenever you touch the ground.", function() return S.bunny end, M.setBunny)
    UI.toggle("SPIN TEST", "Applies a local rotation force to your character.", function() return S.spin end, M.setSpin)

    UI.section("SPEED AND JUMP")
    UI.slider("WALK SPEED", "Local WalkSpeed override (default 16).", 0, 150, function()
        local h = M.parts()
        return h and h.WalkSpeed or 16
    end, function(v) M.setSpeedJump(v, nil) end)
    UI.slider("JUMP POWER", "Local JumpPower override (default 50).", 0, 200, function()
        local h = M.parts()
        return h and h.JumpPower or 50
    end, function(v) M.setSpeedJump(nil, v) end)
    UI.buttons("ANTI-CHEAT SIMULATION PRESETS", "One-click values for testing your own server-side checks.", {
        { "2X SPEED", function()
            if M.setSpeedJump(32, 50) then toast("Local speed test set to 32.", "info", "SCRIPTLY TEST") end
        end },
        { "SUPER JUMP", function()
            if M.setSpeedJump(16, 110) then toast("Local jump test set to 110.", "info", "SCRIPTLY TEST") end
        end },
        { "LAUNCH SELF", M.launch },
        { "RESET ALL", function()
            M.resetAll()
            W.buildTab("MOVEMENT")
        end },
    })
end

Tabs["VISUALS"] = function()
    UI.section("TARGETING AND ESP")
    UI.toggle("PLAYER ESP", "Local outlines for other player characters.", function() return S.esp end, V.setPlayerEsp)
    UI.toggle("NPC TARGET ESP", "Highlights only NPCs tagged ScriptlyTarget.", function() return S.npcEsp end, V.setNpcEsp)
    UI.toggle("NPC AIM TEST", "Camera assist locks only onto tagged NPC test dummies, never players.", function() return S.aim end, V.setAim)

    UI.section("LIGHTING AND CAMERA")
    UI.toggle("FULLBRIGHT", "Local lighting override. Toggle off to restore the saved lighting.", function() return S.fullbright end, V.setFullbright)
    UI.slider("FIELD OF VIEW", "Local camera field of view (default shown on reset).", 30, 120, V.getFov, V.setFov, function(v) return tostring(v) .. "\u{00B0}" end)
    UI.buttons("CAMERA TOOLS", "Reset the field of view or fire a local flash.", {
        { "RESET FOV", function()
            V.setFov(S.defaultFov)
            W.buildTab("VISUALS")
        end },
        { "FLASH TEST", FX.flash },
    })
end

Tabs["SERVER"] = function()
    if not link.authorized then
        UI.banner("SERVER LINK OFFLINE.  Install ScriptlyServer.server.lua in ServerScriptService, then retry.", "warn", "RETRY LINK", function()
            task.spawn(function()
                refreshLink()
                updateBadge()
                toast(link.authorized and "Server controller linked." or "Server controller still offline.", link.authorized and "ok" or "warn", "SERVER")
                if S.tab == "SERVER" then W.buildTab("SERVER") end
            end)
        end)
    end
    UI.section("SELF ACTIONS")
    UI.action("HEAL SELF", "Server restores your character to maximum health.", "HEAL", function() sendServer("Heal") end)
    UI.action("TELEPORT TO SPAWN", "Server moves your character to a SpawnLocation.", "TELEPORT", function() sendServer("TeleportSpawn") end)
    UI.action("RESPAWN SELF", "Server reloads your character.", "RESPAWN", function() sendServer("Respawn") end)
    UI.toggle("FREEZE SELF", "Server-side movement freeze.", function() return S.freeze end, function(on)
        if sendServer(on and "FreezeSelf" or "UnfreezeSelf") then S.freeze = on end
    end)
    UI.toggle("GHOST SELF", "Server changes your character transparency for everyone.", function() return S.ghost end, function(on)
        if sendServer(on and "GhostSelf" or "UnghostSelf") then S.ghost = on end
    end)
    UI.action("TEMP FORCEFIELD", "Server grants you a 12-second ForceField.", "GIVE", function() sendServer("ForceField") end)
    UI.action("FLOP TEST", "Server briefly puts your Humanoid into the Physics state.", "FLOP", function() sendServer("FlopSelf") end)

    UI.section("TELEPORT")
    UI.input("TELEPORT TO PLAYER", "Exact username or display name, then GO", "GO", function(box)
        if not gate() then return end
        sendServer("TeleportToPlayer", { target = box.Text })
    end)
end

Tabs["WORLD + FUN"] = function()
    UI.section("LOCAL EFFECTS (ONLY YOU SEE THESE)")
    UI.action("LOCAL JUMPSCARE", "Shows the jumpscare on your own screen only.", "SCARE ME", function() FX.jumpscare(player.DisplayName) end, true)
    UI.action("LOCAL CONFETTI", "Confetti effect visible only to you.", "PARTY", FX.confetti, true)
    UI.action("LOCAL ANNOUNCEMENT", "Display a local test notification.", "TEST", function()
        toast("Scriptly client effects are working.", "ok", "LOCAL TEST")
    end, true)

    UI.section("SERVER-WIDE CONTROLS  /  REQUIRES SERVER LINK")
    UI.action("LOW GRAVITY", "Changes workspace gravity for every player in this server.", "ACTIVATE", function() sendServer("LowGravityGlobal") end)
    UI.action("RESET GRAVITY", "Restores the gravity value saved at server start.", "RESET", function() sendServer("ResetGravityGlobal") end)
    UI.buttons("TIME OF DAY", "Changes Lighting.ClockTime on the server.", {
        { "DAY", function() sendServer("Day") end },
        { "NIGHT", function() sendServer("Night") end },
        { "RESET TIME", function() sendServer("ResetTime") end },
    })
    UI.action("SERVER JUMPSCARE", "Shows the Scriptly jumpscare to every player in this server.", "SCARE ALL", function() sendServer("ServerJumpscare") end)
    UI.action("SERVER CONFETTI", "Displays a confetti burst on every player's screen.", "PARTY", function() sendServer("ServerConfetti") end)
    UI.input("SERVER ANNOUNCEMENT", "Type a message to show every player...", "SEND", function(box)
        if not gate() then return end
        if sendServer("ServerAnnouncement", { message = box.Text }) then box.Text = "" end
    end)
end

Tabs["THEMES"] = function()
    UI.section("PRESETS")
    UI.themeRow("NEON GRID", "Cyan and magenta. The default retro-cyber look.", Color3.fromRGB(0, 240, 255), Color3.fromRGB(255, 46, 176))
    UI.themeRow("SYNTHWAVE", "Hot pink fading into electric violet.", Color3.fromRGB(255, 64, 200), Color3.fromRGB(120, 80, 255))
    UI.themeRow("MATRIX GREEN", "Classic terminal green.", Color3.fromRGB(0, 255, 125), Color3.fromRGB(0, 150, 90))
    UI.themeRow("TOXIC LIME", "Bright lime with a deep forest finish.", Color3.fromRGB(190, 255, 0), Color3.fromRGB(40, 140, 0))
    UI.themeRow("CYBER TEAL", "Cool neon teal with an ocean-blue edge.", Color3.fromRGB(0, 255, 220), Color3.fromRGB(0, 120, 200))
    UI.themeRow("AMBER TERMINAL", "Retro amber phosphor palette.", Color3.fromRGB(255, 190, 55), Color3.fromRGB(255, 110, 20))

    UI.section("CUSTOM GRADIENT")
    local first = UI.input("PRIMARY COLOUR", "Hex colour, for example #00F0FF", nil, nil)
    local second = UI.input("SECONDARY COLOUR", "Hex colour, for example #FF2EB0", nil, nil)
    UI.action("APPLY CUSTOM GRADIENT", "Uses the two hex colours entered above.", "APPLY", function()
        local function parseHex(value)
            value = string.gsub(value or "", "#", "")
            if #value ~= 6 or not string.match(value, "^%x%x%x%x%x%x$") then return nil end
            return Color3.fromRGB(
                tonumber(string.sub(value, 1, 2), 16),
                tonumber(string.sub(value, 3, 4), 16),
                tonumber(string.sub(value, 5, 6), 16)
            )
        end
        local a, b = parseHex(first.Text), parseHex(second.Text)
        if a and b then
            applyTheme(a, b)
            toast("Custom gradient applied.", "ok", "THEME")
        else
            toast("Invalid hex. Use six digits, for example #00F0FF.", "warn", "THEME")
        end
    end, true)
end

-- ---------------------------------------------------------------------------
--  Tab switching
-- ---------------------------------------------------------------------------
function W.buildTab(tabId)
    S.tab = tabId
    for _, conn in ipairs(S.tabConns) do conn:Disconnect() end
    S.tabConns = {}
    for _, child in ipairs(S.scroller:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
    rowIndex = 0

    for _, tab in ipairs(TABS) do
        local nav = navButtons[tab.id]
        local on = tab.id == tabId
        tween(nav.bg, 0.15, { BackgroundTransparency = on and 0 or 1 })
        tween(nav.bar, 0.15, { BackgroundTransparency = on and 0 or 1 })
        tween(nav.idx, 0.15, { TextTransparency = on and 0 or 0.55 })
        tween(nav.name, 0.15, { TextTransparency = on and 0 or 0.3 })
        if on then
            W.pageTitle.Text = tab.title
            W.pageSub.Text = "//  " .. tab.sub
        end
    end

    local builder = Tabs[tabId]
    if builder then
        local ok, err = pcall(builder)
        if not ok then
            warn("[Scriptly 628] Could not build tab " .. tostring(tabId) .. ": " .. tostring(err))
            toast("Tab failed to build. See the output for details.", "bad", "UI ERROR")
        end
    end
    S.scroller.CanvasPosition = Vector2.new(0, 0)
end

for _, tab in ipairs(TABS) do
    navButtons[tab.id].button.MouseButton1Click:Connect(function()
        if S.tab ~= tab.id then W.buildTab(tab.id) end
    end)
end

-- ---------------------------------------------------------------------------
--  Players / characters / tagged NPCs
-- ---------------------------------------------------------------------------
local function watchPlayer(other)
    if other == player then return end
    track(other.CharacterAdded:Connect(function()
        task.wait(0.6)
        if S.esp then V.addPlayerHighlight(other) end
    end))
    track(other.CharacterRemoving:Connect(function(character)
        local highlight = S.playerHL[character]
        if highlight then
            highlight:Destroy()
            S.playerHL[character] = nil
        end
    end))
end
track(Players.PlayerAdded:Connect(watchPlayer))
for _, other in ipairs(Players:GetPlayers()) do watchPlayer(other) end

track(CollectionService:GetInstanceAddedSignal(CFG.TAG):Connect(function()
    if S.npcEsp then task.wait(0.1) V.refreshNpcEsp() end
end))
track(CollectionService:GetInstanceRemovedSignal(CFG.TAG):Connect(function()
    if S.npcEsp then V.refreshNpcEsp() end
end))

-- Re-apply persistent movement toggles after a respawn.
track(player.CharacterAdded:Connect(function(character)
    character:WaitForChild("HumanoidRootPart", 10)
    task.wait(0.3)
    if S.fly then M.startFly() end
    if S.noclip then M.setNoclip(true) end
    if S.spin then M.setSpin(true) end
end))

-- ---------------------------------------------------------------------------
--  Input + ambient animation
-- ---------------------------------------------------------------------------
track(UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == CFG.TOGGLE_KEY then
        W.setVisible(not S.visible)
    end
end))

-- Keep the window inside the screen when the viewport changes.
do
    local cam = workspace.CurrentCamera
    if cam then
        track(cam:GetPropertyChangedSignal("ViewportSize"):Connect(function()
            W.scale.Scale = UI.fitScale()
        end))
    end
end

-- Border shimmer + FPS average on one Heartbeat connection.
track(RunService.Heartbeat:Connect(function(dt)
    if dt > 0 then S.fps = S.fps + (1 / dt - S.fps) * 0.08 end
    if S.visible then
        W.borderGrad.Rotation = (os.clock() * 40) % 360
    end
end))

-- Chromatic jitter on the glitch titles.
task.spawn(function()
    while S.alive do
        task.wait(math.random(22, 55) / 10)
        if not S.alive then break end
        for _ = 1, 4 do
            for _, g in ipairs(S.glitch) do
                if g.main.Parent then
                    local dx = math.random(-3, 3)
                    g.c1.Position = UDim2.fromOffset(-1 - dx, 0)
                    g.c2.Position = UDim2.fromOffset(1 + dx, math.random(-1, 1))
                end
            end
            task.wait(0.035)
        end
        for _, g in ipairs(S.glitch) do
            if g.main.Parent then
                g.c1.Position = UDim2.fromOffset(-1, 0)
                g.c2.Position = UDim2.fromOffset(1, 0)
            end
        end
    end
end)

-- Live status line (FPS / ping / players).
task.spawn(function()
    while S.alive do
        local ping = "--"
        pcall(function()
            ping = string.format("%d", math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue() + 0.5))
        end)
        W.stats.Text = string.format(
            "FPS %d   PING %sms   PLAYERS %d   BUILD %s",
            math.floor(S.fps + 0.5), ping, #Players:GetPlayers(), CFG.VERSION
        )
        task.wait(0.5)
    end
end)

-- ---------------------------------------------------------------------------
--  Cleanup (also runs when the script is executed a second time)
-- ---------------------------------------------------------------------------
local function cleanup()
    S.alive = false
    pcall(M.stopFly)
    pcall(M.setNoclip, false)
    pcall(M.setBunny, false)
    pcall(M.setSpin, false)
    pcall(V.setAim, false)
    pcall(V.setFullbright, false)
    for _, conn in ipairs(S.tabConns) do pcall(function() conn:Disconnect() end) end
    for _, conn in ipairs(S.conns) do pcall(function() conn:Disconnect() end) end
    pcall(function() gui:Destroy() end)
end
pcall(function()
    if type(_G) == "table" then _G.Scriptly628_Cleanup = cleanup end
end)

-- ---------------------------------------------------------------------------
--  Go
-- ---------------------------------------------------------------------------
-- Resolve the server link in the background while the boot screen plays.
task.spawn(function()
    refreshLink()
    updateBadge()
end)

runBoot()

updateBadge()
W.buildTab("MOVEMENT")
W.setVisible(true)
do
    local target = W.scale.Scale
    W.scale.Scale = target * 0.92
    tween(W.scale, 0.3, { Scale = target }, Enum.EasingStyle.Back)
end

-- A server bridge that starts just after the client still gets picked up.
task.spawn(function()
    for _ = 1, 12 do
        if not S.alive then return end
        if refreshLink() then
            updateBadge()
            break
        end
        updateBadge()
        task.wait(1)
    end
end)

print("[Scriptly 628] Console loaded. Press RightShift to toggle.")
print("[Scriptly 628] Owner/Studio mode:", userOwns, "| Server link:", link.authorized)
