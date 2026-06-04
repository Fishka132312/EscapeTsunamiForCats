-- ============================================================
--  PetMonitorGUI  |  LocalScript
--  Размещение: StarterPlayerScripts  или  StarterCharacterScripts
-- ============================================================

local Players         = game:GetService("Players")
local RunService      = game:GetService("RunService")
local TweenService    = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local localPlayer  = Players.LocalPlayer
local playerGui    = localPlayer:WaitForChild("PlayerGui")
local character    = localPlayer.Character or localPlayer.CharacterAdded:Wait()
local humanoidRoot = character:WaitForChild("HumanoidRootPart")

-- ============================================================
--  НАСТРОЙКИ  (меняй здесь под свою игру)
-- ============================================================
local CONFIG = {
    -- Путь к корневой папке со спавнерами
    SPAWNERS_PATH = workspace:WaitForChild("ItemSpawners"),

    -- Названия моделей петов внутри папок редкости
    PET_MODEL_NAMES = { "SpawnedItem", "VisualItem" },

    -- Путь к ProximityPrompt внутри модели: model.Head.ProximityPrompt
    PROMPT_PART   = "Head",
    PROMPT_NAME   = "ProximityPrompt",

    -- Путь к GUI с данными внутри модели
    INFO_GUI_NAME = "InfoGUI",

    -- Имена TextLabel'ов внутри InfoGUI
    LABELS = {
        earnings  = "Earnings",
        mutation  = "Mutation",
        name      = "Name",
        rarity    = "Rarity",
        timer     = "Timer",
    },

    -- Путь к StringValue с картинкой:
    -- model["Open This"]["Paste the link to the image in here"]
    IMAGE_FOLDER  = "Open This",
    IMAGE_VALUE   = "Paste the link to the image in here",

    -- Безопасная зона для возврата после стила
    -- Если SafeZone — BasePart, ставь true; если нет — false (ТП отключается)
    USE_SAFE_ZONE = true,
    SAFE_ZONE_PATH = workspace:FindFirstChild("SafeZone"),

    -- Задержки телепортации (секунды)
    DELAY_BEFORE_STEAL  = 0.2,   -- пауза перед нажатием ProximityPrompt
    DELAY_AT_SAFE_ZONE  = 2.0,   -- ожидание в безопасной зоне
    DELAY_BEFORE_RETURN = 0.5,   -- пауза перед возвратом на старую позицию

    -- Интервал обновления списка (секунды)
    REFRESH_INTERVAL = 1.5,

    -- Все возможные мутации (порядок важен для UI)
    ALL_MUTATIONS = {
        "Normal", "Golden", "Diamond", "Ruby",
        "Rainbow", "Blood", "Neon", "Divine"
    },

    -- Цвет акцента для каждой мутации (hex → Color3)
    MUTATION_COLORS = {
        Normal  = Color3.fromHex("aaaaaa"),
        Golden  = Color3.fromHex("ffd700"),
        Diamond = Color3.fromHex("b9f2ff"),
        Ruby    = Color3.fromHex("ff4466"),
        Rainbow = Color3.fromHex("ff80ff"),
        Blood   = Color3.fromHex("cc0000"),
        Neon    = Color3.fromHex("00ff99"),
        Divine  = Color3.fromHex("ffe066"),
    },
}

-- ============================================================
--  СОСТОЯНИЕ
-- ============================================================
local state = {
    pets            = {},          -- { rarity, name, mutation, earnings, timer, prompt, model }
    activeRarities  = {},          -- set активных редкостей
    activeMutations = {},          -- set активных мутацей
    knownRarities   = {},          -- все найденные редкости
    stealBusy       = false,       -- заблокировать параллельный steal
    guiVisible      = true,
}

-- Активировать все мутации по умолчанию
for _, m in ipairs(CONFIG.ALL_MUTATIONS) do
    state.activeMutations[m] = true
end

-- ============================================================
--  ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
-- ============================================================

-- Безопасно читаем текст TextLabel
local function labelText(infoGui, labelName)
    if not infoGui then return "" end
    local lbl = infoGui:FindFirstChild(labelName)
    return lbl and lbl.Text or ""
end

-- Возвращаем ID картинки из StringValue
local function getPetImageId(model)
    local folder = model:FindFirstChild(CONFIG.IMAGE_FOLDER)
    if not folder then return "" end
    local sv = folder:FindFirstChild(CONFIG.IMAGE_VALUE)
    return sv and sv.Value or ""
end

-- Сканируем workspace.ItemSpawners и собираем всех петов
local function scanPets()
    local found = {}
    local raritiesFound = {}

    for _, rarityFolder in ipairs(CONFIG.SPAWNERS_PATH:GetChildren()) do
        if rarityFolder:IsA("Folder") then
            local rarityName = rarityFolder.Name
            raritiesFound[rarityName] = true

            -- Проходим по ВСЕМ дочерним элементам папки редкости
            for _, child in ipairs(rarityFolder:GetChildren()) do
                -- Проверяем, является ли объект одной из нужных моделей
                local isPetModel = false
                for _, petModelName in ipairs(CONFIG.PET_MODEL_NAMES) do
                    if child.Name == petModelName then
                        isPetModel = true
                        break
                    end
                end

                if isPetModel and child:IsA("Model") then
                    local headPart = child:FindFirstChild(CONFIG.PROMPT_PART)
                    local infoGui  = child:FindFirstChild(CONFIG.INFO_GUI_NAME)

                    -- Ищем ProximityPrompt (может быть прямым дочерним или внутри парта)
                    local prompt
                    if headPart then
                        prompt = headPart:FindFirstChild(CONFIG.PROMPT_NAME)
                    end

                    if prompt and infoGui then
                        local petData = {
                            model    = child,
                            prompt   = prompt,
                            rarity   = labelText(infoGui, CONFIG.LABELS.rarity),
                            name     = labelText(infoGui, CONFIG.LABELS.name),
                            mutation = labelText(infoGui, CONFIG.LABELS.mutation),
                            earnings = labelText(infoGui, CONFIG.LABELS.earnings),
                            timer    = labelText(infoGui, CONFIG.LABELS.timer),
                            imageId  = getPetImageId(child),
                        }
                        -- Если Rarity пустой — используем имя папки
                        if petData.rarity == "" then
                            petData.rarity = rarityName
                        end
                        table.insert(found, petData)
                    end
                end
            end
        end
    end

    -- Обновляем известные редкости
    for rarity in pairs(raritiesFound) do
        if not state.knownRarities[rarity] then
            state.knownRarities[rarity] = true
            -- По умолчанию включаем новую редкость
            state.activeRarities[rarity] = true
        end
    end

    return found
end

-- ============================================================
--  ЛОГИКА STEAL
-- ============================================================
local function stealPet(petData)
    if state.stealBusy then return end
    state.stealBusy = true

    -- Обновляем ссылки на персонажа (мог ресетнуться)
    character    = localPlayer.Character or localPlayer.CharacterAdded:Wait()
    humanoidRoot = character:WaitForChild("HumanoidRootPart")

    -- 1. Сохраняем текущую позицию
    local savedCFrame = humanoidRoot.CFrame

    -- 2. ТП к голове пета
    local headPart = petData.model:FindFirstChild(CONFIG.PROMPT_PART)
    if headPart then
        humanoidRoot.CFrame = headPart.CFrame + Vector3.new(0, 3, 0)
    end

    task.wait(CONFIG.DELAY_BEFORE_STEAL)

    -- 3. Эмулируем нажатие ProximityPrompt
    --    fireproximityprompt — внутренний метод движка Roblox
    if petData.prompt and petData.prompt:IsA("ProximityPrompt") then
        local success, err = pcall(function()
            fireproximityprompt(petData.prompt) -- luacheck: ignore (встроенная функция клиента)
        end)
        if not success then
            warn("[PetMonitor] fireproximityprompt error:", err)
        end
    end

    task.wait(0.3)

    -- 4. ТП в SafeZone (если включено)
    if CONFIG.USE_SAFE_ZONE and CONFIG.SAFE_ZONE_PATH then
        local safeZone = CONFIG.SAFE_ZONE_PATH
        if safeZone:IsA("BasePart") or safeZone:IsA("Model") then
            local targetCF
            if safeZone:IsA("BasePart") then
                targetCF = safeZone.CFrame + Vector3.new(0, 5, 0)
            elseif safeZone:IsA("Model") and safeZone.PrimaryPart then
                targetCF = safeZone.PrimaryPart.CFrame + Vector3.new(0, 5, 0)
            end
            if targetCF then
                humanoidRoot.CFrame = targetCF
            end
        end
    end

    task.wait(CONFIG.DELAY_AT_SAFE_ZONE)

    -- 5. Возвращаемся на сохранённую позицию
    task.wait(CONFIG.DELAY_BEFORE_RETURN)
    humanoidRoot.CFrame = savedCFrame

    state.stealBusy = false
end

-- ============================================================
--  ПОСТРОЕНИЕ GUI
-- ============================================================

-- Утилита: создать UICorner
local function addCorner(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 8)
    c.Parent = parent
end

-- Утилита: создать UIStroke
local function addStroke(parent, color, thickness)
    local s = Instance.new("UIStroke")
    s.Color = color or Color3.fromHex("333333")
    s.Thickness = thickness or 1
    s.Parent = parent
end

-- Создаём корневой ScreenGui
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "PetMonitorGUI"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

-- ── MAIN FRAME ────────────────────────────────────────────
local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 420, 0, 560)
mainFrame.Position = UDim2.new(0.5, -210, 0.5, -280)
mainFrame.BackgroundColor3 = Color3.fromHex("0d0f14")
mainFrame.BorderSizePixel = 0
mainFrame.Parent = screenGui
addCorner(mainFrame, 12)
addStroke(mainFrame, Color3.fromHex("252a36"), 1.5)

-- Заголовочная полоса
local titleBar = Instance.new("Frame")
titleBar.Name = "TitleBar"
titleBar.Size = UDim2.new(1, 0, 0, 42)
titleBar.BackgroundColor3 = Color3.fromHex("161924")
titleBar.BorderSizePixel = 0
titleBar.Parent = mainFrame
addCorner(titleBar, 12)  -- скруглены только верхние углы визуально

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -90, 1, 0)
titleLabel.Position = UDim2.new(0, 14, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "🐾  PET MONITOR"
titleLabel.TextColor3 = Color3.fromHex("e8eaf0")
titleLabel.TextSize = 15
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = titleBar

-- Кнопка свернуть/развернуть
local toggleBtn = Instance.new("TextButton")
toggleBtn.Size = UDim2.new(0, 30, 0, 22)
toggleBtn.Position = UDim2.new(1, -80, 0.5, -11)
toggleBtn.BackgroundColor3 = Color3.fromHex("252a36")
toggleBtn.TextColor3 = Color3.fromHex("aaaaaa")
toggleBtn.Text = "—"
toggleBtn.TextSize = 14
toggleBtn.Font = Enum.Font.GothamBold
toggleBtn.BorderSizePixel = 0
toggleBtn.Parent = titleBar
addCorner(toggleBtn, 5)

-- Кнопка закрыть
local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 30, 0, 22)
closeBtn.Position = UDim2.new(1, -42, 0.5, -11)
closeBtn.BackgroundColor3 = Color3.fromHex("ff4455")
closeBtn.TextColor3 = Color3.fromHex("ffffff")
closeBtn.Text = "✕"
closeBtn.TextSize = 14
closeBtn.Font = Enum.Font.GothamBold
closeBtn.BorderSizePixel = 0
closeBtn.Parent = titleBar
addCorner(closeBtn, 5)

-- Тело (скрывается при сворачивании)
local bodyFrame = Instance.new("Frame")
bodyFrame.Name = "Body"
bodyFrame.Size = UDim2.new(1, 0, 1, -42)
bodyFrame.Position = UDim2.new(0, 0, 0, 42)
bodyFrame.BackgroundTransparency = 1
bodyFrame.Parent = mainFrame

-- ── FILTERS PANEL ─────────────────────────────────────────
local filtersFrame = Instance.new("Frame")
filtersFrame.Name = "Filters"
filtersFrame.Size = UDim2.new(1, -16, 0, 110)
filtersFrame.Position = UDim2.new(0, 8, 0, 8)
filtersFrame.BackgroundColor3 = Color3.fromHex("161924")
filtersFrame.BorderSizePixel = 0
filtersFrame.Parent = bodyFrame
addCorner(filtersFrame, 8)

local filterTitle = Instance.new("TextLabel")
filterTitle.Size = UDim2.new(1, -10, 0, 22)
filterTitle.Position = UDim2.new(0, 10, 0, 4)
filterTitle.BackgroundTransparency = 1
filterTitle.Text = "ФИЛЬТРЫ"
filterTitle.TextColor3 = Color3.fromHex("667799")
filterTitle.TextSize = 11
filterTitle.Font = Enum.Font.GothamBold
filterTitle.TextXAlignment = Enum.TextXAlignment.Left
filterTitle.Parent = filtersFrame

-- Зона чекбоксов редкостей (будет заполняться динамически)
local rarityScroll = Instance.new("ScrollingFrame")
rarityScroll.Name = "RarityScroll"
rarityScroll.Size = UDim2.new(1, -10, 0, 36)
rarityScroll.Position = UDim2.new(0, 5, 0, 26)
rarityScroll.BackgroundTransparency = 1
rarityScroll.ScrollBarThickness = 3
rarityScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
rarityScroll.ScrollingDirection = Enum.ScrollingDirection.X
rarityScroll.Parent = filtersFrame

local rarityLayout = Instance.new("UIListLayout")
rarityLayout.FillDirection = Enum.FillDirection.Horizontal
rarityLayout.Padding = UDim.new(0, 5)
rarityLayout.SortOrder = Enum.SortOrder.LayoutOrder
rarityLayout.Parent = rarityScroll

-- Зона чекбоксов мутаций
local mutLabel = Instance.new("TextLabel")
mutLabel.Size = UDim2.new(1, -10, 0, 16)
mutLabel.Position = UDim2.new(0, 10, 0, 62)
mutLabel.BackgroundTransparency = 1
mutLabel.Text = "Мутации:"
mutLabel.TextColor3 = Color3.fromHex("667799")
mutLabel.TextSize = 11
mutLabel.Font = Enum.Font.GothamBold
mutLabel.TextXAlignment = Enum.TextXAlignment.Left
mutLabel.Parent = filtersFrame

local mutScroll = Instance.new("ScrollingFrame")
mutScroll.Name = "MutScroll"
mutScroll.Size = UDim2.new(1, -10, 0, 36)
mutScroll.Position = UDim2.new(0, 5, 0, 74)
mutScroll.BackgroundTransparency = 1
mutScroll.ScrollBarThickness = 3
mutScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
mutScroll.ScrollingDirection = Enum.ScrollingDirection.X
mutScroll.Parent = filtersFrame

local mutLayout = Instance.new("UIListLayout")
mutLayout.FillDirection = Enum.FillDirection.Horizontal
mutLayout.Padding = UDim.new(0, 5)
mutLayout.SortOrder = Enum.SortOrder.LayoutOrder
mutLayout.Parent = mutScroll

-- ── PET LIST ──────────────────────────────────────────────
local listLabel = Instance.new("TextLabel")
listLabel.Size = UDim2.new(1, -16, 0, 18)
listLabel.Position = UDim2.new(0, 8, 0, 124)
listLabel.BackgroundTransparency = 1
listLabel.Text = "СПИСОК ПЕТОВ"
listLabel.TextColor3 = Color3.fromHex("667799")
listLabel.TextSize = 11
listLabel.Font = Enum.Font.GothamBold
listLabel.TextXAlignment = Enum.TextXAlignment.Left
listLabel.Parent = bodyFrame

local petScroll = Instance.new("ScrollingFrame")
petScroll.Name = "PetScroll"
petScroll.Size = UDim2.new(1, -16, 1, -152)
petScroll.Position = UDim2.new(0, 8, 0, 142)
petScroll.BackgroundColor3 = Color3.fromHex("0a0c10")
petScroll.BorderSizePixel = 0
petScroll.ScrollBarThickness = 4
petScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
petScroll.Parent = bodyFrame
addCorner(petScroll, 8)

local petListLayout = Instance.new("UIListLayout")
petListLayout.Padding = UDim.new(0, 4)
petListLayout.SortOrder = Enum.SortOrder.LayoutOrder
petListLayout.Parent = petScroll

local petListPadding = Instance.new("UIPadding")
petListPadding.PaddingTop = UDim.new(0, 5)
petListPadding.PaddingBottom = UDim.new(0, 5)
petListPadding.PaddingLeft = UDim.new(0, 5)
petListPadding.PaddingRight = UDim.new(0, 5)
petListPadding.Parent = petScroll

-- ── СТАТУСНАЯ СТРОКА ──────────────────────────────────────
local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -16, 0, 18)
statusLabel.Position = UDim2.new(0, 8, 1, -22)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Ожидание сканирования..."
statusLabel.TextColor3 = Color3.fromHex("445566")
statusLabel.TextSize = 10
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.Parent = bodyFrame

-- ============================================================
--  ФУНКЦИИ ПОСТРОЕНИЯ ФИЛЬТРОВ
-- ============================================================

-- Создать чекбокс-кнопку
local function makeFilterChip(text, active, color, onClick)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, math.max(50, #text * 7 + 16), 0, 26)
    btn.AutoButtonColor = false
    btn.BorderSizePixel = 0
    btn.Text = text
    btn.TextSize = 11
    btn.Font = Enum.Font.GothamBold

    local function refresh(isActive)
        btn.BackgroundColor3 = isActive
            and (color or Color3.fromHex("3355ff"))
            or Color3.fromHex("1c2030")
        btn.TextColor3 = isActive
            and Color3.fromHex("ffffff")
            or Color3.fromHex("667799")
    end

    refresh(active)
    addCorner(btn, 13)

    btn.MouseButton1Click:Connect(function()
        onClick(btn, refresh)
    end)

    return btn
end

-- Перестроить фильтр мутаций
local function buildMutationFilters()
    for _, c in ipairs(mutScroll:GetChildren()) do
        if c:IsA("TextButton") then c:Destroy() end
    end
    local totalW = 0
    for _, mut in ipairs(CONFIG.ALL_MUTATIONS) do
        local color = CONFIG.MUTATION_COLORS[mut] or Color3.fromHex("aaaaaa")
        local chip = makeFilterChip(mut, state.activeMutations[mut], color, function(_, refresh)
            state.activeMutations[mut] = not state.activeMutations[mut]
            refresh(state.activeMutations[mut])
        end)
        chip.Parent = mutScroll
        totalW = totalW + chip.Size.X.Offset + 5
    end
    mutScroll.CanvasSize = UDim2.new(0, totalW, 0, 0)
end

-- Перестроить фильтр редкостей (вызывается при появлении новых редкостей)
local rarityChips = {}
local function rebuildRarityFilters()
    for _, c in ipairs(rarityScroll:GetChildren()) do
        if c:IsA("TextButton") then c:Destroy() end
    end
    rarityChips = {}
    local totalW = 0
    -- Собираем отсортированный список редкостей
    local rarityList = {}
    for r in pairs(state.knownRarities) do
        table.insert(rarityList, r)
    end
    table.sort(rarityList)

    for _, rarity in ipairs(rarityList) do
        local chip = makeFilterChip(rarity, state.activeRarities[rarity], nil, function(_, refresh)
            state.activeRarities[rarity] = not state.activeRarities[rarity]
            refresh(state.activeRarities[rarity])
        end)
        chip.Parent = rarityScroll
        rarityChips[rarity] = chip
        totalW = totalW + chip.Size.X.Offset + 5
    end
    rarityScroll.CanvasSize = UDim2.new(0, totalW, 0, 0)
end

-- ============================================================
--  ПОСТРОЕНИЕ КАРТОЧКИ ПЕТА
-- ============================================================

local function makePetCard(petData, index)
    local mutColor = CONFIG.MUTATION_COLORS[petData.mutation] or Color3.fromHex("aaaaaa")

    local card = Instance.new("Frame")
    card.Name = "PetCard_" .. index
    card.Size = UDim2.new(1, -2, 0, 62)
    card.BackgroundColor3 = Color3.fromHex("131720")
    card.BorderSizePixel = 0
    card.LayoutOrder = index
    addCorner(card, 7)
    addStroke(card, Color3.fromHex("1e2535"), 1)

    -- Левый цветной акцент по мутации
    local accent = Instance.new("Frame")
    accent.Size = UDim2.new(0, 3, 1, -10)
    accent.Position = UDim2.new(0, 5, 0, 5)
    accent.BackgroundColor3 = mutColor
    accent.BorderSizePixel = 0
    addCorner(accent, 3)
    accent.Parent = card

    -- Изображение пета (если есть ID)
    local imgLabel = Instance.new("ImageLabel")
    imgLabel.Size = UDim2.new(0, 44, 0, 44)
    imgLabel.Position = UDim2.new(0, 14, 0.5, -22)
    imgLabel.BackgroundColor3 = Color3.fromHex("1c2030")
    imgLabel.BorderSizePixel = 0
    imgLabel.Image = petData.imageId ~= "" and ("rbxassetid://" .. petData.imageId) or ""
    imgLabel.ImageColor3 = Color3.fromHex("aaaaaa")
    addCorner(imgLabel, 6)
    imgLabel.Parent = card

    -- Иконка-заглушка если нет картинки
    if petData.imageId == "" then
        local placeholder = Instance.new("TextLabel")
        placeholder.Size = UDim2.new(1, 0, 1, 0)
        placeholder.BackgroundTransparency = 1
        placeholder.Text = "🐾"
        placeholder.TextSize = 20
        placeholder.Font = Enum.Font.GothamBold
        placeholder.Parent = imgLabel
    end

    -- Название пета
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, -175, 0, 18)
    nameLabel.Position = UDim2.new(0, 66, 0, 8)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = petData.name ~= "" and petData.name or "Unknown Pet"
    nameLabel.TextColor3 = Color3.fromHex("dde0ea")
    nameLabel.TextSize = 13
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
    nameLabel.Parent = card

    -- Мутация
    local mutLabel2 = Instance.new("TextLabel")
    mutLabel2.Size = UDim2.new(0, 100, 0, 14)
    mutLabel2.Position = UDim2.new(0, 66, 0, 28)
    mutLabel2.BackgroundTransparency = 1
    mutLabel2.Text = petData.mutation
    mutLabel2.TextColor3 = mutColor
    mutLabel2.TextSize = 11
    mutLabel2.Font = Enum.Font.GothamBold
    mutLabel2.TextXAlignment = Enum.TextXAlignment.Left
    mutLabel2.Parent = card

    -- Редкость
    local rarLabel = Instance.new("TextLabel")
    rarLabel.Size = UDim2.new(0, 100, 0, 13)
    rarLabel.Position = UDim2.new(0, 66, 0, 43)
    rarLabel.BackgroundTransparency = 1
    rarLabel.Text = petData.rarity
    rarLabel.TextColor3 = Color3.fromHex("667799")
    rarLabel.TextSize = 10
    rarLabel.Font = Enum.Font.Gotham
    rarLabel.TextXAlignment = Enum.TextXAlignment.Left
    rarLabel.Parent = card

    -- Доход в секунду
    local earningsLabel = Instance.new("TextLabel")
    earningsLabel.Size = UDim2.new(0, 80, 0, 13)
    earningsLabel.Position = UDim2.new(1, -168, 0, 8)
    earningsLabel.BackgroundTransparency = 1
    earningsLabel.Text = "💰 " .. (petData.earnings ~= "" and petData.earnings or "—")
    earningsLabel.TextColor3 = Color3.fromHex("88cc66")
    earningsLabel.TextSize = 10
    earningsLabel.Font = Enum.Font.Gotham
    earningsLabel.TextXAlignment = Enum.TextXAlignment.Right
    earningsLabel.Parent = card

    -- Таймер
    local timerLabel = Instance.new("TextLabel")
    timerLabel.Size = UDim2.new(0, 80, 0, 13)
    timerLabel.Position = UDim2.new(1, -168, 0, 24)
    timerLabel.BackgroundTransparency = 1
    timerLabel.Text = "⏱ " .. (petData.timer ~= "" and petData.timer or "—")
    timerLabel.TextColor3 = Color3.fromHex("aa8866")
    timerLabel.TextSize = 10
    timerLabel.Font = Enum.Font.Gotham
    timerLabel.TextXAlignment = Enum.TextXAlignment.Right
    timerLabel.Parent = card

    -- Кнопка Steal
    local stealBtn = Instance.new("TextButton")
    stealBtn.Size = UDim2.new(0, 64, 0, 28)
    stealBtn.Position = UDim2.new(1, -74, 0.5, -14)
    stealBtn.BackgroundColor3 = Color3.fromHex("dd2244")
    stealBtn.TextColor3 = Color3.fromHex("ffffff")
    stealBtn.Text = "STEAL"
    stealBtn.TextSize = 11
    stealBtn.Font = Enum.Font.GothamBold
    stealBtn.BorderSizePixel = 0
    stealBtn.AutoButtonColor = false
    addCorner(stealBtn, 6)
    stealBtn.Parent = card

    -- Hover-эффект на кнопке
    stealBtn.MouseEnter:Connect(function()
        TweenService:Create(stealBtn,
            TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromHex("ff3355") }):Play()
    end)
    stealBtn.MouseLeave:Connect(function()
        TweenService:Create(stealBtn,
            TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromHex("dd2244") }):Play()
    end)

    stealBtn.MouseButton1Click:Connect(function()
        if state.stealBusy then
            statusLabel.Text = "⚠ Steal уже выполняется..."
            return
        end
        statusLabel.Text = "🎯 Стилим: " .. petData.name
        stealBtn.Text = "..."
        stealBtn.BackgroundColor3 = Color3.fromHex("886622")

        task.spawn(function()
            stealPet(petData)
            statusLabel.Text = "✅ Готово!"
        end)
    end)

    return card
end

-- ============================================================
--  ОБНОВЛЕНИЕ СПИСКА ПЕТОВ
-- ============================================================

local lastRarityCount = 0

local function refreshPetList()
    -- Сканируем петов
    local pets = scanPets()
    state.pets = pets

    -- Если появились новые редкости — перестраиваем фильтр
    local count = 0
    for _ in pairs(state.knownRarities) do count = count + 1 end
    if count ~= lastRarityCount then
        rebuildRarityFilters()
        lastRarityCount = count
    end

    -- Очищаем старые карточки
    for _, child in ipairs(petScroll:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end

    -- Фильтруем и строим карточки
    local visible = 0
    for i, pet in ipairs(pets) do
        local rarityOk  = state.activeRarities[pet.rarity]
        local mutOk     = state.activeMutations[pet.mutation]
            -- Если мутация неизвестная — показываем по умолчанию
            or (not CONFIG.MUTATION_COLORS[pet.mutation])
        if rarityOk and mutOk then
            local card = makePetCard(pet, i)
            card.Parent = petScroll
            visible = visible + 1
        end
    end

    -- Авто-высота холста
    petScroll.CanvasSize = UDim2.new(0, 0, 0,
        visible * 66 + 10)

    statusLabel.Text = string.format(
        "Найдено: %d пет(ов) | Показано: %d | %s",
        #pets, visible, os.date("%H:%M:%S")
    )
end

-- ============================================================
--  DRAGGING (перетаскивание окна)
-- ============================================================
do
    local dragging = false
    local dragStart, startPos

    titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging  = true
            dragStart = input.Position
            startPos  = mainFrame.Position
        end
    end)

    titleBar.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
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
end

-- ============================================================
--  КНОПКИ УПРАВЛЕНИЯ GUI
-- ============================================================
closeBtn.MouseButton1Click:Connect(function()
    screenGui:Destroy()
end)

toggleBtn.MouseButton1Click:Connect(function()
    state.guiVisible = not state.guiVisible
    bodyFrame.Visible = state.guiVisible
    mainFrame.Size = state.guiVisible
        and UDim2.new(0, 420, 0, 560)
        or  UDim2.new(0, 420, 0, 42)
    toggleBtn.Text = state.guiVisible and "—" or "□"
end)

-- ============================================================
--  ГОРЯЧАЯ КЛАВИША  (RightAlt — скрыть/показать окно)
-- ============================================================
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    -- Меняй KeyCode под свой вкус
    if input.KeyCode == Enum.KeyCode.RightAlt then
        screenGui.Enabled = not screenGui.Enabled
    end
end)

-- ============================================================
--  ИНИЦИАЛИЗАЦИЯ И ЦИКЛ ОБНОВЛЕНИЯ
-- ============================================================
buildMutationFilters()
rebuildRarityFilters()

-- Первый запуск
refreshPetList()

-- Обновление по таймеру (не каждый кадр — экономим FPS)
local timeSinceRefresh = 0
RunService.Heartbeat:Connect(function(dt)
    timeSinceRefresh = timeSinceRefresh + dt
    if timeSinceRefresh >= CONFIG.REFRESH_INTERVAL then
        timeSinceRefresh = 0
        -- task.spawn чтобы не блокировать Heartbeat
        task.spawn(refreshPetList)
    end
end)

print("[PetMonitor] GUI загружен. RightAlt — скрыть/показать.")
