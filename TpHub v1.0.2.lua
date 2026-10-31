-- [[ Teleport Hub v1.0.2 | ] to toggle ]]
-- Категории: Teleporting + Coins Collecting

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer
local function getGuiParent()
    local ok, hui = pcall(function() return gethui and gethui() end)
    if ok and hui then return hui end
    local ok2, cg = pcall(function() return game:GetService("CoreGui") end)
    if ok2 and cg then
        local success = pcall(function() cg:FindFirstChild("TeleportHub") end)
        if success then return cg end
    end
    return LocalPlayer:WaitForChild("PlayerGui")
end

-- // Config: Teleports 12 pts
local TELEPORTS = {
    {name = "Spawn",      x = -90, y = 60, z = 15,    color = Color3.fromRGB(16,185,129),  icon = "⌂"},
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
    {id = "teleporting", name = "Teleporting",       icon = "◎", count = #TELEPORTS},
    {id = "coins",       name = "Coins Collecting", icon = "◯", count = 0}, -- count обновится после скана
}

-- // Utils
local function tween(obj, props, time, style, dir)
    local info = TweenInfo.new(time or 0.25, style or Enum.EasingStyle.Quart, dir or Enum.EasingDirection.Out)
    local t = TweenService:Create(obj, info, props)
    t:Play()
    return t
end

local function notify(title, text)
    pcall(function()
        StarterGui:SetCore("SendNotification", {Title = title, Text = text, Duration = 2.8})
    end)
end

local function doTeleport(x, y, z, label, noToast)
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local hrp = char:WaitForChild("HumanoidRootPart", 5)
    if not hrp then notify("Ошибка", "HumanoidRootPart не найден") return end
    local target = CFrame.new(x, y + 3, z)
    local dist = (hrp.Position - Vector3.new(x, y, z)).Magnitude
    if dist > 3500 then
        hrp.CFrame = target
        pcall(function() hrp.AssemblyLinearVelocity = Vector3.zero end)
    else
        local tw = TweenService:Create(hrp, TweenInfo.new(0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {CFrame = target})
        tw:Play()
        task.delay(0.4, function()
            if (hrp.Position - Vector3.new(x, y, z)).Magnitude > 10 then hrp.CFrame = target end
        end)
    end
    if not noToast and _G.__teleportToast then _G.__teleportToast(label, string.format("%d, %d, %d", x, y, z)) end
    if not noToast then notify("Телепорт → " .. label, string.format("X:%d Y:%d Z:%d", x, y, z)) end
end

-- // Coins logic
local function round3(n)
    -- до 3 знаков чтобы избежать багов, как в ТЗ
    return tonumber(string.format("%.3f", n))
end

local function parseWorldPivotToVector3(pivot)
    -- pivot может быть CFrame, Vector3, или строка "x, y, z, 1,0,0..."
    if typeof(pivot) == "CFrame" then
        local p = pivot.Position
        return Vector3.new(round3(p.X), round3(p.Y), round3(p.Z))
    elseif typeof(pivot) == "Vector3" then
        return Vector3.new(round3(pivot.X), round3(pivot.Y), round3(pivot.Z))
    elseif typeof(pivot) == "string" then
        -- строка вида "-99.4776917, 63.0119057, -2902.2583, 1, 0, 0, 0, 1, 0, 0, 0, 1"
        local nums = {}
        for s in pivot:gmatch("[^,]+") do
            local n = tonumber((s:gsub("%s+", "")))
            if n then table.insert(nums, n) end
        end
        if #nums >= 3 then
            return Vector3.new(round3(nums[1]), round3(nums[2]), round3(nums[3]))
        end
    end
    return nil
end

local function scanMutationCoins()
    local okRoot, root = pcall(function() return workspace:FindFirstChild("MutationCoins") end)
    if not okRoot or not root then return {}, "MutationCoins не найдена в Workspace" end
    local seen = {}
    local out = {}
    -- ищем все объекты с именем MutationCoin_*
    local descendants = root:GetDescendants()
    for _, inst in ipairs(descendants) do
        if inst.Name:match("^MutationCoin_") then
            if seen[inst] then continue end
            seen[inst] = true
            local pos = nil
            -- 1) WorldPivot (Model)
            local ok, wp = pcall(function() return inst.WorldPivot end)
            if ok and wp and typeof(wp) == "CFrame" then
                pos = Vector3.new(round3(wp.Position.X), round3(wp.Position.Y), round3(wp.Position.Z))
            end
            -- 2) GetPivot
            if not pos then
                local ok2, gp = pcall(function() return inst:GetPivot() end)
                if ok2 and gp and typeof(gp) == "CFrame" then
                    pos = Vector3.new(round3(gp.Position.X), round3(gp.Position.Y), round3(gp.Position.Z))
                end
            end
            -- 3) BasePart.Position
            if not pos and inst:IsA("BasePart") then
                pos = Vector3.new(round3(inst.Position.X), round3(inst.Position.Y), round3(inst.Position.Z))
            end
            -- 4) Model.PrimaryPart
            if not pos and inst:IsA("Model") then
                local ok3, pp = pcall(function() return inst.PrimaryPart end)
                if ok3 and pp and pp:IsA("BasePart") then
                    pos = Vector3.new(round3(pp.Position.X), round3(pp.Position.Y), round3(pp.Position.Z))
                end
            end
            -- 5) любой BasePart внутри
            if not pos then
                local part = inst:FindFirstChildWhichIsA("BasePart", true)
                if part then pos = Vector3.new(round3(part.Position.X), round3(part.Position.Y), round3(part.Position.Z)) end
            end
            -- 6) атрибут WorldPivot как строка (на случай если хранят строкой)
            if not pos then
                local ok4, attr = pcall(function() return inst:GetAttribute("WorldPivot") end)
                if ok4 and attr then pos = parseWorldPivotToVector3(attr) end
            end
            if pos then
                table.insert(out, {obj = inst, pos = pos, name = inst.Name})
            end
        end
    end
    -- сортировка: по имени для детерминизма, либо по дистанции? сейчас как найдено
    table.sort(out, function(a,b) return a.name < b.name end)
    return out, nil
end

-- состояние сбора
local isCollecting = false
local collectedCount = 0
local targetCount = 0
local coinsCache = {}

-- forward для UI
local amountBox, foundLabel, toCollectLabel, collectedLabel, progressBar, progressText, statusLabel, startBtn, stopBtn, scanBtn, coinsBadge, coinsBadgeLabel, coinsHeaderSub

local function updateCoinsUI()
    local found = #coinsCache
    if foundLabel then foundLabel.Text = "Найдено: " .. found end
    if toCollectLabel then toCollectLabel.Text = "К сбору: " .. targetCount end
    if collectedLabel then collectedLabel.Text = "Собрано: " .. collectedCount .. " / " .. targetCount end
    if coinsBadgeLabel then
        if isCollecting then
            coinsBadgeLabel.Text = collectedCount .. "/" .. targetCount
            coinsBadge.BackgroundColor3 = Color3.fromRGB(34,197,94)
        else
            coinsBadgeLabel.Text = found .. " COINS"
            coinsBadge.BackgroundColor3 = Color3.fromRGB(124,92,255)
        end
    end
    if progressBar and targetCount > 0 then
        local pct = math.clamp(collectedCount / targetCount, 0, 1)
        tween(progressBar, {Size = UDim2.new(pct, 0, 1, 0)}, 0.2)
    elseif progressBar then
        tween(progressBar, {Size = UDim2.new(0,0,1,0)}, 0.2)
    end
    if progressText then
        if targetCount > 0 then
            progressText.Text = math.floor((collectedCount/targetCount)*100) .. "%"
        else
            progressText.Text = "0%"
        end
    end
    if statusLabel then
        if isCollecting then
            statusLabel.Text = "● Собираю  " .. collectedCount .. " / " .. targetCount
            statusLabel.TextColor3 = Color3.fromRGB(34,197,94)
        elseif collectedCount > 0 and collectedCount >= targetCount and targetCount > 0 then
            statusLabel.Text = "✓ Готово — " .. collectedCount .. " / " .. targetCount
            statusLabel.TextColor3 = Color3.fromRGB(16,185,129)
        elseif collectedCount > 0 then
            statusLabel.Text = "○ Остановлено — " .. collectedCount .. " / " .. targetCount
            statusLabel.TextColor3 = Color3.fromRGB(245,158,11)
        else
            statusLabel.Text = "○ Ожидание"
            statusLabel.TextColor3 = Color3.fromRGB(125,125,135)
        end
    end
    if coinsHeaderSub then
        if #coinsCache == 0 then
            coinsHeaderSub.Text = "Нажми Scan чтобы найти монеты в MutationCoins"
        else
            coinsHeaderSub.Text = string.format("%d монет найдено  •  укажи сколько собрать", #coinsCache)
        end
    end
    -- обновить счётчик в категории слева
    if _G.__updateCoinsCount then _G.__updateCoinsCount(#coinsCache) end
end

local function doCoinsScan(showToast)
    local res, err = scanMutationCoins()
    if err then
        coinsCache = {}
        notify("Coins", err)
        if showToast and _G.__teleportToast then _G.__teleportToast("Ошибка", err) end
    else
        coinsCache = res
        if showToast then
            notify("Coins", string.format("Найдено монет: %d", #res))
            if _G.__teleportToast then _G.__teleportToast("Сканирование", string.format("Найдено %d MutationCoin", #res)) end
        end
    end
    updateCoinsUI()
    return res
end

local collectThread = nil
local function startCollecting()
    if isCollecting then return end
    local amount = tonumber(amountBox.Text)
    if not amount or amount <= 0 then
        notify("Coins", "Укажи количество > 0")
        if _G.__teleportToast then _G.__teleportToast("Ошибка", "Количество должно быть > 0") end
        return
    end
    amount = math.floor(amount)
    if amount > 9999 then amount = 9999 end
    -- если кеш пуст — скан
    if #coinsCache == 0 then doCoinsScan(false) end
    if #coinsCache == 0 then
        notify("Coins", "Монеты не найдены")
        return
    end
    if amount > #coinsCache then
        notify("Coins", string.format("Нашлось только %d монет, соберу их", #coinsCache))
        amount = #coinsCache
        amountBox.Text = tostring(amount)
    end
    targetCount = amount
    collectedCount = 0
    isCollecting = true
    startBtn.Visible = false
    stopBtn.Visible = true
    -- берём снепшот монет на момент старта
    local snapshot = {}
    for i=1, math.min(targetCount, #coinsCache) do snapshot[i] = coinsCache[i] end
    updateCoinsUI()
    notify("Coins", string.format("Старт сбора %d монет", targetCount))

    collectThread = task.spawn(function()
        for idx, coin in ipairs(snapshot) do
            if not isCollecting then break end
            -- если монету уже собрали (исчезла) — скипаем но считаем?
            if coin.obj and not coin.obj.Parent then
                -- пробуем найти замену: берём следующую из актуального кеша
                -- но проще пропускаем
                collectedCount += 1
                updateCoinsUI()
                task.wait(0.05)
                continue
            end
            local pos = coin.pos
            -- телепорт точно на монету (без +3, но +1.2 чтобы не застрять)
            local char = LocalPlayer.Character
            if not char then char = LocalPlayer.CharacterAdded:Wait() end
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if not hrp then
                hrp = char:WaitForChild("HumanoidRootPart", 2)
            end
            if hrp then
                -- используем exact rounded pos + небольшой оффсет по Y
                local target = CFrame.new(pos.X, pos.Y + 1.2, pos.Z)
                -- инстант для сбора монет — надёжнее чем твин
                hrp.CFrame = target
                pcall(function() hrp.AssemblyLinearVelocity = Vector3.zero end)
                hrp.Velocity = Vector3.zero
            end
            collectedCount += 1
            updateCoinsUI()
            task.wait(0.2)
        end
        isCollecting = false
        if startBtn then startBtn.Visible = true end
        if stopBtn then stopBtn.Visible = false end
        updateCoinsUI()
        if collectedCount >= targetCount then
            notify("Coins", string.format("Готово! Собрано %d/%d", collectedCount, targetCount))
            if _G.__teleportToast then _G.__teleportToast("Готово ✓", string.format("Собрано %d монет", collectedCount)) end
        else
            notify("Coins", string.format("Остановлено %d/%d", collectedCount, targetCount))
        end
    end)
end

local function stopCollecting()
    if not isCollecting then return end
    isCollecting = false
    if collectThread then task.cancel(collectThread) end
    if startBtn then startBtn.Visible = true end
    if stopBtn then stopBtn.Visible = false end
    updateCoinsUI()
    notify("Coins", "Остановлено")
end

-- // Player TP helpers (for Teleporting bottom section)
local playerSearchText = ""
local playerListFrame, playerSearchBox, playerCountLabel, playerRefreshBtn
local function getHRP(char)
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart")
end
local function teleportToPlayer(targetPlayer)
    if not targetPlayer or not targetPlayer.Character then
        notify("Игрок", "У игрока нет персонажа")
        return
    end
    local targetHRP = getHRP(targetPlayer.Character)
    if not targetHRP then
        notify("Игрок", "HumanoidRootPart цели не найден")
        return
    end
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local hrp = char:WaitForChild("HumanoidRootPart", 5)
    if not hrp then return end
    -- тп чуть в сторону от цели чтобы не застрять внутри
    local offset = targetHRP.CFrame.LookVector * 3 + Vector3.new(0, 1.5, 0)
    local target = CFrame.new(targetHRP.Position + offset)
    -- прямой CFrame + обнуление скорости
    hrp.CFrame = target
    pcall(function() hrp.AssemblyLinearVelocity = Vector3.zero end)
    hrp.Velocity = Vector3.zero
    notify("Телепорт → " .. targetPlayer.Name, string.format("К игроку %s (@%s)", targetPlayer.DisplayName, targetPlayer.Name))
    if _G.__teleportToast then _G.__teleportToast("→ " .. targetPlayer.Name, string.format("X:%.0f Y:%.0f Z:%.0f", targetHRP.Position.X, targetHRP.Position.Y, targetHRP.Position.Z)) end
end

local function refreshPlayerList()
    if not playerListFrame then return end
    -- очищаем старые
    for _, ch in ipairs(playerListFrame:GetChildren()) do
        if ch:IsA("Frame") or ch:IsA("TextButton") then ch:Destroy() end
    end
    local players = Players:GetPlayers()
    -- фильтр
    local filtered = {}
    local q = playerSearchText:lower():gsub("%s+", "")
    for _, p in ipairs(players) do
        if p ~= LocalPlayer then
            if q == "" or p.Name:lower():find(q, 1, true) or p.DisplayName:lower():find(q, 1, true) then
                table.insert(filtered, p)
            end
        end
    end
    table.sort(filtered, function(a,b) return a.Name:lower() < b.Name:lower() end)
    if playerCountLabel then
        playerCountLabel.Text = #filtered .. " игроков" .. (q ~= "" and " • фильтр" or "")
    end
    if #filtered == 0 then
        local empty = Instance.new("TextLabel")
        empty.BackgroundTransparency = 1
        empty.Size = UDim2.new(1, -8, 0, 32)
        empty.Font = Enum.Font.Gotham
        empty.Text = (q ~= "" and "Никого не найдено" or "Нет других игроков")
        empty.TextColor3 = Color3.fromRGB(110,110,125)
        empty.TextSize = 11
        empty.Parent = playerListFrame
        return
    end
    for _, p in ipairs(filtered) do
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, -6, 0, 34)
        row.BackgroundColor3 = Color3.fromRGB(26,26,32)
        row.BorderSizePixel = 0
        row.Parent = playerListFrame
        local rc = Instance.new("UICorner")
        rc.CornerRadius = UDim.new(0, 8)
        rc.Parent = row
        local rs = Instance.new("UIStroke")
        rs.Color = Color3.fromRGB(45,45,55)
        rs.Transparency = 0.6
        rs.Parent = row
        local avatar = Instance.new("Frame")
        avatar.Size = UDim2.fromOffset(24,24)
        avatar.Position = UDim2.fromOffset(6, 5)
        avatar.BackgroundColor3 = Color3.fromRGB(124,92,255)
        avatar.BackgroundTransparency = 0.85
        avatar.Parent = row
        local ac = Instance.new("UICorner")
        ac.CornerRadius = UDim.new(1,0)
        ac.Parent = avatar
        local al = Instance.new("TextLabel")
        al.BackgroundTransparency = 1
        al.Size = UDim2.fromScale(1,1)
        al.Font = Enum.Font.GothamBold
        al.Text = p.DisplayName:sub(1,1):upper()
        al.TextColor3 = Color3.fromRGB(124,92,255)
        al.TextSize = 12
        al.Parent = avatar
        -- аватар упрощён до инициала (убрал GetUserThumbnailAsync — крашил Roblox при частом обновлении)
        local nameLbl = Instance.new("TextLabel")
        nameLbl.BackgroundTransparency = 1
        nameLbl.Position = UDim2.fromOffset(36, 4)
        nameLbl.Size = UDim2.new(1, -78, 0, 12)
        nameLbl.Font = Enum.Font.GothamBold
        nameLbl.Text = p.DisplayName
        nameLbl.TextColor3 = Color3.fromRGB(255,255,255)
        nameLbl.TextSize = 11
        nameLbl.TextXAlignment = Enum.TextXAlignment.Left
        nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
        nameLbl.Parent = row
        local userLbl = Instance.new("TextLabel")
        userLbl.BackgroundTransparency = 1
        userLbl.Position = UDim2.fromOffset(36, 18)
        userLbl.Size = UDim2.new(1, -78, 0, 10)
        userLbl.Font = Enum.Font.Gotham
        userLbl.Text = "@" .. p.Name
        userLbl.TextColor3 = Color3.fromRGB(130,130,145)
        userLbl.TextSize = 10
        userLbl.TextXAlignment = Enum.TextXAlignment.Left
        userLbl.TextTruncate = Enum.TextTruncate.AtEnd
        userLbl.Parent = row
        local tpBtn = Instance.new("TextButton")
        tpBtn.Size = UDim2.fromOffset(36, 22)
        tpBtn.Position = UDim2.new(1, -42, 0.5, -11)
        tpBtn.BackgroundColor3 = Color3.fromRGB(124,92,255)
        tpBtn.Text = "TP"
        tpBtn.Font = Enum.Font.GothamBold
        tpBtn.TextSize = 10
        tpBtn.TextColor3 = Color3.fromRGB(255,255,255)
        tpBtn.AutoButtonColor = false
        tpBtn.Parent = row
        local tc = Instance.new("UICorner")
        tc.CornerRadius = UDim.new(0, 7)
        tc.Parent = tpBtn
        tpBtn.MouseEnter:Connect(function() tween(tpBtn, {BackgroundColor3 = Color3.fromRGB(91,141,239)}, 0.12) end)
        tpBtn.MouseLeave:Connect(function() tween(tpBtn, {BackgroundColor3 = Color3.fromRGB(124,92,255)}, 0.12) end)
        tpBtn.MouseButton1Click:Connect(function() teleportToPlayer(p) end)
        row.MouseEnter:Connect(function() tween(rs, {Transparency = 0.25, Color = Color3.fromRGB(124,92,255)}, 0.12) end)
        row.MouseLeave:Connect(function() tween(rs, {Transparency = 0.6, Color = Color3.fromRGB(45,45,55)}, 0.12) end)
    end
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

local blur = Instance.new("Frame")
blur.Name = "Backdrop"
blur.Size = UDim2.fromScale(1,1)
blur.BackgroundColor3 = Color3.fromRGB(10,10,14)
blur.BackgroundTransparency = 0.25
blur.Visible = false
blur.ZIndex = 0
blur.Parent = gui

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
dotGrad.Color = ColorSequence.new{ColorSequenceKeypoint.new(0, Color3.fromRGB(124,92,255)), ColorSequenceKeypoint.new(1, Color3.fromRGB(91,141,239))}
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
subtitle.Text = "•  v1.0.2  —  ] to toggle"
subtitle.TextColor3 = Color3.fromRGB(125,125,135)
subtitle.TextSize = 11
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.Parent = titleWrap

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
    btn.MouseEnter:Connect(function() tween(btn, {BackgroundColor3 = hover, TextColor3 = Color3.fromRGB(255,255,255)}, 0.15) end)
    btn.MouseLeave:Connect(function() tween(btn, {BackgroundColor3 = Color3.fromRGB(32,32,38), TextColor3 = Color3.fromRGB(170,170,180)}, 0.15) end)
    return btn
end

local minimizeBtn = makeControl("—", 0, Color3.fromRGB(45,45,55))
local closeBtn = makeControl("✕", 38, Color3.fromRGB(239,68,68))

local divider = Instance.new("Frame")
divider.Size = UDim2.new(1, 0, 0, 1)
divider.Position = UDim2.fromOffset(0, 52)
divider.BackgroundColor3 = Color3.fromRGB(45,45,55)
divider.BorderSizePixel = 0
divider.Parent = main

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
rightArea.ClipsDescendants = true

-- ================= TELEPORT PAGE =================
local teleportPage = Instance.new("Frame")
teleportPage.Name = "TeleportPage"
teleportPage.Size = UDim2.fromScale(1,1)
teleportPage.BackgroundTransparency = 1
teleportPage.Visible = true
teleportPage.Parent = rightArea

local header = Instance.new("Frame")
header.BackgroundTransparency = 1
header.Size = UDim2.new(1, -24, 0, 48)
header.Position = UDim2.fromOffset(12, 8)
header.Parent = teleportPage

local headerTitle = Instance.new("TextLabel")
headerTitle.Name = "HeaderTitle"
headerTitle.BackgroundTransparency = 1
headerTitle.Position = UDim2.fromOffset(0, 0)
headerTitle.Size = UDim2.new(1, -80, 0, 20)
headerTitle.Font = Enum.Font.GothamBold
headerTitle.Text = "Teleporting"
headerTitle.TextColor3 = Color3.fromRGB(255,255,255)
headerTitle.TextSize = 18
headerTitle.TextXAlignment = Enum.TextXAlignment.Left
headerTitle.TextYAlignment = Enum.TextYAlignment.Bottom
headerTitle.Parent = header

local headerSub = Instance.new("TextLabel")
headerSub.BackgroundTransparency = 1
headerSub.Position = UDim2.fromOffset(0, 22)
headerSub.Size = UDim2.new(1, -80, 0, 14)
headerSub.Font = Enum.Font.Gotham
headerSub.Text = "12 locations  •  click to teleport"
headerSub.TextColor3 = Color3.fromRGB(125,125,135)
headerSub.TextSize = 11
headerSub.TextXAlignment = Enum.TextXAlignment.Left
headerSub.TextYAlignment = Enum.TextYAlignment.Top
headerSub.Parent = header

local badge = Instance.new("Frame")
badge.Size = UDim2.fromOffset(64, 24)
badge.Position = UDim2.new(1, -64, 0, 11)
badge.BackgroundColor3 = Color3.fromRGB(124,92,255)
badge.Parent = header
local badgeCorner = Instance.new("UICorner")
badgeCorner.CornerRadius = UDim.new(1,0)
badgeCorner.Parent = badge
local badgeGrad = Instance.new("UIGradient")
badgeGrad.Color = ColorSequence.new{ColorSequenceKeypoint.new(0, Color3.fromRGB(124,92,255)), ColorSequenceKeypoint.new(1, Color3.fromRGB(91,141,239))}
badgeGrad.Rotation = 90
badgeGrad.Parent = badge
local badgeText = Instance.new("TextLabel")
badgeText.BackgroundTransparency = 1
badgeText.Size = UDim2.fromScale(1,1)
badgeText.Font = Enum.Font.GothamBold
badgeText.Text = "12 PTS"
badgeText.TextColor3 = Color3.fromRGB(255,255,255)
badgeText.TextSize = 10
badgeText.Parent = badge

local outerScroll=Instance.new("ScrollingFrame") outerScroll.Name="OuterScroll" outerScroll.Position=UDim2.fromOffset(12,62) outerScroll.Size=UDim2.new(1,-24,1,-74) outerScroll.BackgroundTransparency=1 outerScroll.BorderSizePixel=0 outerScroll.CanvasSize=UDim2.new(0,0,0,0) outerScroll.ScrollBarThickness=4 outerScroll.ScrollBarImageColor3=Color3.fromRGB(65,65,75) outerScroll.Parent=teleportPage
local stack=Instance.new("Frame") stack.Name="Stack" stack.Size=UDim2.new(1,-4,0,600) stack.BackgroundTransparency=1 stack.Parent=outerScroll local stackLayout=Instance.new("UIListLayout") stackLayout.Padding=UDim.new(0,10) stackLayout.SortOrder=Enum.SortOrder.LayoutOrder stackLayout.Parent=stack local stackPad=Instance.new("UIPadding") stackPad.PaddingTop=UDim.new(0,2) stackPad.PaddingBottom=UDim.new(0,6) stackPad.Parent=stack
local gridFrame=Instance.new("Frame") gridFrame.Name="GridFrame" gridFrame.Size=UDim2.new(1,0,0,388) gridFrame.BackgroundTransparency=1 gridFrame.LayoutOrder=1 gridFrame.Parent=stack
local grid=Instance.new("UIGridLayout") grid.CellPadding=UDim2.fromOffset(8,8) grid.CellSize=UDim2.fromOffset(212,56) grid.FillDirectionMaxCells=2 grid.HorizontalAlignment=Enum.HorizontalAlignment.Left grid.SortOrder=Enum.SortOrder.LayoutOrder grid.Parent=gridFrame
-- players section now inside same scroll, below grid
local playersSection=Instance.new("Frame") playersSection.Name="PlayersSection" playersSection.Size=UDim2.new(1,0,0,120) playersSection.BackgroundColor3=Color3.fromRGB(20,20,25) playersSection.LayoutOrder=2 playersSection.Parent=stack local psc=Instance.new("UICorner") psc.CornerRadius=UDim.new(0,12) psc.Parent=playersSection local pss=Instance.new("UIStroke") pss.Color=Color3.fromRGB(45,45,55) pss.Transparency=0.4 pss.Parent=playersSection local psp=Instance.new("UIPadding") psp.PaddingTop=UDim.new(0,10) psp.PaddingBottom=UDim.new(0,10) psp.PaddingLeft=UDim.new(0,10) psp.PaddingRight=UDim.new(0,10) psp.Parent=playersSection
local psHeader=Instance.new("Frame") psHeader.BackgroundTransparency=1 psHeader.Size=UDim2.new(1,0,0,18) psHeader.Parent=playersSection local psTitle=Instance.new("TextLabel") psTitle.BackgroundTransparency=1 psTitle.Size=UDim2.new(1,-90,1,0) psTitle.Font=Enum.Font.GothamBold psTitle.Text="Teleport to Player" psTitle.TextColor3=Color3.fromRGB(255,255,255) psTitle.TextSize=11 psTitle.Parent=psHeader playerCountLabel=Instance.new("TextLabel") playerCountLabel.BackgroundTransparency=1 playerCountLabel.Position=UDim2.new(1,-90,0,0) playerCountLabel.Size=UDim2.new(0,90,1,0) playerCountLabel.Font=Enum.Font.Gotham playerCountLabel.Text="0 игроков" playerCountLabel.TextColor3=Color3.fromRGB(110,110,125) playerCountLabel.TextSize=10 playerCountLabel.TextXAlignment=Enum.TextXAlignment.Right playerCountLabel.Parent=psHeader
local psSearchRow=Instance.new("Frame") psSearchRow.BackgroundTransparency=1 psSearchRow.Size=UDim2.new(1,0,0,26) psSearchRow.Parent=playersSection local psl=Instance.new("UIListLayout") psl.FillDirection=Enum.FillDirection.Horizontal psl.Padding=UDim.new(0,6) psl.VerticalAlignment=Enum.VerticalAlignment.Center psl.Parent=psSearchRow
local sbf=Instance.new("Frame") sbf.Size=UDim2.new(1,-42,0,26) sbf.BackgroundColor3=Color3.fromRGB(26,26,32) sbf.Parent=psSearchRow local sbfc=Instance.new("UICorner") sbfc.CornerRadius=UDim.new(0,8) sbfc.Parent=sbf local sbfs=Instance.new("UIStroke") sbfs.Color=Color3.fromRGB(55,55,65) sbfs.Transparency=0.4 sbfs.Parent=sbf local si=Instance.new("TextLabel") si.BackgroundTransparency=1 si.Size=UDim2.fromOffset(22,26) si.Font=Enum.Font.Gotham si.Text="⌕" si.TextColor3=Color3.fromRGB(110,110,125) si.TextSize=13 si.Parent=sbf playerSearchBox=Instance.new("TextBox") playerSearchBox.BackgroundTransparency=1 playerSearchBox.Position=UDim2.fromOffset(22,0) playerSearchBox.Size=UDim2.new(1,-28,1,0) playerSearchBox.Font=Enum.Font.Gotham playerSearchBox.PlaceholderText="Поиск по нику..." playerSearchBox.Text="" playerSearchBox.TextColor3=Color3.fromRGB(255,255,255) playerSearchBox.PlaceholderColor3=Color3.fromRGB(110,110,125) playerSearchBox.TextSize=11 playerSearchBox.ClearTextOnFocus=false playerSearchBox.Parent=sbf
playerRefreshBtn=Instance.new("TextButton") playerRefreshBtn.Size=UDim2.fromOffset(32,26) playerRefreshBtn.BackgroundColor3=Color3.fromRGB(32,32,38) playerRefreshBtn.Text="↻" playerRefreshBtn.Font=Enum.Font.GothamBold playerRefreshBtn.TextSize=13 playerRefreshBtn.TextColor3=Color3.fromRGB(170,170,180) playerRefreshBtn.Parent=psSearchRow local prc=Instance.new("UICorner") prc.CornerRadius=UDim.new(0,8) prc.Parent=playerRefreshBtn
local psListHolder=Instance.new("Frame") psListHolder.Name="PlayersListHolder" psListHolder.BackgroundTransparency=1 psListHolder.Size=UDim2.new(1,0,0,60) psListHolder.Parent=playersSection playerListFrame=Instance.new("Frame") playerListFrame.BackgroundTransparency=1 playerListFrame.Size=UDim2.new(1,0,1,0) playerListFrame.Parent=psListHolder local pll=Instance.new("UIListLayout") pll.Padding=UDim.new(0,4) pll.SortOrder=Enum.SortOrder.LayoutOrder pll.Parent=playerListFrame
-- toast
-- ================= COINS PAGE =================
local coinsPage = Instance.new("Frame")
coinsPage.Name = "CoinsPage"
coinsPage.Size = UDim2.fromScale(1,1)
coinsPage.BackgroundTransparency = 1
coinsPage.Visible = false
coinsPage.Parent = rightArea

local cHeader = Instance.new("Frame")
cHeader.BackgroundTransparency = 1
cHeader.Size = UDim2.new(1, -24, 0, 48)
cHeader.Position = UDim2.fromOffset(12, 8)
cHeader.Parent = coinsPage

local cHeaderTitle = Instance.new("TextLabel")
cHeaderTitle.BackgroundTransparency = 1
cHeaderTitle.Position = UDim2.fromOffset(0, 0)
cHeaderTitle.Size = UDim2.new(1, -90, 0, 20)
cHeaderTitle.Font = Enum.Font.GothamBold
cHeaderTitle.Text = "Coins Collecting"
cHeaderTitle.TextColor3 = Color3.fromRGB(255,255,255)
cHeaderTitle.TextSize = 18
cHeaderTitle.TextXAlignment = Enum.TextXAlignment.Left
cHeaderTitle.TextYAlignment = Enum.TextYAlignment.Bottom
cHeaderTitle.Parent = cHeader

coinsHeaderSub = Instance.new("TextLabel")
coinsHeaderSub.BackgroundTransparency = 1
coinsHeaderSub.Position = UDim2.fromOffset(0, 22)
coinsHeaderSub.Size = UDim2.new(1, -90, 0, 14)
coinsHeaderSub.Font = Enum.Font.Gotham
coinsHeaderSub.Text = "Нажми Scan чтобы найти монеты в MutationCoins"
coinsHeaderSub.TextColor3 = Color3.fromRGB(125,125,135)
coinsHeaderSub.TextSize = 11
coinsHeaderSub.TextXAlignment = Enum.TextXAlignment.Left
coinsHeaderSub.TextYAlignment = Enum.TextYAlignment.Top
coinsHeaderSub.Parent = cHeader

coinsBadge = Instance.new("Frame")
coinsBadge.Size = UDim2.fromOffset(74, 24)
coinsBadge.Position = UDim2.new(1, -74, 0, 11)
coinsBadge.BackgroundColor3 = Color3.fromRGB(124,92,255)
coinsBadge.Parent = cHeader
local cbCorner = Instance.new("UICorner")
cbCorner.CornerRadius = UDim.new(1,0)
cbCorner.Parent = coinsBadge
local cbGrad = Instance.new("UIGradient")
cbGrad.Color = ColorSequence.new{ColorSequenceKeypoint.new(0, Color3.fromRGB(124,92,255)), ColorSequenceKeypoint.new(1, Color3.fromRGB(91,141,239))}
cbGrad.Rotation = 90
cbGrad.Parent = coinsBadge
coinsBadgeLabel = Instance.new("TextLabel")
coinsBadgeLabel.Name = "Label"
coinsBadgeLabel.BackgroundTransparency = 1
coinsBadgeLabel.Size = UDim2.fromScale(1,1)
coinsBadgeLabel.Font = Enum.Font.GothamBold
coinsBadgeLabel.Text = "0 COINS"
coinsBadgeLabel.TextColor3 = Color3.fromRGB(255,255,255)
coinsBadgeLabel.TextSize = 10
coinsBadgeLabel.Parent = coinsBadge

local coinsScroll = Instance.new("ScrollingFrame")
coinsScroll.Name = "CoinsScroll"
coinsScroll.Position = UDim2.fromOffset(12, 62)
coinsScroll.Size = UDim2.new(1, -24, 1, -74)
coinsScroll.BackgroundTransparency = 1
coinsScroll.BorderSizePixel = 0
coinsScroll.CanvasSize = UDim2.new(0,0,0,540)
coinsScroll.ScrollBarThickness = 4
coinsScroll.ScrollBarImageColor3 = Color3.fromRGB(65,65,75)
coinsScroll.ScrollingDirection = Enum.ScrollingDirection.Y
coinsScroll.Parent = coinsPage

local coinsList = Instance.new("Frame")
coinsList.BackgroundTransparency = 1
coinsList.Size = UDim2.new(1, 0, 1, 0)
coinsList.Parent = coinsScroll
local coinsLayout = Instance.new("UIListLayout")
coinsLayout.Padding = UDim.new(0, 10)
coinsLayout.SortOrder = Enum.SortOrder.LayoutOrder
coinsLayout.Parent = coinsList
local coinsPad = Instance.new("UIPadding")
coinsPad.PaddingTop = UDim.new(0, 2)
coinsPad.PaddingRight = UDim.new(0, 4)
coinsPad.Parent = coinsScroll

-- Card helper
local function makeCoinsCard(height)
    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, -4, 0, height)
    card.BackgroundColor3 = Color3.fromRGB(26,26,32)
    card.BorderSizePixel = 0
    card.Parent = coinsList
    local cc = Instance.new("UICorner")
    cc.CornerRadius = UDim.new(0, 12)
    cc.Parent = card
    local cs = Instance.new("UIStroke")
    cs.Color = Color3.fromRGB(45,45,55)
    cs.Transparency = 0.5
    cs.Thickness = 1
    cs.Parent = card
    return card
end

-- 1) Scan card
local scanCard = makeCoinsCard(66)
local scanIcon = Instance.new("Frame")
scanIcon.Size = UDim2.fromOffset(36,36)
scanIcon.Position = UDim2.fromOffset(12, 15)
scanIcon.BackgroundColor3 = Color3.fromRGB(124,92,255)
scanIcon.BackgroundTransparency = 0.88
scanIcon.Parent = scanCard
local siC = Instance.new("UICorner")
siC.CornerRadius = UDim.new(1,0)
siC.Parent = scanIcon
local siS = Instance.new("UIStroke")
siS.Color = Color3.fromRGB(124,92,255)
siS.Transparency = 0.6
siS.Parent = scanIcon
local siLbl = Instance.new("TextLabel")
siLbl.BackgroundTransparency = 1
siLbl.Size = UDim2.fromScale(1,1)
siLbl.Font = Enum.Font.GothamBold
siLbl.Text = "◯"
siLbl.TextColor3 = Color3.fromRGB(124,92,255)
siLbl.TextSize = 16
siLbl.Parent = scanIcon

local scanTitle = Instance.new("TextLabel")
scanTitle.BackgroundTransparency = 1
scanTitle.Position = UDim2.fromOffset(56, 12)
scanTitle.Size = UDim2.new(1, -140, 0, 14)
scanTitle.Font = Enum.Font.GothamBold
scanTitle.Text = "MutationCoins"
scanTitle.TextColor3 = Color3.fromRGB(255,255,255)
scanTitle.TextSize = 12
scanTitle.TextXAlignment = Enum.TextXAlignment.Left
scanTitle.Parent = scanCard

local scanDesc = Instance.new("TextLabel")
scanDesc.BackgroundTransparency = 1
scanDesc.Position = UDim2.fromOffset(56, 28)
scanDesc.Size = UDim2.new(1, -140, 0, 12)
scanDesc.Font = Enum.Font.Gotham
scanDesc.Text = "Workspace → MutationCoins → чанки"
scanDesc.TextColor3 = Color3.fromRGB(110,110,125)
scanDesc.TextSize = 10
scanDesc.TextXAlignment = Enum.TextXAlignment.Left
scanDesc.Parent = scanCard

foundLabel = Instance.new("TextLabel")
foundLabel.BackgroundTransparency = 1
foundLabel.Position = UDim2.fromOffset(56, 42)
foundLabel.Size = UDim2.new(1, -140, 0, 12)
foundLabel.Font = Enum.Font.GothamBold
foundLabel.Text = "Найдено: 0"
foundLabel.TextColor3 = Color3.fromRGB(16,185,129)
foundLabel.TextSize = 11
foundLabel.TextXAlignment = Enum.TextXAlignment.Left
foundLabel.Parent = scanCard

scanBtn = Instance.new("TextButton")
scanBtn.Size = UDim2.fromOffset(72, 32)
scanBtn.Position = UDim2.new(1, -84, 0.5, -16)
scanBtn.BackgroundColor3 = Color3.fromRGB(124,92,255)
scanBtn.Text = "SCAN"
scanBtn.Font = Enum.Font.GothamBold
scanBtn.TextColor3 = Color3.fromRGB(255,255,255)
scanBtn.TextSize = 11
scanBtn.AutoButtonColor = false
scanBtn.Parent = scanCard
local sbC = Instance.new("UICorner")
sbC.CornerRadius = UDim.new(0, 8)
sbC.Parent = scanBtn
local sbG = Instance.new("UIGradient")
sbG.Color = ColorSequence.new{ColorSequenceKeypoint.new(0, Color3.fromRGB(124,92,255)), ColorSequenceKeypoint.new(1, Color3.fromRGB(91,141,239))}
sbG.Rotation = 90
sbG.Parent = scanBtn

-- 2) Amount card
local amountCard = makeCoinsCard(84)
local amtLabel = Instance.new("TextLabel")
amtLabel.BackgroundTransparency = 1
amtLabel.Position = UDim2.fromOffset(14, 12)
amtLabel.Size = UDim2.new(1, -28, 0, 14)
amtLabel.Font = Enum.Font.GothamBold
amtLabel.Text = "Сколько монет собрать"
amtLabel.TextColor3 = Color3.fromRGB(255,255,255)
amtLabel.TextSize = 12
amtLabel.TextXAlignment = Enum.TextXAlignment.Left
amtLabel.Parent = amountCard

local amtSub = Instance.new("TextLabel")
amtSub.BackgroundTransparency = 1
amtSub.Position = UDim2.fromOffset(14, 28)
amtSub.Size = UDim2.new(1, -28, 0, 12)
amtSub.Font = Enum.Font.Gotham
amtSub.Text = "Телепорт каждые 0.2с • WorldPivot → 3 знака"
amtSub.TextColor3 = Color3.fromRGB(110,110,125)
amtSub.TextSize = 10
amtSub.TextXAlignment = Enum.TextXAlignment.Left
amtSub.Parent = amountCard

local inputFrame = Instance.new("Frame")
inputFrame.Size = UDim2.new(1, -28, 0, 34)
inputFrame.Position = UDim2.fromOffset(14, 44)
inputFrame.BackgroundColor3 = Color3.fromRGB(20,20,25)
inputFrame.Parent = amountCard
local iC = Instance.new("UICorner")
iC.CornerRadius = UDim.new(0, 10)
iC.Parent = inputFrame
local iS = Instance.new("UIStroke")
iS.Color = Color3.fromRGB(55,55,65)
iS.Transparency = 0.3
iS.Parent = inputFrame

local minusBtn = Instance.new("TextButton")
minusBtn.Size = UDim2.fromOffset(34, 34)
minusBtn.BackgroundColor3 = Color3.fromRGB(32,32,38)
minusBtn.Text = "−"
minusBtn.Font = Enum.Font.GothamBold
minusBtn.TextSize = 16
minusBtn.TextColor3 = Color3.fromRGB(180,180,190)
minusBtn.AutoButtonColor = false
minusBtn.Parent = inputFrame
local mC = Instance.new("UICorner")
mC.CornerRadius = UDim.new(0, 10)
mC.Parent = minusBtn

amountBox = Instance.new("TextBox")
amountBox.Size = UDim2.new(1, -72, 1, 0)
amountBox.Position = UDim2.fromOffset(36, 0)
amountBox.BackgroundTransparency = 1
amountBox.Text = "25"
amountBox.PlaceholderText = "0"
amountBox.Font = Enum.Font.GothamBold
amountBox.TextColor3 = Color3.fromRGB(255,255,255)
amountBox.TextSize = 15
amountBox.ClearTextOnFocus = false
amountBox.Parent = inputFrame

local plusBtn = Instance.new("TextButton")
plusBtn.Size = UDim2.fromOffset(34, 34)
plusBtn.Position = UDim2.new(1, -34, 0, 0)
plusBtn.BackgroundColor3 = Color3.fromRGB(124,92,255)
plusBtn.Text = "+"
plusBtn.Font = Enum.Font.GothamBold
plusBtn.TextSize = 16
plusBtn.TextColor3 = Color3.fromRGB(255,255,255)
plusBtn.AutoButtonColor = false
plusBtn.Parent = inputFrame
local pC = Instance.new("UICorner")
pC.CornerRadius = UDim.new(0, 10)
pC.Parent = plusBtn

-- quick presets
local presetRow = Instance.new("Frame")
presetRow.BackgroundTransparency = 1
presetRow.Size = UDim2.new(1, -4, 0, 22)
presetRow.Parent = coinsList
presetRow.LayoutOrder = 3
local pLayout = Instance.new("UIListLayout")
pLayout.FillDirection = Enum.FillDirection.Horizontal
pLayout.Padding = UDim.new(0, 6)
pLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
pLayout.Parent = presetRow
for _, v in ipairs({10,25,50,100,250}) do
    local b = Instance.new("TextButton")
    b.Size = UDim2.fromOffset(52, 22)
    b.BackgroundColor3 = Color3.fromRGB(32,32,38)
    b.Text = tostring(v)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 11
    b.TextColor3 = Color3.fromRGB(170,170,180)
    b.AutoButtonColor = false
    b.Parent = presetRow
    local cc2 = Instance.new("UICorner")
    cc2.CornerRadius = UDim.new(1,0)
    cc2.Parent = b
    b.MouseButton1Click:Connect(function() amountBox.Text = tostring(v) updateCoinsUI() end)
    b.MouseEnter:Connect(function() tween(b, {BackgroundColor3 = Color3.fromRGB(45,45,55), TextColor3 = Color3.fromRGB(255,255,255)}, 0.12) end)
    b.MouseLeave:Connect(function() tween(b, {BackgroundColor3 = Color3.fromRGB(32,32,38), TextColor3 = Color3.fromRGB(170,170,180)}, 0.12) end)
end
local maxBtn = Instance.new("TextButton")
maxBtn.Size = UDim2.fromOffset(52, 22)
maxBtn.BackgroundColor3 = Color3.fromRGB(26,26,32)
maxBtn.Text = "MAX"
maxBtn.Font = Enum.Font.GothamBold
maxBtn.TextSize = 10
maxBtn.TextColor3 = Color3.fromRGB(124,92,255)
maxBtn.AutoButtonColor = false
maxBtn.Parent = presetRow
local m2C = Instance.new("UICorner")
m2C.CornerRadius = UDim.new(1,0)
m2C.Parent = maxBtn
local m2S = Instance.new("UIStroke")
m2S.Color = Color3.fromRGB(124,92,255)
m2S.Transparency = 0.5
m2S.Parent = maxBtn
maxBtn.MouseButton1Click:Connect(function()
    if #coinsCache > 0 then amountBox.Text = tostring(#coinsCache) else doCoinsScan(false) amountBox.Text = tostring(#coinsCache) end
    updateCoinsUI()
end)

-- 3) Progress card
local progCard = makeCoinsCard(72)
progCard.LayoutOrder = 4
local progTitle = Instance.new("TextLabel")
progTitle.BackgroundTransparency = 1
progTitle.Position = UDim2.fromOffset(14, 12)
progTitle.Size = UDim2.new(1, -28, 0, 14)
progTitle.Font = Enum.Font.GothamBold
progTitle.Text = "Прогресс"
progTitle.TextColor3 = Color3.fromRGB(255,255,255)
progTitle.TextSize = 12
progTitle.TextXAlignment = Enum.TextXAlignment.Left
progTitle.Parent = progCard

toCollectLabel = Instance.new("TextLabel")
toCollectLabel.BackgroundTransparency = 1
toCollectLabel.Position = UDim2.fromOffset(14, 30)
toCollectLabel.Size = UDim2.fromOffset(90, 12)
toCollectLabel.Font = Enum.Font.Gotham
toCollectLabel.Text = "К сбору: 0"
toCollectLabel.TextColor3 = Color3.fromRGB(110,110,125)
toCollectLabel.TextSize = 10
toCollectLabel.TextXAlignment = Enum.TextXAlignment.Left
toCollectLabel.Parent = progCard

collectedLabel = Instance.new("TextLabel")
collectedLabel.BackgroundTransparency = 1
collectedLabel.Position = UDim2.fromOffset(110, 30)
collectedLabel.Size = UDim2.new(1, -124, 0, 12)
collectedLabel.Font = Enum.Font.GothamBold
collectedLabel.Text = "Собрано: 0 / 0"
collectedLabel.TextColor3 = Color3.fromRGB(125,125,135)
collectedLabel.TextSize = 10
collectedLabel.TextXAlignment = Enum.TextXAlignment.Left
collectedLabel.Parent = progCard

local barBg = Instance.new("Frame")
barBg.Size = UDim2.new(1, -28, 0, 10)
barBg.Position = UDim2.fromOffset(14, 48)
barBg.BackgroundColor3 = Color3.fromRGB(20,20,25)
barBg.Parent = progCard
local bC = Instance.new("UICorner")
bC.CornerRadius = UDim.new(1,0)
bC.Parent = barBg

progressBar = Instance.new("Frame")
progressBar.Size = UDim2.new(0, 0, 1, 0)
progressBar.BackgroundColor3 = Color3.fromRGB(16,185,129)
progressBar.Parent = barBg
local pbC = Instance.new("UICorner")
pbC.CornerRadius = UDim.new(1,0)
pbC.Parent = progressBar
local pbG = Instance.new("UIGradient")
pbG.Color = ColorSequence.new{ColorSequenceKeypoint.new(0, Color3.fromRGB(16,185,129)), ColorSequenceKeypoint.new(1, Color3.fromRGB(52,211,153))}
pbG.Rotation = 0
pbG.Parent = progressBar

progressText = Instance.new("TextLabel")
progressText.BackgroundTransparency = 1
progressText.Position = UDim2.new(0,0,0,0)
progressText.Size = UDim2.fromScale(1,1)
progressText.Font = Enum.Font.GothamBold
progressText.Text = "0%"
progressText.TextColor3 = Color3.fromRGB(255,255,255)
progressText.TextSize = 8
progressText.Parent = barBg

-- 4) Control card
local ctrlCard = makeCoinsCard(84)
ctrlCard.LayoutOrder = 5
statusLabel = Instance.new("TextLabel")
statusLabel.BackgroundTransparency = 1
statusLabel.Position = UDim2.fromOffset(14, 12)
statusLabel.Size = UDim2.new(1, -28, 0, 14)
statusLabel.Font = Enum.Font.GothamBold
statusLabel.Text = "○ Ожидание"
statusLabel.TextColor3 = Color3.fromRGB(125,125,135)
statusLabel.TextSize = 11
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.Parent = ctrlCard

local hint = Instance.new("TextLabel")
hint.BackgroundTransparency = 1
hint.Position = UDim2.fromOffset(14, 28)
hint.Size = UDim2.new(1, -28, 0, 12)
hint.Font = Enum.Font.Gotham
hint.Text = "Телепорт на WorldPivot (3 знака) каждые 0.2с"
hint.TextColor3 = Color3.fromRGB(90,90,105)
hint.TextSize = 10
hint.TextXAlignment = Enum.TextXAlignment.Left
hint.Parent = ctrlCard

startBtn = Instance.new("TextButton")
startBtn.Size = UDim2.new(1, -28, 0, 32)
startBtn.Position = UDim2.fromOffset(14, 46)
startBtn.BackgroundColor3 = Color3.fromRGB(16,185,129)
startBtn.Text = "▶  START COLLECTING"
startBtn.Font = Enum.Font.GothamBold
startBtn.TextSize = 12
startBtn.TextColor3 = Color3.fromRGB(255,255,255)
startBtn.AutoButtonColor = false
startBtn.Parent = ctrlCard
local stC = Instance.new("UICorner")
stC.CornerRadius = UDim.new(0, 10)
stC.Parent = startBtn
local stG = Instance.new("UIGradient")
stG.Color = ColorSequence.new{ColorSequenceKeypoint.new(0, Color3.fromRGB(16,185,129)), ColorSequenceKeypoint.new(1, Color3.fromRGB(6,182,214))}
stG.Rotation = 90
stG.Parent = startBtn

stopBtn = Instance.new("TextButton")
stopBtn.Size = UDim2.new(1, -28, 0, 32)
stopBtn.Position = UDim2.fromOffset(14, 46)
stopBtn.BackgroundColor3 = Color3.fromRGB(239,68,68)
stopBtn.Text = "■  STOP"
stopBtn.Font = Enum.Font.GothamBold
stopBtn.TextSize = 12
stopBtn.TextColor3 = Color3.fromRGB(255,255,255)
stopBtn.Visible = false
stopBtn.AutoButtonColor = false
stopBtn.Parent = ctrlCard
local spC = Instance.new("UICorner")
spC.CornerRadius = UDim.new(0, 10)
spC.Parent = stopBtn

-- Toast container
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

-- Build Categories with switching
local selectedCategory = "teleporting"
local categoryButtons = {}
local pageMap = {teleporting = teleportPage, coins = coinsPage}

local function selectCategory(id)
    if selectedCategory == id then return end
    selectedCategory = id
    for cid, btn in pairs(categoryButtons) do
        local isSel = cid == id
        local grad = btn:FindFirstChild("Grad")
        local iconBox = btn:FindFirstChild("IconBox") or btn:FindFirstChildWhichIsA("Frame")
        -- find by position
        for _, child in ipairs(btn:GetChildren()) do
            if child:IsA("Frame") then iconBox = child break end
        end
        if isSel then
            tween(btn, {BackgroundColor3 = Color3.fromRGB(124,92,255)}, 0.15)
            if not grad then
                local g = Instance.new("UIGradient")
                g.Name = "Grad"
                g.Color = ColorSequence.new{ColorSequenceKeypoint.new(0, Color3.fromRGB(124,92,255)), ColorSequenceKeypoint.new(1, Color3.fromRGB(91,141,239))}
                g.Rotation = 90
                g.Parent = btn
            end
            if iconBox then
                tween(iconBox, {BackgroundColor3 = Color3.fromRGB(255,255,255), BackgroundTransparency = 0.15}, 0.15)
                local icLbl = iconBox:FindFirstChildWhichIsA("TextLabel")
                if icLbl then tween(icLbl, {TextColor3 = Color3.fromRGB(124,92,255)}, 0.15) end
            end
            for _, lbl in ipairs(btn:GetChildren()) do
                if lbl:IsA("TextLabel") then
                    if lbl.Position.X.Offset == 42 and lbl.Position.Y.Offset == 6 then tween(lbl, {TextColor3 = Color3.fromRGB(255,255,255)}, 0.15)
                    elseif lbl.Position.Y.Offset == 20 then tween(lbl, {TextColor3 = Color3.fromRGB(220,220,255)}, 0.15) end
                end
            end
        else
            tween(btn, {BackgroundColor3 = Color3.fromRGB(26,26,32)}, 0.15)
            if grad then grad:Destroy() end
            if iconBox then
                tween(iconBox, {BackgroundColor3 = Color3.fromRGB(35,35,42), BackgroundTransparency = 0}, 0.15)
                local icLbl = iconBox:FindFirstChildWhichIsA("TextLabel")
                if icLbl then tween(icLbl, {TextColor3 = Color3.fromRGB(170,170,180)}, 0.15) end
            end
            for _, lbl in ipairs(btn:GetChildren()) do
                if lbl:IsA("TextLabel") then
                    if lbl.Position.X.Offset == 42 and lbl.Position.Y.Offset == 6 then tween(lbl, {TextColor3 = Color3.fromRGB(200,200,210)}, 0.15)
                    elseif lbl.Position.Y.Offset == 20 then tween(lbl, {TextColor3 = Color3.fromRGB(110,110,125)}, 0.15) end
                end
            end
        end
    end
    for cid, page in pairs(pageMap) do
        page.Visible = (cid == id)
    end
    -- заголовок бейджа не трогаем, но при переключении на coins делаем скан если пусто
    if id == "coins" and #coinsCache == 0 then
        task.spawn(function() task.wait(0.15) doCoinsScan(false) end)
    end
end

_G.__updateCoinsCount = function(count)
    local btn = categoryButtons["coins"]
    if not btn then return end
    for _, child in ipairs(btn:GetChildren()) do
        if child:IsA("TextLabel") and child.Position.Y.Offset == 20 then
            child.Text = count .. " coins"
        end
    end
end

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
        g.Color = ColorSequence.new{ColorSequenceKeypoint.new(0, Color3.fromRGB(124,92,255)), ColorSequenceKeypoint.new(1, Color3.fromRGB(91,141,239))}
        g.Rotation = 90
        g.Parent = btn
    end
    local iconBox = Instance.new("Frame")
    iconBox.Name = "IconBox"
    iconBox.Size = UDim2.fromOffset(28,28)
    iconBox.Position = UDim2.fromOffset(8,7)
    iconBox.BackgroundColor3 = (cat.id == selectedCategory) and Color3.fromRGB(255,255,255) or Color3.fromRGB(35,35,42)
    iconBox.BackgroundTransparency = (cat.id == selectedCategory) and 0.15 or 0
    iconBox.Parent = btn
    local ic2 = Instance.new("UICorner")
    ic2.CornerRadius = UDim.new(0, 8)
    ic2.Parent = iconBox
    local iconLbl = Instance.new("TextLabel")
    iconLbl.BackgroundTransparency = 1
    iconLbl.Size = UDim2.fromScale(1,1)
    iconLbl.Font = Enum.Font.GothamBold
    iconLbl.Text = cat.icon
    iconLbl.TextColor3 = (cat.id == selectedCategory) and Color3.fromRGB(124,92,255) or Color3.fromRGB(170,170,180)
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
    countLbl.Text = (cat.id == "coins") and "0 coins" or (cat.count .. " points")
    countLbl.TextColor3 = (cat.id == selectedCategory) and Color3.fromRGB(220,220,255) or Color3.fromRGB(110,110,125)
    countLbl.TextSize = 10
    countLbl.TextXAlignment = Enum.TextXAlignment.Left
    countLbl.Parent = btn
    categoryButtons[cat.id] = btn

    btn.MouseButton1Click:Connect(function() selectCategory(cat.id) end)
    if cat.id ~= selectedCategory then
        btn.MouseEnter:Connect(function() tween(btn, {BackgroundColor3 = Color3.fromRGB(34,34,42)}, 0.15) end)
        btn.MouseLeave:Connect(function() tween(btn, {BackgroundColor3 = Color3.fromRGB(26,26,32)}, 0.15) end)
    end
end

-- Build Teleport Cards (теперь в gridHolder внутри скролла)
for idx, tp in ipairs(TELEPORTS) do
    local card = Instance.new("TextButton")
    card.Name = tp.name
    card.BackgroundColor3 = Color3.fromRGB(26,26,32)
    card.BorderSizePixel = 0
    card.Text = ""
    card.AutoButtonColor = false
    card.LayoutOrder = idx
    card.Parent = gridFrame
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
        tween(card, {BackgroundColor3 = Color3.fromRGB(42,42,52)}, 0.08)
        task.wait(0.08)
        tween(card, {BackgroundColor3 = Color3.fromRGB(32,32,40)}, 0.12)
        tween(arrow, {BackgroundColor3 = Color3.fromRGB(255,255,255)}, 0.08)
        task.wait(0.08)
        tween(arrow, {BackgroundColor3 = tp.color}, 0.12)
        doTeleport(tp.x, tp.y, tp.z, tp.name)
    end)
end

-- handlers for coins UI
scanBtn.MouseButton1Click:Connect(function() doCoinsScan(true) end)
scanBtn.MouseEnter:Connect(function() tween(scanBtn, {BackgroundColor3 = Color3.fromRGB(91,141,239)}, 0.12) end)
scanBtn.MouseLeave:Connect(function() tween(scanBtn, {BackgroundColor3 = Color3.fromRGB(124,92,255)}, 0.12) end)

local function clampAmount()
    local n = tonumber(amountBox.Text)
    if not n then amountBox.Text = "0" return 0 end
    n = math.floor(n)
    if n < 0 then n = 0 end
    if n > 9999 then n = 9999 end
    amountBox.Text = tostring(n)
    return n
end

amountBox.FocusLost:Connect(function(enter)
    clampAmount() updateCoinsUI()
end)
amountBox:GetPropertyChangedSignal("Text"):Connect(function()
    -- только цифры
    local t = amountBox.Text
    local filtered = t:gsub("[^%d]", "")
    if filtered ~= t then amountBox.Text = filtered end
    -- не обновляем target пока не нажмут старт
end)

minusBtn.MouseButton1Click:Connect(function()
    local n = clampAmount() - 1
    if n < 0 then n = 0 end
    amountBox.Text = tostring(n)
end)
plusBtn.MouseButton1Click:Connect(function()
    local n = clampAmount() + 1
    if n > 9999 then n = 9999 end
    amountBox.Text = tostring(n)
end)
minusBtn.MouseEnter:Connect(function() tween(minusBtn, {BackgroundColor3 = Color3.fromRGB(45,45,55)}, 0.12) end)
minusBtn.MouseLeave:Connect(function() tween(minusBtn, {BackgroundColor3 = Color3.fromRGB(32,32,38)}, 0.12) end)
plusBtn.MouseEnter:Connect(function() tween(plusBtn, {BackgroundColor3 = Color3.fromRGB(91,141,239)}, 0.12) end)
plusBtn.MouseLeave:Connect(function() tween(plusBtn, {BackgroundColor3 = Color3.fromRGB(124,92,255)}, 0.12) end)

startBtn.MouseButton1Click:Connect(startCollecting)
stopBtn.MouseButton1Click:Connect(stopCollecting)
startBtn.MouseEnter:Connect(function() tween(startBtn, {BackgroundColor3 = Color3.fromRGB(6,182,214)}, 0.12) end)
startBtn.MouseLeave:Connect(function() tween(startBtn, {BackgroundColor3 = Color3.fromRGB(16,185,129)}, 0.12) end)

-- auto canvas size for teleport (просто грид)
task.spawn(function()
    task.wait(0.15)
    local function updateCanvas()
        local rows = math.ceil(#TELEPORTS / 2)
        local needed = rows * 64 + 4
        scroll.CanvasSize = UDim2.new(0, 0, 0, needed)
        -- players list canvas
        if psListHolder and playerListFrame then
            local need = playerListFrame.AbsoluteContentSize.Y + 4
            if need < 1 then need = 34 end
            psListHolder.CanvasSize = UDim2.new(0,0,0, need)
        end
    end
    updateCanvas()
    grid:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() task.wait() updateCanvas() end)
    if playerListFrame then
        playerListFrame:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() task.wait() updateCanvas() end)
    end
    scroll:GetPropertyChangedSignal("AbsoluteWindowSize"):Connect(updateCanvas)
    if psListHolder then
        psListHolder:GetPropertyChangedSignal("AbsoluteWindowSize"):Connect(updateCanvas)
    end
    for i=1,20 do task.wait(0.1) updateCanvas() end
end)

-- players search + refresh wiring
task.spawn(function() task.wait(0.15) local function upd() local rows=math.ceil(#TELEPORTS/2) local gridH=rows*64+4 gridFrame.Size=UDim2.new(1,0,0,gridH) local needPL=playerListFrame.AbsoluteContentSize.Y+4 if needPL<1 then needPL=34 end if needPL>120 then needPL=120 end psListHolder.Size=UDim2.new(1,0,0,needPL) local playersH=18+26+8+needPL+20 -- header+search+gap+list+pad
 playersSection.Size=UDim2.new(1,0,0,playersH) local total=gridH+10+playersH+6 stack.Size=UDim2.new(1,-4,0,total) outerScroll.CanvasSize=UDim2.new(0,0,0,total+6) end upd() grid:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() task.wait() upd() end) playerListFrame:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() task.wait() upd() end) outerScroll:GetPropertyChangedSignal("AbsoluteWindowSize"):Connect(upd) for i=1,20 do task.wait(0.1) upd() end end)

if playerSearchBox then
    playerSearchBox:GetPropertyChangedSignal("Text"):Connect(function()
        playerSearchText = playerSearchBox.Text
        refreshPlayerList()
        -- canvas пересчитается через ChildAdded
    end)
end
if playerRefreshBtn then
    playerRefreshBtn.MouseButton1Click:Connect(function()
        tween(playerRefreshBtn, {Rotation = 360}, 0.35, Enum.EasingStyle.Quart)
        task.delay(0.35, function() playerRefreshBtn.Rotation = 0 end)
        refreshPlayerList()
    end)
    playerRefreshBtn.MouseEnter:Connect(function() tween(playerRefreshBtn, {BackgroundColor3 = Color3.fromRGB(45,45,55)}, 0.12) end)
    playerRefreshBtn.MouseLeave:Connect(function() tween(playerRefreshBtn, {BackgroundColor3 = Color3.fromRGB(32,32,38)}, 0.12) end)
end
-- обновление списка игроков: только при входе/выходе и по кнопке/поиску (убрал while true каждые 2с — крашил)
task.spawn(function()
    task.wait(0.6)
    pcall(refreshPlayerList)
    Players.PlayerAdded:Connect(function() task.wait(0.4) pcall(refreshPlayerList) end)
    Players.PlayerRemoving:Connect(function() task.wait(0.1) pcall(refreshPlayerList) end)
end)

-- coins scroll canvas auto (UIListLayout)
task.spawn(function()
    task.wait(0.2)
    local function upd()
        local sz = coinsLayout.AbsoluteContentSize.Y + 8
        coinsScroll.CanvasSize = UDim2.new(0,0,0, sz)
    end
    upd()
    coinsLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(upd)
end)

-- Dragging
do
    local dragging, dragStart, startPos
    topBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = main.Position
            input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then dragging = false end end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

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

closeBtn.MouseButton1Click:Connect(function() setOpen(false) end)

minimizeBtn.MouseButton1Click:Connect(function()
    isMinimized = not isMinimized
    if isMinimized then
        tween(main, {Size = UDim2.fromOffset(originalSize.X.Offset, 52)}, 0.28, Enum.EasingStyle.Quart)
        teleportPage.Visible = false
        coinsPage.Visible = false
        rightArea.Visible = false
        divider.Visible = false
        minimizeBtn.Text = "□"
    else
        tween(main, {Size = originalSize}, 0.28, Enum.EasingStyle.Back)
        task.wait(0.12)
        rightArea.Visible = true
        divider.Visible = true
        -- вернуть текущую страницу
        teleportPage.Visible = (selectedCategory == "teleporting")
        coinsPage.Visible = (selectedCategory == "coins")
        minimizeBtn.Text = "—"
    end
end)

UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.RightBracket then
        setOpen(not isOpen)
    end
end)

setOpen(true, true)
print("[TeleportHub v1.0.2] Loaded — ] to toggle • 12 teleports • Coins Collecting ready")
notify("Teleport Hub v1.0.2", "] — меню • 2 категории • Coins: SCAN → START")
-- auto scan отключён чтобы не крашило на старте — только по кнопке SCAN
-- task.spawn(function() task.wait(0.8) doCoinsScan(false) end)
