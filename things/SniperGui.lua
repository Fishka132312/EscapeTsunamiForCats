-- ══════════════════════════════════════════════════════════════
-- PET SNIPER v1.0 | LocalScriptфффывывывыв
-- ══════════════════════════════════════════════════════════════

local Players            = game:GetService("Players")
local RunService         = game:GetService("RunService")
local TweenService       = game:GetService("TweenService")
local UserInputService   = game:GetService("UserInputService")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")

local LocalPlayer        = Players.LocalPlayer
local PlayerGui          = LocalPlayer:WaitForChild("PlayerGui")
local Character          = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local HumanoidRootPart   = Character:WaitForChild("HumanoidRootPart")

local workspace          = game:GetService("Workspace")
local ItemSpawners       = workspace:WaitForChild("ItemSpawners")

-- ══════════════════════════════════════════════════════════════
-- КОНСТАНТЫ
-- ══════════════════════════════════════════════════════════════

local RARITY_FOLDERS = {
    "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythical", "OG", "SpecialItemSpawn"
}

local RARITY_ORDER = {
    SpecialItemSpawn = 1, OG = 2, Mythical = 3, Legendary = 4,
    Epic = 5, Rare = 6, Uncommon = 7, Common = 8,
}

local RARITY_COLORS = {
    Common           = Color3.fromRGB(180, 180, 180),
    Uncommon         = Color3.fromRGB(71,  231, 160),
    Rare             = Color3.fromRGB(0,   242, 255),
    Epic             = Color3.fromRGB(255,  71, 255),
    Legendary        = Color3.fromRGB(255, 162,   0),
    Mythical         = Color3.fromRGB(255,  99, 152),
    OG               = Color3.fromRGB(52,  214, 137),
    SpecialItemSpawn = Color3.fromRGB(80,  220, 255),
}

local MUTATION_ORDER = {
    Divine = 1, Neon = 2, Blood = 3, Rainbow = 4,
    Ruby = 5, Diamond = 6, Golden = 7, Normal = 8,
}

local MUTATION_COLORS = {
    Normal  = Color3.fromRGB(200, 200, 200),
    Golden  = Color3.fromRGB(255, 247,   0),
    Diamond = Color3.fromRGB(25,  255, 255),
    Ruby    = Color3.fromRGB(255,  23,  55),
    Rainbow = Color3.fromRGB(0,   255, 170),
    Blood   = Color3.fromRGB(255,   0,   0),
    Neon    = Color3.fromRGB(215, 255,   0),
    Divine  = Color3.fromRGB(255, 232,  36),
}

local MUTATION_LIST = { "Normal","Golden","Diamond","Ruby","Rainbow","Blood","Neon","Divine" }

local STEAL_TELEPORT_WAIT = 0.35
local STEAL_PROMPT_WAIT   = 0.15
local STEAL_RETURN_WAIT   = 0.5

-- ══════════════════════════════════════════════════════════════
-- ЗАГРУЗКА КОНФИГОВ ПЕТОВ
-- ══════════════════════════════════════════════════════════════

local itemConfig = nil
local allPetNames = {}  -- список всех имён петов из конфига

local ok, result = pcall(function()
    return require(ReplicatedStorage.Modules.ItemConfigurations)
end)

if ok and result and result.Items then
    itemConfig = result.Items
    for name, _ in pairs(itemConfig) do
        table.insert(allPetNames, name)
    end
    table.sort(allPetNames)
end

-- ══════════════════════════════════════════════════════════════
-- СОСТОЯНИЕ СНАЙПЕРА
-- ══════════════════════════════════════════════════════════════

local sniperActive      = false
local selectedPets      = {}   -- { [petName] = true }
local selectedMutations = {}   -- { [mutation] = true }
local snipeAllMutations = false
local snipeAllPets      = false

-- Инициализируем все мутации как выбранные
for _, mut in ipairs(MUTATION_LIST) do
    selectedMutations[mut] = true
end

-- SafeZone — ищем или берём spawn
local function getSafeZonePosition()
    local safeZone = workspace:FindFirstChild("SafeZone")
    if safeZone then
        local part = safeZone:FindFirstChildWhichIsA("BasePart")
        if part then return part.Position + Vector3.new(0, 5, 0) end
    end
    -- Fallback: SpawnLocation
    local spawn = workspace:FindFirstChildWhichIsA("SpawnLocation")
    if spawn then return spawn.Position + Vector3.new(0, 5, 0) end
    return Vector3.new(0, 10, 0)
end

-- ══════════════════════════════════════════════════════════════
-- ИЗВЛЕЧЕНИЕ ДАННЫХ ПЕТА
-- ══════════════════════════════════════════════════════════════

local function extractPetData(pet, rarityKey)
    local data = {
        rarityKey = rarityKey,
        name      = "Unknown",
        mutation  = "Normal",
        timerText = "—",
        headPart  = nil,
        prompt    = nil,
    }

    local infoGUI = pet:FindFirstChild("InfoGUI")
    if infoGUI then
        local textLabels = infoGUI:FindFirstChild("TextLabels")
        if textLabels then
            local nameLabel = textLabels:FindFirstChild("Name")
            local mutLabel  = textLabels:FindFirstChild("Mutation")
            local timerLabel = textLabels:FindFirstChild("Timer")
            if nameLabel  then data.name     = nameLabel.Text:gsub("<[^<>]+>", "") end
            if mutLabel   then data.mutation = mutLabel.Text:gsub("<[^<>]+>", "") end
            if timerLabel then data.timerText = timerLabel.Text end
        end
    end

    local head = pet:FindFirstChild("Head")
    if head then
        data.headPart = head
        data.prompt   = head:FindFirstChildOfClass("ProximityPrompt")
    end

    return data
end

-- ══════════════════════════════════════════════════════════════
-- ЛОГИКА СНАЙПА
-- ══════════════════════════════════════════════════════════════

local isStealing = false
local gatheredCount = 0 -- Текущее количество петов в руках

-- =======================================================================
-- 1. ФУНКЦИЯ ПОЛУЧЕНИЯ МАКСИМАЛЬНОГО ЛИМИТА ИЗ UI
-- =======================================================================
local function getCurrentCarryLimit()
    local playerGui = LocalPlayer:WaitForChild("PlayerGui")
    
    local carryFrame = playerGui:FindFirstChild("GUI") 
        and playerGui.GUI:FindFirstChild("Frames") 
        and playerGui.GUI.Frames:FindFirstChild("Carry") 
        and playerGui.GUI.Frames.Carry:FindFirstChild("Scrolling")

    if carryFrame then
        local upgradeTemplate = carryFrame:FindFirstChild("CarryUpgrade")
        if upgradeTemplate then
            local stats = upgradeTemplate:FindFirstChild("Stats")
            if stats then
                local beforeText = stats:FindFirstChild("Before") and stats.Before:FindFirstChild("Text")
                
                if beforeText and beforeText.Text then
                    local limit = tonumber(beforeText.Text:match("%d+"))
                    if limit then return limit end 
                end
            end
        end
    end
    return 1 -- Безопасный лимит по умолчанию
end

-- =======================================================================
-- 2. ФУНКЦИЯ ТЕЛЕПОРТА НА БАЗУ ДЛЯ РАЗГРУЗКИ
-- =======================================================================
local function teleportToSafeZone()
    pcall(function()
        Character       = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
        HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")
        
        print("[Sniper] Возврат / разгрузка в SafeZone...")
        HumanoidRootPart.CFrame = CFrame.new(getSafeZonePosition())
        task.wait(1.5) -- Ждем, чтобы игра успела забрать петов и очистить инвентарь
        gatheredCount = 0 -- Обнуляем счётчик строго НА БАЗЕ
    end)
end

-- =======================================================================
-- 3. ИСПРАВЛЕННАЯ ФУНКЦИЯ КРАЖИ С ЭКСТРЕННЫМ ВЫХОДОМ
-- =======================================================================
local function stealPet(pet, petData)
    if isStealing then return end
    if not sniperActive then return end -- Защита от старта, если уже выключили
    isStealing = true

    pcall(function()
        Character       = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
        HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")

        local maxCarry = getCurrentCarryLimit()

        -- 1. Телепорт к пету
        if petData and petData.headPart and petData.headPart:IsDescendantOf(workspace) then
            HumanoidRootPart.CFrame = petData.headPart.CFrame + Vector3.new(0, 2, 0)
        end
        
        task.wait(STEAL_TELEPORT_WAIT)
        if not sniperActive then error("STOP") end -- Мгновенный сброс, если выключили во время ожидания

        -- 2. Активация ProximityPrompt
        if pet and pet:IsDescendantOf(workspace) and petData and petData.prompt and petData.prompt:IsDescendantOf(workspace) then
            task.wait(STEAL_PROMPT_WAIT)
            if not sniperActive then error("STOP") end -- Проверка перед промптом
            
            fireproximityprompt(petData.prompt)
            
            gatheredCount = gatheredCount + 1 
            print("[Sniper] Подобрано: " .. tostring(gatheredCount) .. " / " .. tostring(maxCarry))
        end

        task.wait(STEAL_RETURN_WAIT)
        if not sniperActive then error("STOP") end -- Проверка после промпта

        -- 3. Проверка лимита: если забились, летим на базу
        if gatheredCount >= maxCarry then
            teleportToSafeZone()
        end
    end)

    -- Если во время кражи чит выключили, pcall поймает ошибку "STOP" и сразу перенаправит сюда
    if not sniperActive then
        teleportToSafeZone() -- Принудительно возвращаем в сейф зону
    end

    isStealing = false 
end

-- Проверяем, подходит ли пет под фильтры
local function petMatchesFilters(petData)
    if not petData then return false end
    
    if not snipeAllPets then
        if not selectedPets[petData.name] then return false end
    end
    if not snipeAllMutations then
        if not selectedMutations[petData.mutation] then return false end
    end
    return true
end

-- Бесконечно сканируем все папки, пока активен снайпер
local function scanAndSnipe()
    while sniperActive do
        local targetFound = false
        local maxCarry = getCurrentCarryLimit()

        if gatheredCount >= maxCarry and not isStealing then
            isStealing = true
            teleportToSafeZone()
            isStealing = false
        end

        for _, folderName in ipairs(RARITY_FOLDERS) do
            if not sniperActive then break end -- Прерываем, если выключили

            local folder = ItemSpawners:FindFirstChild(folderName)
            if folder then
                for _, pet in ipairs(folder:GetChildren()) do
                    if not sniperActive then break end

                    if pet:IsA("Model") then
                        local petData = extractPetData(pet, folderName)
                        
                        if petMatchesFilters(petData) and not isStealing and gatheredCount < maxCarry then
                            targetFound = true
                            stealPet(pet, petData)
                            break 
                        end
                    end
                end
            end
            if targetFound then break end
        end
        
        task.wait(0.5) 
    end
end

-- Подписка на новые петы
local connections = {}

local function connectSpawners()
    for _, conn in ipairs(connections) do conn:Disconnect() end
    connections = {}

    for _, folderName in ipairs(RARITY_FOLDERS) do
        local folder = ItemSpawners:FindFirstChild(folderName)
        if folder then
            local conn = folder.ChildAdded:Connect(function(pet)
                if not sniperActive then return end
                task.wait(0.1) 
                
                if pet:IsA("Model") then
                    local petData = extractPetData(pet, folderName)
                    if petMatchesFilters(petData) then
                        task.spawn(function()
                            local timeout = 0
                            while isStealing and timeout < 5 do
                                if not sniperActive then return end -- Выход из очереди ожидания
                                task.wait(0.1)
                                timeout = timeout + 0.1
                            end
                            
                            if not sniperActive then return end

                            local maxCarry = getCurrentCarryLimit()
                            if gatheredCount < maxCarry then
                                stealPet(pet, petData)
                            else
                                if not isStealing then
                                    isStealing = true
                                    teleportToSafeZone()
                                    isStealing = false
                                end
                            end
                        end)
                    end
                end
            end)
            table.insert(connections, conn)
        end
    end
end

-- ══════════════════════════════════════════════════════════════
-- GUI
-- ══════════════════════════════════════════════════════════════

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name         = "PetSniper"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = PlayerGui

-- Главная рамка
local MainFrame = Instance.new("Frame")
MainFrame.Name            = "MainFrame"
MainFrame.Size            = UDim2.new(0, 480, 0, 560)
MainFrame.Position        = UDim2.new(0.5, -240, 0.5, -280)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
MainFrame.BorderSizePixel = 0
MainFrame.Active          = true
MainFrame.Draggable       = true
MainFrame.Parent          = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 10)
MainCorner.Parent = MainFrame

local MainStroke = Instance.new("UIStroke")
MainStroke.Color     = Color3.fromRGB(80, 160, 255)
MainStroke.Thickness = 1.5
MainStroke.Parent    = MainFrame

-- Заголовок
local TitleBar = Instance.new("Frame")
TitleBar.Size             = UDim2.new(1, 0, 0, 40)
TitleBar.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
TitleBar.BorderSizePixel  = 0
TitleBar.Parent           = MainFrame

local TitleCorner = Instance.new("UICorner")
TitleCorner.CornerRadius = UDim.new(0, 10)
TitleCorner.Parent = TitleBar

-- Скрыть нижние скруглённые углы у TitleBar
local TitleFix = Instance.new("Frame")
TitleFix.Size             = UDim2.new(1, 0, 0.5, 0)
TitleFix.Position         = UDim2.new(0, 0, 0.5, 0)
TitleFix.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
TitleFix.BorderSizePixel  = 0
TitleFix.Parent           = TitleBar

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size              = UDim2.new(1, -50, 1, 0)
TitleLabel.Position          = UDim2.new(0, 15, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text              = "🐾  PET SNIPER"
TitleLabel.TextColor3        = Color3.fromRGB(80, 160, 255)
TitleLabel.TextSize          = 16
TitleLabel.Font              = Enum.Font.GothamBold
TitleLabel.TextXAlignment    = Enum.TextXAlignment.Left
TitleLabel.Parent            = TitleBar

-- Кнопка закрыть
local CloseBtn = Instance.new("TextButton")
CloseBtn.Size             = UDim2.new(0, 30, 0, 30)
CloseBtn.Position         = UDim2.new(1, -38, 0, 5)
CloseBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
CloseBtn.Text             = "✕"
CloseBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
CloseBtn.TextSize         = 14
CloseBtn.Font             = Enum.Font.GothamBold
CloseBtn.BorderSizePixel  = 0
CloseBtn.Parent           = TitleBar

local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(0, 6)
CloseCorner.Parent = CloseBtn

CloseBtn.MouseButton1Click:Connect(function()
    ScreenGui:Destroy()
    sniperActive = false
    for _, conn in ipairs(connections) do conn:Disconnect() end
end)

-- ── Статус-строка ──────────────────────────────────────────────

local StatusBar = Instance.new("Frame")
StatusBar.Size             = UDim2.new(1, -20, 0, 32)
StatusBar.Position         = UDim2.new(0, 10, 0, 48)
StatusBar.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
StatusBar.BorderSizePixel  = 0
StatusBar.Parent           = MainFrame

local StatusCorner = Instance.new("UICorner")
StatusCorner.CornerRadius = UDim.new(0, 7)
StatusCorner.Parent = StatusBar

local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size              = UDim2.new(1, -10, 1, 0)
StatusLabel.Position          = UDim2.new(0, 10, 0, 0)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text              = "⏹  Снайпер остановлен"
StatusLabel.TextColor3        = Color3.fromRGB(180, 180, 180)
StatusLabel.TextSize          = 13
StatusLabel.Font              = Enum.Font.Gotham
StatusLabel.TextXAlignment    = Enum.TextXAlignment.Left
StatusLabel.Parent            = StatusBar

-- ── Табы ────────────────────────────────────────────────────────

local TabBar = Instance.new("Frame")
TabBar.Size             = UDim2.new(1, -20, 0, 30)
TabBar.Position         = UDim2.new(0, 10, 0, 88)
TabBar.BackgroundTransparency = 1
TabBar.Parent           = MainFrame

local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection  = Enum.FillDirection.Horizontal
tabLayout.Padding        = UDim.new(0, 6)
tabLayout.Parent         = TabBar

local tabNames = { "Петы", "Мутации", "Настройки" }
local tabs     = {}
local tabPages = {}
local activeTab = "Петы"

for _, name in ipairs(tabNames) do
    local btn = Instance.new("TextButton")
    btn.Size             = UDim2.new(0, 140, 1, 0)
    btn.BackgroundColor3 = Color3.fromRGB(30, 30, 42)
    btn.Text             = name
    btn.TextColor3       = Color3.fromRGB(140, 140, 160)
    btn.TextSize         = 13
    btn.Font             = Enum.Font.GothamSemibold
    btn.BorderSizePixel  = 0
    btn.Parent           = TabBar

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 6)
    btnCorner.Parent = btn

    tabs[name] = btn

    -- Страница
    local page = Instance.new("Frame")
    page.Size             = UDim2.new(1, -20, 0, 360)
    page.Position         = UDim2.new(0, 10, 0, 125)
    page.BackgroundTransparency = 1
    page.Visible          = (name == "Петы")
    page.Parent           = MainFrame
    tabPages[name] = page
end

local function switchTab(name)
    activeTab = name
    for tName, btn in pairs(tabs) do
        if tName == name then
            btn.BackgroundColor3 = Color3.fromRGB(80, 160, 255)
            btn.TextColor3       = Color3.fromRGB(255, 255, 255)
        else
            btn.BackgroundColor3 = Color3.fromRGB(30, 30, 42)
            btn.TextColor3       = Color3.fromRGB(140, 140, 160)
        end
        tabPages[tName].Visible = (tName == name)
    end
end

for tName, btn in pairs(tabs) do
    btn.MouseButton1Click:Connect(function() switchTab(tName) end)
end

switchTab("Петы")

-- ══════════════════════════════════════════════════════════════
-- СТРАНИЦА ПЕТОВ
-- ══════════════════════════════════════════════════════════════

local PetsPage = tabPages["Петы"]

-- Поиск
local SearchBox = Instance.new("TextBox")
SearchBox.Size             = UDim2.new(1, 0, 0, 30)
SearchBox.Position         = UDim2.new(0, 0, 0, 0)
SearchBox.BackgroundColor3 = Color3.fromRGB(30, 30, 42)
SearchBox.PlaceholderText  = "🔍  Поиск пета..."
SearchBox.PlaceholderColor3 = Color3.fromRGB(100, 100, 120)
SearchBox.Text             = ""
SearchBox.TextColor3       = Color3.fromRGB(220, 220, 220)
SearchBox.TextSize         = 13
SearchBox.Font             = Enum.Font.Gotham
SearchBox.BorderSizePixel  = 0
SearchBox.ClearTextOnFocus = false
SearchBox.Parent           = PetsPage

local SearchCorner = Instance.new("UICorner")
SearchCorner.CornerRadius = UDim.new(0, 6)
SearchCorner.Parent = SearchBox

-- Кнопка "Выбрать все"
local SelectAllBtn = Instance.new("TextButton")
SelectAllBtn.Size             = UDim2.new(0, 100, 0, 26)
SelectAllBtn.Position         = UDim2.new(0, 0, 0, 36)
SelectAllBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
SelectAllBtn.Text             = "Все петы"
SelectAllBtn.TextColor3       = Color3.fromRGB(200, 200, 200)
SelectAllBtn.TextSize         = 12
SelectAllBtn.Font             = Enum.Font.Gotham
SelectAllBtn.BorderSizePixel  = 0
SelectAllBtn.Parent           = PetsPage

local SelectAllCorner = Instance.new("UICorner")
SelectAllCorner.CornerRadius = UDim.new(0, 5)
SelectAllCorner.Parent = SelectAllBtn

local ClearAllBtn = Instance.new("TextButton")
ClearAllBtn.Size             = UDim2.new(0, 100, 0, 26)
ClearAllBtn.Position         = UDim2.new(0, 108, 0, 36)
ClearAllBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
ClearAllBtn.Text             = "Снять все"
ClearAllBtn.TextColor3       = Color3.fromRGB(200, 200, 200)
ClearAllBtn.TextSize         = 12
ClearAllBtn.Font             = Enum.Font.Gotham
ClearAllBtn.BorderSizePixel  = 0
ClearAllBtn.Parent           = PetsPage

local ClearAllCorner = Instance.new("UICorner")
ClearAllCorner.CornerRadius = UDim.new(0, 5)
ClearAllCorner.Parent = ClearAllBtn

-- Список петов (прокручиваемый)
local PetScroll = Instance.new("ScrollingFrame")
PetScroll.Size              = UDim2.new(1, 0, 0, 285)
PetScroll.Position          = UDim2.new(0, 0, 0, 68)
PetScroll.BackgroundColor3  = Color3.fromRGB(20, 20, 28)
PetScroll.BorderSizePixel   = 0
PetScroll.ScrollBarThickness = 4
PetScroll.ScrollBarImageColor3 = Color3.fromRGB(80, 160, 255)
PetScroll.CanvasSize        = UDim2.new(0, 0, 0, 0)
PetScroll.Parent            = PetsPage

local ScrollCorner = Instance.new("UICorner")
ScrollCorner.CornerRadius = UDim.new(0, 7)
ScrollCorner.Parent = PetScroll

local PetListLayout = Instance.new("UIListLayout")
PetListLayout.Padding       = UDim.new(0, 2)
PetListLayout.SortOrder     = Enum.SortOrder.LayoutOrder
PetListLayout.Parent        = PetScroll

local PetListPad = Instance.new("UIPadding")
PetListPad.PaddingTop    = UDim.new(0, 4)
PetListPad.PaddingLeft   = UDim.new(0, 4)
PetListPad.PaddingRight  = UDim.new(0, 4)
PetListPad.Parent        = PetScroll

local petButtons = {}

local function createPetButton(petName)
    local rarity = (itemConfig and itemConfig[petName] and itemConfig[petName].Rarity) or "Common"
    local rarityColor = RARITY_COLORS[rarity] or Color3.fromRGB(180, 180, 180)

    local btn = Instance.new("TextButton")
    btn.Size             = UDim2.new(1, -8, 0, 30)
    btn.BackgroundColor3 = Color3.fromRGB(28, 28, 38)
    btn.Text             = ""
    btn.BorderSizePixel  = 0
    btn.AutoButtonColor  = false
    btn.Parent           = PetScroll

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 5)
    btnCorner.Parent = btn

    -- Цветная полоска редкости
    local rarityBar = Instance.new("Frame")
    rarityBar.Size             = UDim2.new(0, 3, 1, -6)
    rarityBar.Position         = UDim2.new(0, 3, 0, 3)
    rarityBar.BackgroundColor3 = rarityColor
    rarityBar.BorderSizePixel  = 0
    rarityBar.Parent           = btn

    local barCorner = Instance.new("UICorner")
    barCorner.CornerRadius = UDim.new(0, 2)
    barCorner.Parent = rarityBar

    -- Имя пета
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size              = UDim2.new(1, -50, 1, 0)
    nameLabel.Position          = UDim2.new(0, 12, 0, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text              = petName
    nameLabel.TextColor3        = Color3.fromRGB(220, 220, 220)
    nameLabel.TextSize          = 12
    nameLabel.Font              = Enum.Font.Gotham
    nameLabel.TextXAlignment    = Enum.TextXAlignment.Left
    nameLabel.TextTruncate      = Enum.TextTruncate.AtEnd
    nameLabel.Parent            = btn

    -- Редкость справа
    local rarityLabel = Instance.new("TextLabel")
    rarityLabel.Size              = UDim2.new(0, 80, 1, 0)
    rarityLabel.Position          = UDim2.new(1, -85, 0, 0)
    rarityLabel.BackgroundTransparency = 1
    rarityLabel.Text              = rarity
    rarityLabel.TextColor3        = rarityColor
    rarityLabel.TextSize          = 10
    rarityLabel.Font              = Enum.Font.GothamSemibold
    rarityLabel.TextXAlignment    = Enum.TextXAlignment.Right
    rarityLabel.Parent            = btn

    -- Чекбокс
    local checkMark = Instance.new("TextLabel")
    checkMark.Size              = UDim2.new(0, 18, 0, 18)
    checkMark.Position          = UDim2.new(1, -22, 0.5, -9)
    checkMark.BackgroundColor3  = Color3.fromRGB(30, 30, 42)
    checkMark.Text              = ""
    checkMark.TextColor3        = Color3.fromRGB(80, 200, 100)
    checkMark.TextSize          = 12
    checkMark.Font              = Enum.Font.GothamBold
    checkMark.BorderSizePixel   = 0
    checkMark.Parent            = btn

    local checkCorner = Instance.new("UICorner")
    checkCorner.CornerRadius = UDim.new(0, 4)
    checkCorner.Parent = checkMark

    local function updateCheck()
        if selectedPets[petName] then
            checkMark.Text             = "✓"
            checkMark.BackgroundColor3 = Color3.fromRGB(30, 80, 40)
            btn.BackgroundColor3       = Color3.fromRGB(25, 45, 30)
        else
            checkMark.Text             = ""
            checkMark.BackgroundColor3 = Color3.fromRGB(30, 30, 42)
            btn.BackgroundColor3       = Color3.fromRGB(28, 28, 38)
        end
    end

    btn.MouseButton1Click:Connect(function()
        selectedPets[petName] = not selectedPets[petName]
        updateCheck()
    end)

    updateCheck()
    petButtons[petName] = { button = btn, updateCheck = updateCheck }
    return btn
end

-- Заполняем список
local function refreshPetList(filter)
    filter = (filter or ""):lower()
    local count = 0
    for _, name in ipairs(allPetNames) do
        local btn = petButtons[name]
        if btn then
            local visible = filter == "" or name:lower():find(filter, 1, true)
            btn.button.Visible = visible ~= nil and visible ~= false
        end
        count += 1
    end
    PetScroll.CanvasSize = UDim2.new(0, 0, 0, PetListLayout.AbsoluteContentSize.Y + 8)
end

for _, name in ipairs(allPetNames) do
    createPetButton(name)
end
PetScroll.CanvasSize = UDim2.new(0, 0, 0, PetListLayout.AbsoluteContentSize.Y + 8)

SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
    refreshPetList(SearchBox.Text)
end)

SelectAllBtn.MouseButton1Click:Connect(function()
    snipeAllPets = true
    for _, name in ipairs(allPetNames) do
        selectedPets[name] = true
        if petButtons[name] then petButtons[name].updateCheck() end
    end
end)

ClearAllBtn.MouseButton1Click:Connect(function()
    snipeAllPets = false
    for _, name in ipairs(allPetNames) do
        selectedPets[name] = false
        if petButtons[name] then petButtons[name].updateCheck() end
    end
end)

-- ══════════════════════════════════════════════════════════════
-- СТРАНИЦА МУТАЦИЙ
-- ══════════════════════════════════════════════════════════════

local MutPage = tabPages["Мутации"]

local MutTitleLabel = Instance.new("TextLabel")
MutTitleLabel.Size              = UDim2.new(1, 0, 0, 24)
MutTitleLabel.BackgroundTransparency = 1
MutTitleLabel.Text              = "Выбери мутации для снайпа:"
MutTitleLabel.TextColor3        = Color3.fromRGB(160, 160, 180)
MutTitleLabel.TextSize          = 13
MutTitleLabel.Font              = Enum.Font.Gotham
MutTitleLabel.TextXAlignment    = Enum.TextXAlignment.Left
MutTitleLabel.Parent            = MutPage

local MutGrid = Instance.new("Frame")
MutGrid.Size             = UDim2.new(1, 0, 0, 280)
MutGrid.Position         = UDim2.new(0, 0, 0, 28)
MutGrid.BackgroundTransparency = 1
MutGrid.Parent           = MutPage

local MutGridLayout = Instance.new("UIGridLayout")
MutGridLayout.CellSize    = UDim2.new(0, 210, 0, 46)
MutGridLayout.CellPadding = UDim2.new(0, 8, 0, 8)
MutGridLayout.Parent      = MutGrid

local mutButtons = {}

local function createMutationButton(mutName)
    local color = MUTATION_COLORS[mutName] or Color3.fromRGB(200, 200, 200)

    local btn = Instance.new("TextButton")
    btn.Size             = UDim2.new(0, 210, 0, 46)
    btn.BackgroundColor3 = Color3.fromRGB(28, 28, 38)
    btn.Text             = ""
    btn.BorderSizePixel  = 0
    btn.AutoButtonColor  = false
    btn.Parent           = MutGrid

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 7)
    btnCorner.Parent = btn

    local colorBar = Instance.new("Frame")
    colorBar.Size             = UDim2.new(0, 4, 1, -10)
    colorBar.Position         = UDim2.new(0, 5, 0, 5)
    colorBar.BackgroundColor3 = color
    colorBar.BorderSizePixel  = 0
    colorBar.Parent           = btn

    local barCorner2 = Instance.new("UICorner")
    barCorner2.CornerRadius = UDim.new(0, 2)
    barCorner2.Parent = colorBar

    local mutLabel = Instance.new("TextLabel")
    mutLabel.Size              = UDim2.new(1, -50, 1, 0)
    mutLabel.Position          = UDim2.new(0, 16, 0, 0)
    mutLabel.BackgroundTransparency = 1
    mutLabel.Text              = mutName
    mutLabel.TextColor3        = color
    mutLabel.TextSize          = 14
    mutLabel.Font              = Enum.Font.GothamBold
    mutLabel.TextXAlignment    = Enum.TextXAlignment.Left
    mutLabel.Parent            = btn

    local checkMark = Instance.new("TextLabel")
    checkMark.Size              = UDim2.new(0, 22, 0, 22)
    checkMark.Position          = UDim2.new(1, -28, 0.5, -11)
    checkMark.BackgroundColor3  = Color3.fromRGB(30, 30, 42)
    checkMark.Text              = ""
    checkMark.TextColor3        = Color3.fromRGB(80, 200, 100)
    checkMark.TextSize          = 14
    checkMark.Font              = Enum.Font.GothamBold
    checkMark.BorderSizePixel   = 0
    checkMark.Parent            = btn

    local checkCorner2 = Instance.new("UICorner")
    checkCorner2.CornerRadius = UDim.new(0, 5)
    checkCorner2.Parent = checkMark

    local function updateMutCheck()
        if selectedMutations[mutName] then
            checkMark.Text             = "✓"
            checkMark.BackgroundColor3 = Color3.fromRGB(30, 80, 40)
            btn.BackgroundColor3       = Color3.fromRGB(25, 45, 30)
        else
            checkMark.Text             = ""
            checkMark.BackgroundColor3 = Color3.fromRGB(30, 30, 42)
            btn.BackgroundColor3       = Color3.fromRGB(28, 28, 38)
        end
    end

    btn.MouseButton1Click:Connect(function()
        selectedMutations[mutName] = not selectedMutations[mutName]
        -- Если все выбраны — включаем snipeAllMutations
        local allSelected = true
        for _, m in ipairs(MUTATION_LIST) do
            if not selectedMutations[m] then allSelected = false break end
        end
        snipeAllMutations = allSelected
        updateMutCheck()
    end)

    updateMutCheck()
    mutButtons[mutName] = { button = btn, updateCheck = updateMutCheck }
end

for _, name in ipairs(MUTATION_LIST) do
    createMutationButton(name)
end

-- Кнопки выбора всех мутаций
local MutSelectAll = Instance.new("TextButton")
MutSelectAll.Size             = UDim2.new(0, 120, 0, 28)
MutSelectAll.Position         = UDim2.new(0, 0, 0, 318)
MutSelectAll.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
MutSelectAll.Text             = "Все мутации"
MutSelectAll.TextColor3       = Color3.fromRGB(200, 200, 200)
MutSelectAll.TextSize         = 12
MutSelectAll.Font             = Enum.Font.Gotham
MutSelectAll.BorderSizePixel  = 0
MutSelectAll.Parent           = MutPage

local MutSelectAllCorner = Instance.new("UICorner")
MutSelectAllCorner.CornerRadius = UDim.new(0, 5)
MutSelectAllCorner.Parent = MutSelectAll

MutSelectAll.MouseButton1Click:Connect(function()
    snipeAllMutations = true
    for _, name in ipairs(MUTATION_LIST) do
        selectedMutations[name] = true
        if mutButtons[name] then mutButtons[name].updateCheck() end
    end
end)

local MutClearAll = Instance.new("TextButton")
MutClearAll.Size             = UDim2.new(0, 120, 0, 28)
MutClearAll.Position         = UDim2.new(0, 128, 0, 318)
MutClearAll.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
MutClearAll.Text             = "Снять все"
MutClearAll.TextColor3       = Color3.fromRGB(200, 200, 200)
MutClearAll.TextSize         = 12
MutClearAll.Font             = Enum.Font.Gotham
MutClearAll.BorderSizePixel  = 0
MutClearAll.Parent           = MutPage

local MutClearAllCorner = Instance.new("UICorner")
MutClearAllCorner.CornerRadius = UDim.new(0, 5)
MutClearAllCorner.Parent = MutClearAll

MutClearAll.MouseButton1Click:Connect(function()
    snipeAllMutations = false
    for _, name in ipairs(MUTATION_LIST) do
        selectedMutations[name] = false
        if mutButtons[name] then mutButtons[name].updateCheck() end
    end
end)

-- ══════════════════════════════════════════════════════════════
-- СТРАНИЦА НАСТРОЕК
-- ══════════════════════════════════════════════════════════════

local SettingsPage = tabPages["Настройки"]

local function createSettingRow(parent, yPos, label, default, onChanged)
    local row = Instance.new("Frame")
    row.Size             = UDim2.new(1, 0, 0, 36)
    row.Position         = UDim2.new(0, 0, 0, yPos)
    row.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    row.BorderSizePixel  = 0
    row.Parent           = parent

    local rowCorner = Instance.new("UICorner")
    rowCorner.CornerRadius = UDim.new(0, 6)
    rowCorner.Parent = row

    local lbl = Instance.new("TextLabel")
    lbl.Size              = UDim2.new(0.6, 0, 1, 0)
    lbl.Position          = UDim2.new(0, 10, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text              = label
    lbl.TextColor3        = Color3.fromRGB(180, 180, 200)
    lbl.TextSize          = 12
    lbl.Font              = Enum.Font.Gotham
    lbl.TextXAlignment    = Enum.TextXAlignment.Left
    lbl.Parent            = row

    local box = Instance.new("TextBox")
    box.Size             = UDim2.new(0, 80, 0, 24)
    box.Position         = UDim2.new(1, -88, 0.5, -12)
    box.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
    box.Text             = tostring(default)
    box.TextColor3       = Color3.fromRGB(220, 220, 220)
    box.TextSize         = 12
    box.Font             = Enum.Font.Gotham
    box.BorderSizePixel  = 0
    box.Parent           = row

    local boxCorner = Instance.new("UICorner")
    boxCorner.CornerRadius = UDim.new(0, 5)
    boxCorner.Parent = box

    box.FocusLost:Connect(function()
        local val = tonumber(box.Text)
        if val and val >= 0 then
            onChanged(val)
        else
            box.Text = tostring(default)
        end
    end)

    return row
end

createSettingRow(SettingsPage, 0,   "Задержка ТП к пету (сек):",   STEAL_TELEPORT_WAIT, function(v) STEAL_TELEPORT_WAIT = v end)
createSettingRow(SettingsPage, 44,  "Задержка промпта (сек):",      STEAL_PROMPT_WAIT,   function(v) STEAL_PROMPT_WAIT = v end)
createSettingRow(SettingsPage, 88,  "Задержка возврата (сек):",     STEAL_RETURN_WAIT,   function(v) STEAL_RETURN_WAIT = v end)

-- ── Инфо-блок ──────────────────────────────────────────────────

local InfoBlock = Instance.new("Frame")
InfoBlock.Size             = UDim2.new(1, 0, 0, 90)
InfoBlock.Position         = UDim2.new(0, 0, 0, 140)
InfoBlock.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
InfoBlock.BorderSizePixel  = 0
InfoBlock.Parent           = SettingsPage

local InfoCorner = Instance.new("UICorner")
InfoCorner.CornerRadius = UDim.new(0, 6)
InfoCorner.Parent = InfoBlock

local InfoText = Instance.new("TextLabel")
InfoText.Size              = UDim2.new(1, -16, 1, -8)
InfoText.Position          = UDim2.new(0, 8, 0, 4)
InfoText.BackgroundTransparency = 1
InfoText.Text              = "ℹ️  Как использовать:\n1. Выбери нужных петов на вкладке Петы\n2. Выбери мутации на вкладке Мутации\n3. Нажми СТАРТ\n\nСкрипт сам телепортирует тебя к пету и в SafeZone."
InfoText.TextColor3        = Color3.fromRGB(140, 140, 160)
InfoText.TextSize          = 12
InfoText.Font              = Enum.Font.Gotham
InfoText.TextXAlignment    = Enum.TextXAlignment.Left
InfoText.TextYAlignment    = Enum.TextYAlignment.Top
InfoText.TextWrapped       = true
InfoText.Parent            = InfoBlock

-- ══════════════════════════════════════════════════════════════
-- КНОПКА СТАРТ/СТОП
-- ══════════════════════════════════════════════════════════════

local StartBtn = Instance.new("TextButton")
StartBtn.Size             = UDim2.new(1, -20, 0, 42)
StartBtn.Position         = UDim2.new(0, 10, 1, -52)
StartBtn.BackgroundColor3 = Color3.fromRGB(50, 160, 80)
StartBtn.Text             = "▶  СТАРТ"
StartBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
StartBtn.TextSize         = 15
StartBtn.Font             = Enum.Font.GothamBold
StartBtn.BorderSizePixel  = 0
StartBtn.Parent           = MainFrame

local StartCorner = Instance.new("UICorner")
StartCorner.CornerRadius = UDim.new(0, 8)
StartCorner.Parent = StartBtn

local function updateStartBtn()
    if sniperActive then
        StartBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
        StartBtn.Text             = "⏹  СТОП"
        StatusLabel.Text          = "✅  Снайпер активен — ищу петов..."
        StatusLabel.TextColor3    = Color3.fromRGB(80, 220, 100)
    else
        StartBtn.BackgroundColor3 = Color3.fromRGB(50, 160, 80)
        StartBtn.Text             = "▶  СТАРТ"
        StatusLabel.Text          = "⏹  Снайпер остановлен"
        StatusLabel.TextColor3    = Color3.fromRGB(180, 180, 180)
    end
end

StartBtn.MouseButton1Click:Connect(function()
    -- Проверяем что выбран хотя бы один пет
    local hasPet = snipeAllPets
    if not hasPet then
        for _, v in pairs(selectedPets) do
            if v then hasPet = true break end
        end
    end

    if not hasPet then
        StatusLabel.Text       = "⚠️  Выбери хотя бы одного пета!"
        StatusLabel.TextColor3 = Color3.fromRGB(255, 180, 50)
        return
    end

    local hasMut = snipeAllMutations
    if not hasMut then
        for _, v in pairs(selectedMutations) do
            if v then hasMut = true break end
        end
    end

    if not hasMut then
        StatusLabel.Text       = "⚠️  Выбери хотя бы одну мутацию!"
        StatusLabel.TextColor3 = Color3.fromRGB(255, 180, 50)
        return
    end

    sniperActive = not sniperActive
    updateStartBtn()

    if sniperActive then
        connectSpawners()
        -- Также проверяем уже существующих петов
        task.spawn(scanAndSnipe)
    else
        for _, conn in ipairs(connections) do conn:Disconnect() end
        connections = {}
    end
end)

-- ══════════════════════════════════════════════════════════════
-- ОБНОВЛЕНИЕ СИМВОЛА HRP ПРИ РЕСПАВНЕ
-- ══════════════════════════════════════════════════════════════

LocalPlayer.CharacterAdded:Connect(function(char)
    Character        = char
    HumanoidRootPart = char:WaitForChild("HumanoidRootPart")
    if sniperActive then
        connectSpawners()
    end
end)

-- Готово!
StatusLabel.Text       = "⏹  Снайпер готов к работе"
StatusLabel.TextColor3 = Color3.fromRGB(160, 160, 180)
