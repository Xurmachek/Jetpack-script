-- [[ Teleport Hub v1.0 | RightShift to toggle ]]
-- Красивое меню с категориями слева и кнопками справа
-- Категория по умолчанию: Teleporting
-- Телепорты делают ровно то же что в оригинале: HRP.CFrame = CFrame.new(x,y,z)

-- // Services
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer
local function getGuiParent()
    -- для эксплойтов: gethui() > CoreGui > PlayerGui
    local ok, hui = pcall(function() return gethui and gethui() end)
    if ok and hui then return hui end
    local ok2, cg = pcall(function() return game:GetService("CoreGui") end)
    if ok2 and cg then
        -- некоторые игры не пускают в CoreGui, пробуем PlayerGui
        local success = pcall(function() cg:FindFirstChild("TeleportHub") end)
        if success then return cg end
    end
    return LocalPlayer:WaitForChild("PlayerGui")
end

-- // Config
local TELEPORTS = {
    {name = "Common",     x = -90, y = 60, z = -135,  color = Color3.fromRGB(156,163,175), icon = "●"},
    {name = "Uncommon",   x = -90, y = 60, z = -285,  color = Color3.fromRGB(34,197,94),   icon = "⬢"},
    {name = "Rare",       x = -90, y = 60, z = -475,  color = Color3.fromRGB(59,130,246),  icon = "◆"},
    {name = "Epic",       x = -90, y = 60, z = -775,  color = Color3.fromRGB(168,85,247),  icon = "✦"},
    {name = "Legendary",  x = -90, y = 60, z = -1265, color = Color3.fromRGB(234,179,8),   icon = "★"},
    {name = "Mythical",   x = -90, y = 60, z = -1945, color = Color3.fromRGB(239,68,68),   icon = "♛"},
    {name = "Cosmic 1",   x = -90, y = 60, z = -2870, color = Color3.fromRGB(6,182,214),   icon = "☾"},
    {name = "Cosmic 2",   x = -90, y = 60, z = -4110, color = Color3.fromRGB(139,92,246),  icon = "☄"},
    {name = "Secret 1",   x = -90, y = 60, z = -5735, color = Color3.fromRGB(245,158,11),  icon = "◈"},
    {name = "Secret 2",   x = -90, y = 60, z = -7850, color = Color3.fromRGB(236,72,153),  icon = "⬣"},
    {name = "Celestial",  x = -90, y = 60, z = -9935, color = Color3.fromRGB(255,215,0),   icon = "✧"},
}

local CATEGORIES = {
    {id = "teleporting", name = "Teleporting", icon = "◎", count = #TELEPORTS},
    -- добавляй сюда новые категории так: {id="shop", name="Shop", icon="◐", count=3}
}

-- // Utils
local function tween(obj, props, time, style, dir)
    local info = TweenInfo.new(time or 0.25, style or Enum.EasingStyle.Quart, dir or Enum.EasingDirection.Out)
    local t = TweenService:Create(obj, info, props)
    t:Play()
    return t
end

local function notify(title, text)
    -- пробуем Roblox notification
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title,
            Text = text,
            Duration = 2.5
        })
    end)
end

local function doTeleport(x, y, z, label)
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local hrp = char:WaitForChild("HumanoidRootPart", 5)
    if not hrp then
        notify("Ошибка", "HumanoidRootPart не найден")
        return
    end
    -- как в оригинале: прямая смена CFrame (самый надёжный способ)
    -- добавляем +3 по Y чтобы не застрять в полу
    local target = CFrame.new(x, y + 3, z)
    
    -- если далеко (>2000 studs) делаем сначала мягкий твин чтобы античит не триггерил
    local dist = (hrp.Position - Vector3.new(x, y, z)).Magnitude
    if dist > 3500 then
        -- мгновенно для таких дистанций всё равно лучше CFrame, твин будет слишком долгий
        hrp.CFrame = target
        hrp.Velocity = Vector3.zero
        hrp.AssemblyLinearVelocity = Vector3.zero
    else
        -- мягкий твин 0.35с для красоты
        local tw = TweenService:Create(hrp, TweenInfo.new(0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {CFrame = target})
        tw:Play()
        -- на случай если твин прервётся
        task.delay(0.4, function()
            if (hrp.Position - Vector3.new(x, y, z)).Magnitude > 10 then
                hrp.CFrame = target
            end
        end)
    end

    -- тост внутри гуи
    if _G.__teleportToast then _G.__teleportToast(label, string.format("%d, %d, %d", x, y, z)) end
    notify("Телепорт → " .. label, string.format("X:%d Y:%d Z:%d", x, y, z))
end

-- // GUI Build
if getGuiParent():FindFirstChild("TeleportHub") then
    getGuiParent():FindFirstChild("TeleportHub"):Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "TeleportHub"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.IgnoreGuiInset = true
gui.DisplayOrder = 999
if syn and syn.protect_gui then syn.protect_gui(gui) end
gui.Parent = getGuiParent()

-- backdrop blur (для красоты, если поддерживается)
local blur = Instance.new("Frame")
blur.Name = "Backdrop"
blur.Size = UDim2.fromScale(1,1)
blur.BackgroundColor3 = Color3.fromRGB(10,10,14)
blur.BackgroundTransparency = 0.25
blur.Visible = false
blur.ZIndex = 0
blur.Parent = gui

-- Main Window
local main = Instance.new("Frame")
main.Name = "Main"
main.AnchorPoint = Vector2.new(0.5, 0.5)
main.Position = UDim2.fromScale(0.5, 0.5)
main.Size = UDim2.fromOffset(640, 420)
main.BackgroundColor3 = Color3.fromRGB(20,20,25)
main.BorderSizePixel = 0
main.ClipsDescendants = true
main.ZIndex = 2
main.Parent = gui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 16)
mainCorner.Parent = main

local mainStroke = Instance.new("UIStroke")
mainStroke.Color = Color3.fromRGB(45,45,55)
mainStroke.Thickness = 1
mainStroke.Transparency = 0.3
mainStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
mainStroke.Parent = main

local shadow = Instance.new("ImageLabel")
shadow.Name = "Shadow"
shadow.BackgroundTransparency = 1
shadow.Position = UDim2.fromOffset(-20, -20)
shadow.Size = UDim2.new(1, 40, 1, 40)
shadow.Image = "rbxassetid://5554236805"
shadow.ImageColor3 = Color3.fromRGB(0,0,0)
shadow.ImageTransparency = 0.5
shadow.ScaleType = Enum.ScaleType.Slice
shadow.SliceCenter = Rect.new(23,23,277,277)
shadow.ZIndex = 1
shadow.Parent = main
shadow.Visible = false -- убираем если лагает

-- Top Bar
local topBar = Instance.new("Frame")
topBar.Name = "TopBar"
topBar.Size = UDim2.new(1, 0, 0, 52)
topBar.BackgroundColor3 = Color3.fromRGB(24,24,30)
topBar.BorderSizePixel = 0
topBar.ZIndex = 3
topBar.Parent = main

local topCorner = Instance.new("UICorner")
topCorner.CornerRadius = UDim.new(0, 16)
topCorner.Parent = topBar

local topFix = Instance.new("Frame")
topFix.Size = UDim2.new(1,0,0,16)
topFix.Position = UDim2.new(0,0,1,-16)
topFix.BackgroundColor3 = Color3.fromRGB(24,24,30)
topFix.BorderSizePixel = 0
topFix.ZIndex = 3
topFix.Parent = topBar

-- Title
local titleWrap = Instance.new("Frame")
titleWrap.BackgroundTransparency = 1
titleWrap.Size = UDim2.new(1, -140, 1, 0)
titleWrap.Position = UDim2.fromOffset(18, 0)
titleWrap.Parent = topBar

local dot = Instance.new("Frame")
dot.Size = UDim2.fromOffset(10,10)
dot.Position = UDim2.fromOffset(0, 21)
dot.BackgroundColor3 = Color3.fromRGB(124,92,255)
dot.Parent = titleWrap
local dotCorner = Instance.new("UICorner")
dotCorner.CornerRadius = UDim.new(1,0)
dotCorner.Parent = dot
local dotGrad = Instance.new("UIGradient")
dotGrad.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Color3.fromRGB(124,92,255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(91,141,239))
}
dotGrad.Rotation = 90
dotGrad.Parent = dot

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(18, 0)
title.Size = UDim2.new(1, -20, 1, 0)
title.Font = Enum.Font.GothamBold
title.Text = "TELEPORT HUB"
title.TextColor3 = Color3.fromRGB(255,255,255)
title.TextSize = 14
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextYAlignment = Enum.TextYAlignment.Center
title.Parent = titleWrap

local subtitle = Instance.new("TextLabel")
subtitle.BackgroundTransparency = 1
subtitle.Position = UDim2.fromOffset(138, 0)
subtitle.Size = UDim2.new(1, -140, 1, 0)
subtitle.Font = Enum.Font.Gotham
subtitle.Text = "•  v1.0  —  RightShift to toggle"
subtitle.TextColor3 = Color3.fromRGB(125,125,135)
subtitle.TextSize = 11
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.Parent = titleWrap

-- Window controls
local controls = Instance.new("Frame")
controls.BackgroundTransparency = 1
controls.Size = UDim2.fromOffset(72, 28)
controls.Position = UDim2.new(1, -82, 0.5, -14)
controls.Parent = topBar

local function makeControl(symbol, offsetX, hover)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.fromOffset(28, 28)
    btn.Position = UDim2.fromOffset(offsetX, 0)
    btn.BackgroundColor3 = Color3.fromRGB(32,32,38)
    btn.Text = symbol
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 12
    btn.TextColor3 = Color3.fromRGB(170,170,180)
    btn.AutoButtonColor = false
    btn.Parent = controls
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 8)
    c.Parent = btn
    btn.MouseEnter:Connect(function()
        tween(btn, {BackgroundColor3 = hover, TextColor3 = Color3.fromRGB(255,255,255)}, 0.15)
    end)
    btn.MouseLeave:Connect(function()
        tween(btn, {BackgroundColor3 = Color3.fromRGB(32,32,38), TextColor3 = Color3.fromRGB(170,170,180)}, 0.15)
    end)
    return btn
end

local minimizeBtn = makeControl("—", 0, Color3.fromRGB(45,45,55))
local closeBtn = makeControl("✕", 38, Color3.fromRGB(239,68,68))

-- Divider under topbar
local divider = Instance.new("Frame")
divider.Size = UDim2.new(1, 0, 0, 1)
divider.Position = UDim2.fromOffset(0, 52)
divider.BackgroundColor3 = Color3.fromRGB(45,45,55)
divider.BorderSizePixel = 0
divider.Parent = main

-- Content
local content = Instance.new("Frame")
content.Name = "Content"
content.Position = UDim2.fromOffset(0, 53)
content.Size = UDim2.new(1, 0, 1, -53)
content.BackgroundTransparency = 1
content.Parent = main

-- Sidebar
local sidebar = Instance.new("Frame")
sidebar.Name = "Sidebar"
sidebar.Size = UDim2.new(0, 170, 1, 0)
sidebar.BackgroundColor3 = Color3.fromRGB(16,16,20)
sidebar.BorderSizePixel = 0
sidebar.Parent = content

local sideCorner = Instance.new("UICorner")
sideCorner.CornerRadius = UDim.new(0, 14)
sideCorner.Parent = sidebar
-- fix corners
local sideFix1 = Instance.new("Frame")
sideFix1.Size = UDim2.new(0,16,0,16)
sideFix1.Position = UDim2.new(1,-16,0,0)
sideFix1.BackgroundColor3 = Color3.fromRGB(16,16,20)
sideFix1.BorderSizePixel = 0
sideFix1.Parent = sidebar
local sideFix2 = Instance.new("Frame")
sideFix2.Size = UDim2.new(0,16,1,-16)
sideFix2.Position = UDim2.fromOffset(154, 16)
sideFix2.BackgroundColor3 = Color3.fromRGB(16,16,20)
sideFix2.BorderSizePixel = 0
sideFix2.Parent = sidebar
local sideFix3 = Instance.new("Frame")
sideFix3.Size = UDim2.new(0,16,0,16)
sideFix3.Position = UDim2.new(1,-16,1,-16)
sideFix3.BackgroundColor3 = Color3.fromRGB(16,16,20)
sideFix3.BorderSizePixel = 0
sideFix3.Parent = sidebar

local sideLabel = Instance.new("TextLabel")
sideLabel.BackgroundTransparency = 1
sideLabel.Position = UDim2.fromOffset(14, 12)
sideLabel.Size = UDim2.fromOffset(120, 14)
sideLabel.Font = Enum.Font.GothamBold
sideLabel.Text = "CATEGORIES"
sideLabel.TextColor3 = Color3.fromRGB(100,100,115)
sideLabel.TextSize = 10
sideLabel.TextXAlignment = Enum.TextXAlignment.Left
sideLabel.Parent = sidebar

local categoryList = Instance.new("Frame")
categoryList.BackgroundTransparency = 1
categoryList.Position = UDim2.fromOffset(8, 34)
categoryList.Size = UDim2.new(1, -16, 1, -50)
categoryList.Parent = sidebar
local catLayout = Instance.new("UIListLayout")
catLayout.Padding = UDim.new(0, 6)
catLayout.SortOrder = Enum.SortOrder.LayoutOrder
catLayout.Parent = categoryList

-- Right area
local rightArea = Instance.new("Frame")
rightArea.Name = "RightArea"
rightArea.Position = UDim2.fromOffset(170, 0)
rightArea.Size = UDim2.new(1, -170, 1, 0)
rightArea.BackgroundTransparency = 1
rightArea.Parent = content

local header = Instance.new("Frame")
header.BackgroundTransparency = 1
header.Size = UDim2.new(1, -24, 0, 42)
header.Position = UDim2.fromOffset(12, 8)
header.Parent = rightArea

local headerTitle = Instance.new("TextLabel")
headerTitle.Name = "HeaderTitle"
headerTitle.BackgroundTransparency = 1
headerTitle.Size = UDim2.new(1, -90, 1, 0)
headerTitle.Font = Enum.Font.GothamBold
headerTitle.Text = "Teleporting"
headerTitle.TextColor3 = Color3.fromRGB(255,255,255)
headerTitle.TextSize = 18
headerTitle.TextXAlignment = Enum.TextXAlignment.Left
headerTitle.Parent = header

local headerSub = Instance.new("TextLabel")
headerSub.BackgroundTransparency = 1
headerSub.Position = UDim2.fromOffset(0, 22)
headerSub.Size = UDim2.new(1, -90, 0, 14)
headerSub.Font = Enum.Font.Gotham
headerSub.Text = "11 locations  •  click to teleport"
headerSub.TextColor3 = Color3.fromRGB(125,125,135)
headerSub.TextSize = 11
headerSub.TextXAlignment = Enum.TextXAlignment.Left
headerSub.Parent = header

local badge = Instance.new("Frame")
badge.Size = UDim2.fromOffset(64, 24)
badge.Position = UDim2.new(1, -64, 0, 9)
badge.BackgroundColor3 = Color3.fromRGB(124,92,255)
badge.Parent = header
local badgeCorner = Instance.new("UICorner")
badgeCorner.CornerRadius = UDim.new(1,0)
badgeCorner.Parent = badge
local badgeGrad = Instance.new("UIGradient")
badgeGrad.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Color3.fromRGB(124,92,255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(91,141,239))
}
badgeGrad.Rotation = 90
badgeGrad.Parent = badge
local badgeText = Instance.new("TextLabel")
badgeText.BackgroundTransparency = 1
badgeText.Size = UDim2.fromScale(1,1)
badgeText.Font = Enum.Font.GothamBold
badgeText.Text = "11 PTS"
badgeText.TextColor3 = Color3.fromRGB(255,255,255)
badgeText.TextSize = 10
badgeText.Parent = badge

local scroll = Instance.new("ScrollingFrame")
scroll.Name = "Scroll"
scroll.Position = UDim2.fromOffset(12, 58)
scroll.Size = UDim2.new(1, -24, 1, -70)
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel = 0
scroll.CanvasSize = UDim2.new(0,0,0,0)
scroll.ScrollBarThickness = 4
scroll.ScrollBarImageColor3 = Color3.fromRGB(65,65,75)
scroll.ScrollingDirection = Enum.ScrollingDirection.Y
scroll.Parent = rightArea

local grid = Instance.new("UIGridLayout")
grid.CellPadding = UDim2.fromOffset(8, 8)
grid.CellSize = UDim2.fromOffset(226, 56)
grid.FillDirectionMaxCells = 2
grid.HorizontalAlignment = Enum.HorizontalAlignment.Left
grid.SortOrder = Enum.SortOrder.LayoutOrder
grid.Parent = scroll

local gridPad = Instance.new("UIPadding")
gridPad.PaddingTop = UDim.new(0, 2)
gridPad.Parent = scroll

-- Toast container (внутри rightArea для превью, но глобально тоже работает)
local toastContainer = Instance.new("Frame")
toastContainer.Name = "ToastContainer"
toastContainer.BackgroundTransparency = 1
toastContainer.Size = UDim2.new(1, 0, 0, 0)
toastContainer.Position = UDim2.new(0, 0, 1, -46)
toastContainer.ZIndex = 10
toastContainer.Parent = rightArea

local function showToast(title, msg)
    local toast = Instance.new("Frame")
    toast.Size = UDim2.new(1, -12, 0, 44)
    toast.Position = UDim2.new(0, 6, 1, 10)
    toast.BackgroundColor3 = Color3.fromRGB(28,28,34)
    toast.BorderSizePixel = 0
    toast.Parent = toastContainer
    local tc = Instance.new("UICorner")
    tc.CornerRadius = UDim.new(0, 10)
    tc.Parent = toast
    local ts = Instance.new("UIStroke")
    ts.Color = Color3.fromRGB(65,65,75)
    ts.Transparency = 0.4
    ts.Parent = toast
    local icon = Instance.new("Frame")
    icon.Size = UDim2.fromOffset(30,30)
    icon.Position = UDim2.fromOffset(7,7)
    icon.BackgroundColor3 = Color3.fromRGB(34,197,94)
    icon.Parent = toast
    local ic = Instance.new("UICorner")
    ic.CornerRadius = UDim.new(1,0)
    ic.Parent = icon
    local iconLbl = Instance.new("TextLabel")
    iconLbl.BackgroundTransparency = 1
    iconLbl.Size = UDim2.fromScale(1,1)
    iconLbl.Font = Enum.Font.GothamBold
    iconLbl.Text = "✓"
    iconLbl.TextColor3 = Color3.fromRGB(255,255,255)
    iconLbl.TextSize = 14
    iconLbl.Parent = icon
    local tTitle = Instance.new("TextLabel")
    tTitle.BackgroundTransparency = 1
    tTitle.Position = UDim2.fromOffset(44, 6)
    tTitle.Size = UDim2.new(1, -52, 0, 14)
    tTitle.Font = Enum.Font.GothamBold
    tTitle.Text = title
    tTitle.TextColor3 = Color3.fromRGB(255,255,255)
    tTitle.TextSize = 12
    tTitle.TextXAlignment = Enum.TextXAlignment.Left
    tTitle.Parent = toast
    local tMsg = Instance.new("TextLabel")
    tMsg.BackgroundTransparency = 1
    tMsg.Position = UDim2.fromOffset(44, 20)
    tMsg.Size = UDim2.new(1, -52, 0, 12)
    tMsg.Font = Enum.Font.Gotham
    tMsg.Text = msg
    tMsg.TextColor3 = Color3.fromRGB(150,150,165)
    tMsg.TextSize = 11
    tMsg.TextXAlignment = Enum.TextXAlignment.Left
    tMsg.Parent = toast
    toast.BackgroundTransparency = 1
    tTitle.TextTransparency = 1
    tMsg.TextTransparency = 1
    icon.BackgroundTransparency = 1
    iconLbl.TextTransparency = 1
    ts.Transparency = 1
    tween(toast, {BackgroundTransparency = 0}, 0.2)
    tween(ts, {Transparency = 0.4}, 0.2)
    tween(icon, {BackgroundTransparency = 0}, 0.2)
    tween(iconLbl, {TextTransparency = 0}, 0.2)
    tween(tTitle, {TextTransparency = 0}, 0.2)
    tween(tMsg, {TextTransparency = 0}, 0.2)
    tween(toast, {Position = UDim2.new(0,6,1,-52)}, 0.35, Enum.EasingStyle.Back)
    task.delay(2.2, function()
        tween(toast, {BackgroundTransparency = 1}, 0.25)
        tween(ts, {Transparency = 1}, 0.25)
        tween(icon, {BackgroundTransparency = 1}, 0.25)
        tween(iconLbl, {TextTransparency = 1}, 0.25)
        tween(tTitle, {TextTransparency = 1}, 0.25)
        tween(tMsg, {TextTransparency = 1}, 0.25)
        tween(toast, {Position = UDim2.new(0,6,1,10)}, 0.25)
        task.wait(0.3)
        toast:Destroy()
    end)
end
_G.__teleportToast = showToast

-- Build Categories
local selectedCategory = "teleporting"
local categoryButtons = {}

for i, cat in ipairs(CATEGORIES) do
    local btn = Instance.new("TextButton")
    btn.Name = cat.id
    btn.Size = UDim2.new(1, 0, 0, 42)
    btn.BackgroundColor3 = (cat.id == selectedCategory) and Color3.fromRGB(124,92,255) or Color3.fromRGB(26,26,32)
    btn.Text = ""
    btn.AutoButtonColor = false
    btn.Parent = categoryList
    btn.LayoutOrder = i
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 10)
    c.Parent = btn
    if cat.id == selectedCategory then
        local g = Instance.new("UIGradient")
        g.Name = "Grad"
        g.Color = ColorSequence.new{
            ColorSequenceKeypoint.new(0, Color3.fromRGB(124,92,255)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(91,141,239))
        }
        g.Rotation = 90
        g.Parent = btn
    end
    local iconBox = Instance.new("Frame")
    iconBox.Size = UDim2.fromOffset(28,28)
    iconBox.Position = UDim2.fromOffset(8,7)
    iconBox.BackgroundColor3 = (cat.id == selectedCategory) and Color3.fromRGB(255,255,255) or Color3.fromRGB(35,35,42)
    iconBox.BackgroundTransparency = (cat.id == selectedCategory) and 0.85 or 0
    iconBox.Parent = btn
    local ic2 = Instance.new("UICorner")
    ic2.CornerRadius = UDim.new(0, 8)
    ic2.Parent = iconBox
    local iconLbl = Instance.new("TextLabel")
    iconLbl.BackgroundTransparency = 1
    iconLbl.Size = UDim2.fromScale(1,1)
    iconLbl.Font = Enum.Font.GothamBold
    iconLbl.Text = cat.icon
    iconLbl.TextColor3 = (cat.id == selectedCategory) and Color3.fromRGB(255,255,255) or Color3.fromRGB(170,170,180)
    iconLbl.TextSize = 13
    iconLbl.Parent = iconBox
    local nameLbl = Instance.new("TextLabel")
    nameLbl.BackgroundTransparency = 1
    nameLbl.Position = UDim2.fromOffset(42, 6)
    nameLbl.Size = UDim2.new(1, -72, 0, 14)
    nameLbl.Font = Enum.Font.GothamBold
    nameLbl.Text = cat.name
    nameLbl.TextColor3 = (cat.id == selectedCategory) and Color3.fromRGB(255,255,255) or Color3.fromRGB(200,200,210)
    nameLbl.TextSize = 12
    nameLbl.TextXAlignment = Enum.TextXAlignment.Left
    nameLbl.Parent = btn
    local countLbl = Instance.new("TextLabel")
    countLbl.BackgroundTransparency = 1
    countLbl.Position = UDim2.fromOffset(42, 20)
    countLbl.Size = UDim2.new(1, -72, 0, 12)
    countLbl.Font = Enum.Font.Gotham
    countLbl.Text = cat.count .. " points"
    countLbl.TextColor3 = (cat.id == selectedCategory) and Color3.fromRGB(220,220,255) or Color3.fromRGB(110,110,125)
    countLbl.TextSize = 10
    countLbl.TextXAlignment = Enum.TextXAlignment.Left
    countLbl.Parent = btn
    categoryButtons[cat.id] = btn

    if cat.id ~= selectedCategory then
        btn.MouseEnter:Connect(function()
            tween(btn, {BackgroundColor3 = Color3.fromRGB(34,34,42)}, 0.15)
        end)
        btn.MouseLeave:Connect(function()
            tween(btn, {BackgroundColor3 = Color3.fromRGB(26,26,32)}, 0.15)
        end)
    end
end

-- Build Teleport Cards
for idx, tp in ipairs(TELEPORTS) do
    local card = Instance.new("TextButton")
    card.Name = tp.name
    card.BackgroundColor3 = Color3.fromRGB(26,26,32)
    card.BorderSizePixel = 0
    card.Text = ""
    card.AutoButtonColor = false
    card.LayoutOrder = idx
    card.Parent = scroll
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = card
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(45,45,55)
    stroke.Thickness = 1
    stroke.Transparency = 0.5
    stroke.Parent = card

    local accent = Instance.new("Frame")
    accent.Size = UDim2.new(0, 3, 1, -16)
    accent.Position = UDim2.fromOffset(8, 8)
    accent.BackgroundColor3 = tp.color
    accent.BorderSizePixel = 0
    accent.Parent = card
    local aCorner = Instance.new("UICorner")
    aCorner.CornerRadius = UDim.new(1,0)
    aCorner.Parent = accent

    local iconCircle = Instance.new("Frame")
    iconCircle.Size = UDim2.fromOffset(34,34)
    iconCircle.Position = UDim2.fromOffset(18, 11)
    iconCircle.BackgroundColor3 = tp.color
    iconCircle.BackgroundTransparency = 0.88
    iconCircle.Parent = card
    local iCorner = Instance.new("UICorner")
    iCorner.CornerRadius = UDim.new(1,0)
    iCorner.Parent = iconCircle
    local iconStroke = Instance.new("UIStroke")
    iconStroke.Color = tp.color
    iconStroke.Transparency = 0.6
    iconStroke.Thickness = 1
    iconStroke.Parent = iconCircle
    local iconText = Instance.new("TextLabel")
    iconText.BackgroundTransparency = 1
    iconText.Size = UDim2.fromScale(1,1)
    iconText.Font = Enum.Font.GothamBold
    iconText.Text = tp.icon
    iconText.TextColor3 = tp.color
    iconText.TextSize = 14
    iconText.Parent = iconCircle

    local name = Instance.new("TextLabel")
    name.BackgroundTransparency = 1
    name.Position = UDim2.fromOffset(60, 10)
    name.Size = UDim2.new(1, -96, 0, 14)
    name.Font = Enum.Font.GothamBold
    name.Text = tp.name
    name.TextColor3 = Color3.fromRGB(255,255,255)
    name.TextSize = 12
    name.TextXAlignment = Enum.TextXAlignment.Left
    name.Parent = card

    local coords = Instance.new("TextLabel")
    coords.BackgroundTransparency = 1
    coords.Position = UDim2.fromOffset(60, 26)
    coords.Size = UDim2.new(1, -96, 0, 12)
    coords.Font = Enum.Font.Gotham
    coords.Text = string.format("%d ,  %d ,  %d", tp.x, tp.y, tp.z)
    coords.TextColor3 = Color3.fromRGB(140,140,155)
    coords.TextSize = 11
    coords.TextXAlignment = Enum.TextXAlignment.Left
    coords.Parent = card

    local arrow = Instance.new("Frame")
    arrow.Size = UDim2.fromOffset(28,28)
    arrow.Position = UDim2.new(1, -38, 0.5, -14)
    arrow.BackgroundColor3 = Color3.fromRGB(35,35,42)
    arrow.Parent = card
    local arCorner = Instance.new("UICorner")
    arCorner.CornerRadius = UDim.new(0, 8)
    arCorner.Parent = arrow
    local arrowLbl = Instance.new("TextLabel")
    arrowLbl.BackgroundTransparency = 1
    arrowLbl.Size = UDim2.fromScale(1,1)
    arrowLbl.Font = Enum.Font.GothamBold
    arrowLbl.Text = "→"
    arrowLbl.TextColor3 = Color3.fromRGB(170,170,180)
    arrowLbl.TextSize = 13
    arrowLbl.Parent = arrow

    -- hover
    card.MouseEnter:Connect(function()
        tween(card, {BackgroundColor3 = Color3.fromRGB(32,32,40)}, 0.15)
        tween(stroke, {Color = tp.color, Transparency = 0.25}, 0.15)
        tween(arrow, {BackgroundColor3 = tp.color}, 0.15)
        tween(arrowLbl, {TextColor3 = Color3.fromRGB(255,255,255)}, 0.15)
    end)
    card.MouseLeave:Connect(function()
        tween(card, {BackgroundColor3 = Color3.fromRGB(26,26,32)}, 0.15)
        tween(stroke, {Color = Color3.fromRGB(45,45,55), Transparency = 0.5}, 0.15)
        tween(arrow, {BackgroundColor3 = Color3.fromRGB(35,35,42)}, 0.15)
        tween(arrowLbl, {TextColor3 = Color3.fromRGB(170,170,180)}, 0.15)
    end)

    card.MouseButton1Click:Connect(function()
        -- клик-анимация
        tween(card, {BackgroundColor3 = Color3.fromRGB(42,42,52)}, 0.08)
        task.wait(0.08)
        tween(card, {BackgroundColor3 = Color3.fromRGB(32,32,40)}, 0.12)
        -- пульс стрелки
        tween(arrow, {BackgroundColor3 = Color3.fromRGB(255,255,255)}, 0.08)
        task.wait(0.08)
        tween(arrow, {BackgroundColor3 = tp.color}, 0.12)
        doTeleport(tp.x, tp.y, tp.z, tp.name)
    end)
end

-- auto canvas size
task.spawn(function()
    task.wait(0.1)
    local function updateCanvas()
        local count = #TELEPORTS
        local rows = math.ceil(count / 2)
        scroll.CanvasSize = UDim2.new(0,0,0, rows * 64 + 6)
    end
    updateCanvas()
    grid:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateCanvas)
end)

-- Dragging (только за TopBar)
do
    local dragging, dragStart, startPos
    topBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = main.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

-- Open / Close logic + RightShift
local isOpen = true
local isMinimized = false
local originalSize = main.Size

local function setOpen(open, instant)
    isOpen = open
    if open then
        gui.Enabled = true
        blur.Visible = true
        main.Visible = true
        if instant then
            main.Size = originalSize
            main.BackgroundTransparency = 0
        else
            main.Size = UDim2.fromOffset(originalSize.X.Offset * 0.92, originalSize.Y.Offset * 0.92)
            main.BackgroundTransparency = 1
            for _,v in ipairs(main:GetDescendants()) do
                if v:IsA("TextLabel") or v:IsA("TextButton") then
                    -- не трогаем чтобы не мигало
                end
            end
            tween(main, {Size = originalSize, BackgroundTransparency = 0}, 0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
            tween(blur, {BackgroundTransparency = 0.25}, 0.28)
        end
    else
        if instant then
            main.Visible = false
            blur.Visible = false
            gui.Enabled = false
        else
            local t1 = tween(main, {Size = UDim2.fromOffset(originalSize.X.Offset * 0.92, originalSize.Y.Offset * 0.92), BackgroundTransparency = 1}, 0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
            tween(blur, {BackgroundTransparency = 1}, 0.22)
            t1.Completed:Wait()
            main.Visible = false
            blur.Visible = false
        end
    end
end

closeBtn.MouseButton1Click:Connect(function()
    setOpen(false)
end)

minimizeBtn.MouseButton1Click:Connect(function()
    isMinimized = not isMinimized
    if isMinimized then
        tween(main, {Size = UDim2.fromOffset(originalSize.X.Offset, 52)}, 0.28, Enum.EasingStyle.Quart)
        scroll.Visible = false
        sidebar.Visible = false
        rightArea.Visible = false
        divider.Visible = false
        minimizeBtn.Text = "□"
    else
        tween(main, {Size = originalSize}, 0.28, Enum.EasingStyle.Back)
        task.wait(0.12)
        scroll.Visible = true
        sidebar.Visible = true
        rightArea.Visible = true
        divider.Visible = true
        minimizeBtn.Text = "—"
    end
end)

UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.RightShift then
        setOpen(not isOpen)
    end
    if input.KeyCode == Enum.KeyCode.RightControl and UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
        -- easter: Shift+RightCtrl тоже
        setOpen(not isOpen)
    end
end)

-- старт открыт
setOpen(true, true)

-- подсказка в консоли
print("[TeleportHub] Loaded — RightShift to toggle • 11 points ready")
notify("Teleport Hub", "RightShift — открыть меню • 11 точек загружено")
