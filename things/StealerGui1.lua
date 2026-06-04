-- ╔══════════════════════════════════════════════════════════════╗
-- ║           PET MONITOR GUI  —  LocalScript (Client)          ║
-- ║   Мониторинг спавна петов, фильтры, телепорт, "Steal"       ║
-- ╚══════════════════════════════════════════════════════════════╝

local Players        = game:GetService("Players")
local RunService     = game:GetService("RunService")
local TweenService   = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player         = Players.LocalPlayer
local character      = player.Character or player.CharacterAdded:Wait()
local playerGui      = player.PlayerGui

-- ─────────────────────────────────────────────
--  Константы
-- ─────────────────────────────────────────────
local SPAWNERS_PATH  = workspace:WaitForChild("ItemSpawners")
local SAFE_ZONE_NAME = "SafeZone"

-- Порядок редкостей (индекс = приоритет, 1 — лучший)
local RARITY_ORDER = { "OG", "Legendary", "Mythic", "Epic", "Special", "Common" }
local RARITY_COLOR = {
    OG        = Color3.fromRGB(255, 215,   0),  -- золото
    Legendary = Color3.fromRGB(255, 140,   0),  -- оранжевый
    Mythic    = Color3.fromRGB(200,  50, 255),  -- фиолетовый
    Epic      = Color3.fromRGB( 80, 130, 255),  -- синий
    Special   = Color3.fromRGB( 50, 220, 180),  -- бирюзовый
    Common    = Color3.fromRGB(190, 190, 190),  -- серый
}

-- Порядок мутаций (индекс = приоритет, 1 — лучший)
local MUTATION_ORDER = { "Divine", "Neon", "Blood", "Rainbow", "Ruby", "Diamond", "Golden", "Normal" }
local MUTATION_COLOR = {
    Divine   = Color3.fromRGB(255, 255, 100),
    Neon     = Color3.fromRGB(  0, 255, 200),
    Blood    = Color3.fromRGB(200,   0,   0),
    Rainbow  = Color3.fromRGB(255,  80, 180),
    Ruby     = Color3.fromRGB(220,  30,  60),
    Diamond  = Color3.fromRGB(100, 220, 255),
    Golden   = Color3.fromRGB(255, 200,  50),
    Normal   = Color3.fromRGB(210, 210, 210),
}

-- ─────────────────────────────────────────────
--  Состояние фильтров (хранится в таблице)
-- ─────────────────────────────────────────────
local filters = {
    rarities  = { OG=true, Legendary=true, Mythic=true, Epic=true, Special=true, Common=true },
    mutations = { Divine=true, Neon=true, Blood=true, Rainbow=true,
                  Ruby=true, Diamond=true, Golden=true, Normal=true },
}

-- ─────────────────────────────────────────────
--  Таблица активных петов: [instance] = данные
-- ─────────────────────────────────────────────
local activePets   = {}   -- { name, rarity, mutation, earnings, imageId, head, prompt }
local petFrames    = {}   -- [instance] = Frame в списке
local needsRebuild = false  -- флаг пересборки списка

-- ─────────────────────────────────────────────
--  Вспомогательные функции
-- ─────────────────────────────────────────────

--- Возвращает ранг редкости (меньше = лучше)
local function rarityRank(r)
    for i, v in ipairs(RARITY_ORDER) do
        if v == r then return i end
    end
    return #RARITY_ORDER + 1
end

--- Возвращает ранг мутации (меньше = лучше)
local function mutationRank(m)
    for i, v in ipairs(MUTATION_ORDER) do
        if v == m then return i end
    end
    return #MUTATION_ORDER + 1
end

--- Читает TextLabel из InfoGUI пета
local function readLabel(pet, labelName)
    local ok, val = pcall(function()
        return pet:FindFirstChild("InfoGUI")
            :FindFirstChild("TextLabels")
            :FindFirstChild(labelName).Text
    end)
    return ok and val or ""
end

--- Пытается получить imageId картинки пета
local function readImageId(pet)
    local ok, val = pcall(function()
        return pet:FindFirstChild("Open This")
            :FindFirstChild("Paste the link to the image in here").Value
    end)
    return ok and val or ""
end

--- Парсит строку таймера вида "1:23" в секунды
local function parseTimer(timerText)
    local m, s = timerText:match("(%d+):(%d+)")
    if m and s then return tonumber(m)*60 + tonumber(s) end
    local sec = timerText:match("(%d+)")
    return sec and tonumber(sec) or 0
end

-- ─────────────────────────────────────────────
--  Построение GUI
-- ─────────────────────────────────────────────

local screenGui = Instance.new("ScreenGui")
screenGui.Name            = "PetMonitorGUI"
screenGui.ResetOnSpawn    = false
screenGui.ZIndexBehavior  = Enum.ZIndexBehavior.Sibling
screenGui.IgnoreGuiInset  = true
screenGui.Parent          = playerGui

-- ── Главное окно ──────────────────────────────
local mainFrame = Instance.new("Frame")
mainFrame.Name              = "MainFrame"
mainFrame.Size              = UDim2.new(0, 480, 0, 620)
mainFrame.Position          = UDim2.new(0.5, -240, 0.5, -310)
mainFrame.BackgroundColor3  = Color3.fromRGB(12, 12, 20)
mainFrame.BorderSizePixel   = 0
mainFrame.ClipsDescendants  = true
mainFrame.Parent            = screenGui

-- Скругление
local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 14)
mainCorner.Parent = mainFrame

-- Обводка
local mainStroke = Instance.new("UIStroke")
mainStroke.Color     = Color3.fromRGB(80, 60, 140)
mainStroke.Thickness = 1.5
mainStroke.Parent    = mainFrame

-- Фоновый градиент
local mainGradient = Instance.new("UIGradient")
mainGradient.Color    = ColorSequence.new({
    ColorSequenceKeypoint.new(0,   Color3.fromRGB(18, 14, 32)),
    ColorSequenceKeypoint.new(1,   Color3.fromRGB( 8, 12, 22)),
})
mainGradient.Rotation = 135
mainGradient.Parent   = mainFrame

-- Декоративная полоса сверху
local topBar = Instance.new("Frame")
topBar.Name             = "TopBar"
topBar.Size             = UDim2.new(1, 0, 0, 44)
topBar.BackgroundColor3 = Color3.fromRGB(25, 18, 50)
topBar.BorderSizePixel  = 0
topBar.ZIndex           = 2
topBar.Parent           = mainFrame

local topBarGrad = Instance.new("UIGradient")
topBarGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(100, 50, 200)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB( 40, 20,  90)),
})
topBarGrad.Rotation = 90
topBarGrad.Parent   = topBar

local topCorner = Instance.new("UICorner")
topCorner.CornerRadius = UDim.new(0, 14)
topCorner.Parent = topBar

-- Лого / заголовок
local titleLabel = Instance.new("TextLabel")
titleLabel.Name              = "Title"
titleLabel.Size              = UDim2.new(1, -100, 1, 0)
titleLabel.Position          = UDim2.new(0, 14, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text              = "🐾  PET MONITOR"
titleLabel.TextColor3        = Color3.fromRGB(255, 255, 255)
titleLabel.TextSize          = 16
titleLabel.Font              = Enum.Font.GothamBold
titleLabel.TextXAlignment    = Enum.TextXAlignment.Left
titleLabel.ZIndex            = 3
titleLabel.Parent            = topBar

-- Кнопка свернуть
local minimizeBtn = Instance.new("TextButton")
minimizeBtn.Name              = "MinimizeBtn"
minimizeBtn.Size              = UDim2.new(0, 28, 0, 28)
minimizeBtn.Position          = UDim2.new(1, -66, 0.5, -14)
minimizeBtn.BackgroundColor3  = Color3.fromRGB(60, 40, 100)
minimizeBtn.Text              = "–"
minimizeBtn.TextColor3        = Color3.fromRGB(200, 180, 255)
minimizeBtn.TextSize          = 18
minimizeBtn.Font              = Enum.Font.GothamBold
minimizeBtn.ZIndex            = 4
minimizeBtn.Parent            = topBar
Instance.new("UICorner", minimizeBtn).CornerRadius = UDim.new(0, 6)

-- Кнопка закрыть
local closeBtn = Instance.new("TextButton")
closeBtn.Name              = "CloseBtn"
closeBtn.Size              = UDim2.new(0, 28, 0, 28)
closeBtn.Position          = UDim2.new(1, -32, 0.5, -14)
closeBtn.BackgroundColor3  = Color3.fromRGB(160, 30, 50)
closeBtn.Text              = "✕"
closeBtn.TextColor3        = Color3.fromRGB(255, 200, 210)
closeBtn.TextSize          = 14
closeBtn.Font              = Enum.Font.GothamBold
closeBtn.ZIndex            = 4
closeBtn.Parent            = topBar
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)

-- ── Панель фильтров ────────────────────────────
local filterPanel = Instance.new("Frame")
filterPanel.Name             = "FilterPanel"
filterPanel.Size             = UDim2.new(1, -16, 0, 130)
filterPanel.Position         = UDim2.new(0, 8, 0, 50)
filterPanel.BackgroundColor3 = Color3.fromRGB(20, 15, 38)
filterPanel.BorderSizePixel  = 0
filterPanel.Parent           = mainFrame
Instance.new("UICorner", filterPanel).CornerRadius = UDim.new(0, 10)
local fpStroke = Instance.new("UIStroke")
fpStroke.Color     = Color3.fromRGB(60, 40, 100)
fpStroke.Thickness = 1
fpStroke.Parent    = filterPanel

-- Заголовок фильтров
local filterTitle = Instance.new("TextLabel")
filterTitle.Size              = UDim2.new(1, -10, 0, 20)
filterTitle.Position          = UDim2.new(0, 10, 0, 5)
filterTitle.BackgroundTransparency = 1
filterTitle.Text              = "FILTERS"
filterTitle.TextColor3        = Color3.fromRGB(150, 120, 220)
filterTitle.TextSize          = 11
filterTitle.Font              = Enum.Font.GothamBold
filterTitle.TextXAlignment    = Enum.TextXAlignment.Left
filterTitle.Parent            = filterPanel

-- Разделитель
local sep1 = Instance.new("Frame")
sep1.Size             = UDim2.new(1, -20, 0, 1)
sep1.Position         = UDim2.new(0, 10, 0, 26)
sep1.BackgroundColor3 = Color3.fromRGB(60, 40, 100)
sep1.BorderSizePixel  = 0
sep1.Parent           = filterPanel

-- ── Функция создания CheckBox ──────────────────
local checkboxRefs = {}  -- { label:string, type:"rarity"|"mutation", btn:TextButton }

local function makeCheckbox(parent, label, posX, posY, filterType, color)
    local container = Instance.new("Frame")
    container.Size             = UDim2.new(0, 82, 0, 22)
    container.Position         = UDim2.new(0, posX, 0, posY)
    container.BackgroundTransparency = 1
    container.Parent           = parent

    local box = Instance.new("TextButton")
    box.Size             = UDim2.new(0, 18, 0, 18)
    box.Position         = UDim2.new(0, 0, 0.5, -9)
    box.BackgroundColor3 = Color3.fromRGB(30, 22, 55)
    box.Text             = "✓"
    box.TextColor3       = color or Color3.fromRGB(180, 140, 255)
    box.TextSize         = 12
    box.Font             = Enum.Font.GothamBold
    box.Parent           = container
    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 4)
    local bStroke = Instance.new("UIStroke")
    bStroke.Color     = Color3.fromRGB(90, 60, 160)
    bStroke.Thickness = 1
    bStroke.Parent    = box

    local lbl = Instance.new("TextLabel")
    lbl.Size             = UDim2.new(0, 60, 1, 0)
    lbl.Position         = UDim2.new(0, 22, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text             = label
    lbl.TextColor3       = color or Color3.fromRGB(220, 200, 255)
    lbl.TextSize         = 11
    lbl.Font             = Enum.Font.Gotham
    lbl.TextXAlignment   = Enum.TextXAlignment.Left
    lbl.Parent           = container

    -- Логика включения/выключения
    local isOn = true
    local function updateVisual()
        if isOn then
            box.Text             = "✓"
            box.BackgroundColor3 = Color3.fromRGB(80, 50, 160)
        else
            box.Text             = ""
            box.BackgroundColor3 = Color3.fromRGB(30, 22, 55)
        end
    end

    box.MouseButton1Click:Connect(function()
        isOn = not isOn
        updateVisual()
        if filterType == "rarity" then
            filters.rarities[label] = isOn
        else
            filters.mutations[label] = isOn
        end
        needsRebuild = true
    end)

    table.insert(checkboxRefs, { label=label, btn=box, state=function() return isOn end })
    return container
end

-- Строка 1: редкости
local rarityRow = { "Common", "Epic", "Mythic", "Legendary", "OG", "Special" }
for i, rarity in ipairs(rarityRow) do
    local col = RARITY_COLOR[rarity] or Color3.fromRGB(200,200,200)
    makeCheckbox(filterPanel, rarity, 8 + (i-1)*78, 32, "rarity", col)
end

-- Строка 2: мутации (первые 4)
local mutRow1 = { "Normal", "Golden", "Diamond", "Ruby" }
for i, mut in ipairs(mutRow1) do
    local col = MUTATION_COLOR[mut] or Color3.fromRGB(200,200,200)
    makeCheckbox(filterPanel, mut, 8 + (i-1)*115, 60, "mutation", col)
end

-- Строка 3: мутации (вторые 4)
local mutRow2 = { "Rainbow", "Blood", "Neon", "Divine" }
for i, mut in ipairs(mutRow2) do
    local col = MUTATION_COLOR[mut] or Color3.fromRGB(200,200,200)
    makeCheckbox(filterPanel, mut, 8 + (i-1)*115, 88, "mutation", col)
end

-- ── Счётчик петов ──────────────────────────────
local countLabel = Instance.new("TextLabel")
countLabel.Name              = "CountLabel"
countLabel.Size              = UDim2.new(1, -16, 0, 20)
countLabel.Position          = UDim2.new(0, 8, 0, 186)
countLabel.BackgroundTransparency = 1
countLabel.Text              = "Pets shown: 0"
countLabel.TextColor3        = Color3.fromRGB(140, 110, 200)
countLabel.TextSize          = 12
countLabel.Font              = Enum.Font.Gotham
countLabel.TextXAlignment    = Enum.TextXAlignment.Left
countLabel.Parent            = mainFrame

-- ── Скроллируемый список ───────────────────────
local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Name              = "PetList"
scrollFrame.Size              = UDim2.new(1, -16, 1, -218)
scrollFrame.Position          = UDim2.new(0, 8, 0, 210)
scrollFrame.BackgroundColor3  = Color3.fromRGB(15, 11, 28)
scrollFrame.BorderSizePixel   = 0
scrollFrame.ScrollBarThickness = 4
scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(100, 60, 200)
scrollFrame.CanvasSize        = UDim2.new(0, 0, 0, 0)
scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
scrollFrame.ClipsDescendants  = true
scrollFrame.Parent            = mainFrame
Instance.new("UICorner", scrollFrame).CornerRadius = UDim.new(0, 10)
local sfStroke = Instance.new("UIStroke")
sfStroke.Color     = Color3.fromRGB(40, 30, 70)
sfStroke.Thickness = 1
sfStroke.Parent    = scrollFrame

local listLayout = Instance.new("UIListLayout")
listLayout.Padding         = UDim.new(0, 6)
listLayout.SortOrder       = Enum.SortOrder.LayoutOrder
listLayout.Parent          = scrollFrame

local listPadding = Instance.new("UIPadding")
listPadding.PaddingTop    = UDim.new(0, 6)
listPadding.PaddingBottom = UDim.new(0, 6)
listPadding.PaddingLeft   = UDim.new(0, 6)
listPadding.PaddingRight  = UDim.new(0, 6)
listPadding.Parent        = scrollFrame

-- ─────────────────────────────────────────────
--  Создание карточки пета в списке
-- ─────────────────────────────────────────────
local function createPetCard(petInstance, data)
    local card = Instance.new("Frame")
    card.Name             = "PetCard_" .. petInstance.Name
    card.Size             = UDim2.new(1, 0, 0, 76)
    card.BackgroundColor3 = Color3.fromRGB(22, 16, 42)
    card.BorderSizePixel  = 0
    card.Parent           = scrollFrame
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 10)
    local cardStroke = Instance.new("UIStroke")
    cardStroke.Color     = Color3.fromRGB(55, 35, 100)
    cardStroke.Thickness = 1
    cardStroke.Parent    = card

    -- Тонкая цветная полоска слева по редкости
    local rarityBar = Instance.new("Frame")
    rarityBar.Size             = UDim2.new(0, 4, 1, -16)
    rarityBar.Position         = UDim2.new(0, 6, 0, 8)
    rarityBar.BackgroundColor3 = RARITY_COLOR[data.rarity] or Color3.fromRGB(150,150,150)
    rarityBar.BorderSizePixel  = 0
    rarityBar.Parent           = card
    Instance.new("UICorner", rarityBar).CornerRadius = UDim.new(0, 4)

    -- Иконка/картинка пета
    local petImage = Instance.new("ImageLabel")
    petImage.Size             = UDim2.new(0, 56, 0, 56)
    petImage.Position         = UDim2.new(0, 16, 0, 10)
    petImage.BackgroundColor3 = Color3.fromRGB(30, 20, 55)
    petImage.Image            = (data.imageId ~= "") and ("rbxassetid://" .. data.imageId:match("%d+")) or "rbxasset://textures/ui/GuiImagePlaceholder.png"
    petImage.ScaleType        = Enum.ScaleType.Fit
    petImage.Parent           = card
    Instance.new("UICorner", petImage).CornerRadius = UDim.new(0, 8)

    -- Название пета
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name             = "NameLabel"
    nameLabel.Size             = UDim2.new(0, 180, 0, 18)
    nameLabel.Position         = UDim2.new(0, 80, 0, 8)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text             = data.name
    nameLabel.TextColor3       = Color3.fromRGB(255, 255, 255)
    nameLabel.TextSize         = 13
    nameLabel.Font             = Enum.Font.GothamBold
    nameLabel.TextXAlignment   = Enum.TextXAlignment.Left
    nameLabel.TextTruncate     = Enum.TextTruncate.AtEnd
    nameLabel.Parent           = card

    -- Редкость
    local rarityLabel = Instance.new("TextLabel")
    rarityLabel.Size           = UDim2.new(0, 100, 0, 15)
    rarityLabel.Position       = UDim2.new(0, 80, 0, 28)
    rarityLabel.BackgroundTransparency = 1
    rarityLabel.Text           = "◆ " .. (data.rarity ~= "" and data.rarity or "Unknown")
    rarityLabel.TextColor3     = RARITY_COLOR[data.rarity] or Color3.fromRGB(200,200,200)
    rarityLabel.TextSize       = 11
    rarityLabel.Font           = Enum.Font.GothamBold
    rarityLabel.TextXAlignment = Enum.TextXAlignment.Left
    rarityLabel.Parent         = card

    -- Мутация
    local mutLabel = Instance.new("TextLabel")
    mutLabel.Size              = UDim2.new(0, 110, 0, 15)
    mutLabel.Position          = UDim2.new(0, 80, 0, 44)
    mutLabel.BackgroundTransparency = 1
    mutLabel.Text              = "✦ " .. (data.mutation ~= "" and data.mutation or "Normal")
    mutLabel.TextColor3        = MUTATION_COLOR[data.mutation] or Color3.fromRGB(210,210,210)
    mutLabel.TextSize          = 11
    mutLabel.Font              = Enum.Font.Gotham
    mutLabel.TextXAlignment    = Enum.TextXAlignment.Left
    mutLabel.Parent            = card

    -- Earnings
    local earnLabel = Instance.new("TextLabel")
    earnLabel.Name             = "EarnLabel"
    earnLabel.Size             = UDim2.new(0, 100, 0, 15)
    earnLabel.Position         = UDim2.new(0, 80, 0, 60)
    earnLabel.BackgroundTransparency = 1
    earnLabel.Text             = "💰 " .. data.earnings
    earnLabel.TextColor3       = Color3.fromRGB(255, 215, 80)
    earnLabel.TextSize         = 11
    earnLabel.Font             = Enum.Font.Gotham
    earnLabel.TextXAlignment   = Enum.TextXAlignment.Left
    earnLabel.Parent           = card

    -- Таймер
    local timerLabel = Instance.new("TextLabel")
    timerLabel.Name            = "TimerLabel"
    timerLabel.Size            = UDim2.new(0, 80, 0, 18)
    timerLabel.Position        = UDim2.new(1, -164, 0, 8)
    timerLabel.BackgroundTransparency = 1
    timerLabel.Text            = "⏱ " .. readLabel(petInstance, "Timer")
    timerLabel.TextColor3      = Color3.fromRGB(180, 220, 255)
    timerLabel.TextSize        = 12
    timerLabel.Font            = Enum.Font.GothamBold
    timerLabel.TextXAlignment  = Enum.TextXAlignment.Right
    timerLabel.Parent          = card

    -- Кнопка "Steal"
    local stealBtn = Instance.new("TextButton")
    stealBtn.Name              = "StealBtn"
    stealBtn.Size              = UDim2.new(0, 68, 0, 34)
    stealBtn.Position          = UDim2.new(1, -82, 0.5, -17)
    stealBtn.BackgroundColor3  = Color3.fromRGB(200, 40, 80)
    stealBtn.Text              = "STEAL"
    stealBtn.TextColor3        = Color3.fromRGB(255, 255, 255)
    stealBtn.TextSize          = 13
    stealBtn.Font              = Enum.Font.GothamBold
    stealBtn.Parent            = card
    Instance.new("UICorner", stealBtn).CornerRadius = UDim.new(0, 8)

    -- Gradient на кнопке
    local stealGrad = Instance.new("UIGradient")
    stealGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 60, 100)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(160, 20, 50)),
    })
    stealGrad.Rotation = 90
    stealGrad.Parent   = stealBtn

    -- Hover-эффект
    stealBtn.MouseEnter:Connect(function()
        TweenService:Create(stealBtn, TweenInfo.new(0.15), {
            BackgroundColor3 = Color3.fromRGB(255, 80, 120)
        }):Play()
    end)
    stealBtn.MouseLeave:Connect(function()
        TweenService:Create(stealBtn, TweenInfo.new(0.15), {
            BackgroundColor3 = Color3.fromRGB(200, 40, 80)
        }):Play()
    end)

    -- ── Логика кнопки Steal ───────────────────
    stealBtn.MouseButton1Click:Connect(function()
        -- Получаем свежий character (мог переспавниться)
        character = player.Character
        if not character then return end

        local headPart = data.head
        if not headPart or not headPart.Parent then return end

        -- 1. Телепорт к голове пета
        local hrp = character:FindFirstChild("HumanoidRootPart")
        if hrp then
            hrp.CFrame = headPart.CFrame * CFrame.new(0, 0, -2.5)
        end

        -- 2. Небольшая задержка
        task.wait(0.35)

        -- 3. Активируем ProximityPrompt
        local prompt = data.prompt
        if prompt and prompt:IsA("ProximityPrompt") then
            -- Используем FireProximityPrompt (только на клиенте)
            local ok2 = pcall(function()
                local module = game:GetService("ProximityPromptService")
                -- Стандартный способ триггера промпта с клиента:
                fireclickdetector(prompt)  -- fallback
            end)
            if not ok2 then
                -- Прямой вызов через RemoteEvent / TriggerProximityPrompt
                pcall(function()
                    prompt:InputHoldBegin()
                    task.wait(prompt.HoldDuration + 0.1)
                    prompt:InputHoldEnd()
                end)
            end
        end

        -- 4. Телепорт в SafeZone
        task.wait(0.5)
        character = player.Character
        if not character then return end
        hrp = character:FindFirstChild("HumanoidRootPart")
        local safeZone = workspace:FindFirstChild(SAFE_ZONE_NAME)
        if hrp and safeZone then
            if safeZone:IsA("BasePart") then
                hrp.CFrame = safeZone.CFrame + Vector3.new(0, 4, 0)
            elseif safeZone:FindFirstChildWhichIsA("BasePart") then
                local part = safeZone:FindFirstChildWhichIsA("BasePart")
                hrp.CFrame = part.CFrame + Vector3.new(0, 4, 0)
            end
        end
    end)

    petFrames[petInstance] = card
    return card
end

-- ─────────────────────────────────────────────
--  Пересборка видимого списка с учётом фильтров
-- ─────────────────────────────────────────────
local function rebuildList()
    -- 1. Собираем отфильтрованных
    local visible = {}
    for inst, data in pairs(activePets) do
        local rarityOk   = filters.rarities[data.rarity]   == true
        local mutationOk = filters.mutations[data.mutation] == true or
                           filters.mutations["Normal"]      == true and (data.mutation == "" or data.mutation == "Normal")
        if rarityOk and mutationOk then
            table.insert(visible, { inst=inst, data=data })
        end
    end

    -- 2. Сортировка: редкость → мутация → таймер
    table.sort(visible, function(a, b)
        local rA = rarityRank(a.data.rarity)
        local rB = rarityRank(b.data.rarity)
        if rA ~= rB then return rA < rB end
        local mA = mutationRank(a.data.mutation)
        local mB = mutationRank(b.data.mutation)
        if mA ~= mB then return mA < mB end
        return (a.data.timerSecs or 9999) < (b.data.timerSecs or 9999)
    end)

    -- 3. Скрываем все карточки
    for _, frame in pairs(petFrames) do
        frame.Visible = false
    end

    -- 4. Показываем и расставляем LayoutOrder
    for order, entry in ipairs(visible) do
        local frame = petFrames[entry.inst]
        if not frame then
            frame = createPetCard(entry.inst, entry.data)
        end
        frame.LayoutOrder = order
        frame.Visible     = true
    end

    countLabel.Text = string.format("Pets shown: %d / %d", #visible, (function()
        local n = 0; for _ in pairs(activePets) do n = n + 1 end; return n
    end)())
end

-- ─────────────────────────────────────────────
--  Чтение данных из пета и добавление в таблицу
-- ─────────────────────────────────────────────
local function registerPet(petInstance)
    if activePets[petInstance] then return end  -- уже есть

    -- Ждём InfoGUI если не появился
    local infoGui = petInstance:FindFirstChild("InfoGUI")
    if not infoGui then
        infoGui = petInstance:WaitForChild("InfoGUI", 5)
        if not infoGui then return end
    end

    local labels = infoGui:FindFirstChild("TextLabels")
    if not labels then
        labels = infoGui:WaitForChild("TextLabels", 5)
        if not labels then return end
    end

    local head   = petInstance:FindFirstChild("Head")
    local prompt = head and head:FindFirstChildWhichIsA("ProximityPrompt")

    local timerText = readLabel(petInstance, "Timer")
    local mutation  = readLabel(petInstance, "Mutation")
    if mutation == "" then mutation = "Normal" end

    activePets[petInstance] = {
        name      = readLabel(petInstance, "Name"),
        rarity    = readLabel(petInstance, "Rarity"),
        mutation  = mutation,
        earnings  = readLabel(petInstance, "Earnings"),
        imageId   = readImageId(petInstance),
        head      = head,
        prompt    = prompt,
        timerSecs = parseTimer(timerText),
        timerLabel= nil,  -- будет заполнено после создания карточки
    }

    needsRebuild = true
end

--- Удаляет пета из таблицы и GUI
local function unregisterPet(petInstance)
    activePets[petInstance] = nil
    local frame = petFrames[petInstance]
    if frame then
        frame:Destroy()
        petFrames[petInstance] = nil
    end
    needsRebuild = true
end

-- ─────────────────────────────────────────────
--  Подписка на папку спавнера
-- ─────────────────────────────────────────────
local function watchFolder(folder)
    -- Существующие петы
    for _, child in ipairs(folder:GetChildren()) do
        task.spawn(registerPet, child)
    end
    -- Новые петы
    folder.ChildAdded:Connect(function(child)
        task.spawn(registerPet, child)
    end)
    -- Удалённые петы
    folder.ChildRemoved:Connect(function(child)
        unregisterPet(child)
    end)
end

-- Ждём ItemSpawners и подписываемся на все папки
task.spawn(function()
    for _, folder in ipairs(SPAWNERS_PATH:GetChildren()) do
        if folder:IsA("Folder") or folder:IsA("Model") then
            watchFolder(folder)
        end
    end
    -- На случай новых папок
    SPAWNERS_PATH.ChildAdded:Connect(function(folder)
        if folder:IsA("Folder") or folder:IsA("Model") then
            watchFolder(folder)
        end
    end)
end)

-- ─────────────────────────────────────────────
--  RunService: обновление таймеров + rebuild
-- ─────────────────────────────────────────────
local updateAccum = 0  -- накапливаем время для 1-секундного тика таймеров

RunService.Heartbeat:Connect(function(dt)
    -- 1. Пересборка списка если нужно
    if needsRebuild then
        needsRebuild = false
        rebuildList()
    end

    -- 2. Обновление таймеров раз в секунду
    updateAccum = updateAccum + dt
    if updateAccum < 1 then return end
    updateAccum = 0

    for inst, data in pairs(activePets) do
        -- Обновляем timerSecs из живого TextLabel
        local freshTimer = readLabel(inst, "Timer")
        data.timerSecs = parseTimer(freshTimer)

        -- Обновляем отображение таймера в карточке
        local frame = petFrames[inst]
        if frame then
            local tl = frame:FindFirstChild("TimerLabel", true)
            if tl then
                local secs = data.timerSecs
                if secs <= 10 then
                    tl.TextColor3 = Color3.fromRGB(255, 80, 80)
                elseif secs <= 30 then
                    tl.TextColor3 = Color3.fromRGB(255, 180, 50)
                else
                    tl.TextColor3 = Color3.fromRGB(180, 220, 255)
                end
                tl.Text = string.format("⏱ %d:%02d", math.floor(secs/60), secs%60)
            end
        end
    end
end)

-- ─────────────────────────────────────────────
--  Перетаскивание окна (Draggable)
-- ─────────────────────────────────────────────
do
    local dragging = false
    local dragStart, startPos

    topBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging  = true
            dragStart = input.Position
            startPos  = mainFrame.Position
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
                      or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            mainFrame.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end

-- ─────────────────────────────────────────────
--  Кнопки закрытия и сворачивания
-- ─────────────────────────────────────────────
local isMinimized = false
local fullHeight  = mainFrame.Size.Y.Offset

closeBtn.MouseButton1Click:Connect(function()
    TweenService:Create(mainFrame, TweenInfo.new(0.2), {
        Size = UDim2.new(0, 480, 0, 0)
    }):Play()
    task.wait(0.25)
    screenGui:Destroy()
end)

minimizeBtn.MouseButton1Click:Connect(function()
    isMinimized = not isMinimized
    if isMinimized then
        TweenService:Create(mainFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quint), {
            Size = UDim2.new(0, 480, 0, 44)
        }):Play()
        minimizeBtn.Text = "□"
    else
        TweenService:Create(mainFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quint), {
            Size = UDim2.new(0, 480, 0, fullHeight)
        }):Play()
        minimizeBtn.Text = "–"
    end
end)

-- ─────────────────────────────────────────────
--  Анимация появления окна
-- ─────────────────────────────────────────────
mainFrame.Size = UDim2.new(0, 480, 0, 0)
TweenService:Create(mainFrame, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
    Size = UDim2.new(0, 480, 0, fullHeight)
}):Play()

print("[PetMonitor] GUI loaded successfully.")
