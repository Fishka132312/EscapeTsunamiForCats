-- ╔══════════════════════════════════════════════════════════════════╗
-- ║           PET MONITOR GUI — LocalScript by Claude              ║
-- ║  Мониторинг петов: фильтрация, сортировка, Steal, телепорт     ║
-- ╚══════════════════════════════════════════════════════════════════╝

local Players       = game:GetService("Players")
local RunService    = game:GetService("RunService")
local TweenService  = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player        = Players.LocalPlayer
local character     = player.Character or player.CharacterAdded:Wait()
local playerGui     = player:WaitForChild("PlayerGui")
local workspace     = game:GetService("Workspace")

-- ──────────────────────────────────────────────────────────────────
-- КОНСТАНТЫ
-- ──────────────────────────────────────────────────────────────────

-- Папки со спавнерами (можно добавить ещё)
local SPAWNER_FOLDERS = {"Common", "Epic", "Mythic", "Legendary", "OG", "SpecialItemSpawn"}

-- Порядок редкостей (лучший = меньший индекс)
local RARITY_ORDER = {
	OG           = 1,
	Legendary    = 2,
	Mythic       = 3,
	Epic         = 4,
	Special      = 5,
	Common       = 6,
}

-- Порядок мутаций (лучшая = меньший индекс)
local MUTATION_ORDER = {
	Divine   = 1,
	Neon     = 2,
	Blood    = 3,
	Rainbow  = 4,
	Ruby     = 5,
	Diamond  = 6,
	Golden   = 7,
	Normal   = 8,
}

-- Цвета редкостей
local RARITY_COLORS = {
	OG        = Color3.fromRGB(255, 215,   0),
	Legendary = Color3.fromRGB(255, 140,   0),
	Mythic    = Color3.fromRGB(180,   0, 255),
	Epic      = Color3.fromRGB( 80, 100, 255),
	Special   = Color3.fromRGB(  0, 220, 180),
	Common    = Color3.fromRGB(160, 160, 160),
}

-- Цвета мутаций
local MUTATION_COLORS = {
	Divine   = Color3.fromRGB(255, 240, 100),
	Neon     = Color3.fromRGB( 80, 255, 200),
	Blood    = Color3.fromRGB(200,   0,  40),
	Rainbow  = Color3.fromRGB(255, 120, 200),
	Ruby     = Color3.fromRGB(220,  50,  50),
	Diamond  = Color3.fromRGB(130, 220, 255),
	Golden   = Color3.fromRGB(255, 200,  60),
	Normal   = Color3.fromRGB(200, 200, 200),
}

-- Дефолтные цвета, если редкость/мутация не распознана
local DEFAULT_COLOR  = Color3.fromRGB(200, 200, 200)

-- ──────────────────────────────────────────────────────────────────
-- СОСТОЯНИЕ ФИЛЬТРОВ
-- ──────────────────────────────────────────────────────────────────

local filters = {
	rarities  = {Common=true, Epic=true, Mythic=true, Legendary=true, OG=true, Special=true},
	mutations = {Normal=true, Golden=true, Diamond=true, Ruby=true, Rainbow=true, Blood=true, Neon=true, Divine=true},
}

-- ──────────────────────────────────────────────────────────────────
-- ХРАНИЛИЩЕ ПЕТОВ
-- petRegistry[instance] = { instance, name, rarity, mutation, timer, earnings, imageId }
-- ──────────────────────────────────────────────────────────────────

local petRegistry = {}   -- ключ = Instance пета
local listDirty   = true -- флаг: нужна перерисовка списка

-- ──────────────────────────────────────────────────────────────────
-- ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
-- ──────────────────────────────────────────────────────────────────

--- Безопасно читает текст из TextLabel
local function safeText(pet, labelName)
	local ok, val = pcall(function()
		return pet:FindFirstChild("InfoGUI")
			and pet.InfoGUI:FindFirstChild("TextLabels")
			and pet.InfoGUI.TextLabels:FindFirstChild(labelName)
			and pet.InfoGUI.TextLabels[labelName].Text
			or ""
	end)
	return ok and val or ""
end

--- Безопасно читает Image-ссылку пета
local function safeImage(pet)
	local ok, val = pcall(function()
		return pet:FindFirstChild("Open This")
			and pet["Open This"]:FindFirstChild("Paste the link to the image in here")
			and pet["Open This"]["Paste the link to the image in here"].Value
			or ""
	end)
	return ok and val or ""
end

--- Возвращает нормализованное название редкости (для сравнения с ключами)
local function normalizeRarity(raw)
	if not raw or raw == "" then return "Common" end
	local s = raw:gsub("^%s+", ""):gsub("%s+$", "")
	-- Первая буква большая, остальные маленькие
	return s:sub(1,1):upper() .. s:sub(2):lower()
end

local function normalizeMutation(raw)
	if not raw or raw == "" then return "Normal" end
	local s = raw:gsub("^%s+", ""):gsub("%s+$", "")
	return s:sub(1,1):upper() .. s:sub(2):lower()
end

--- Собирает данные о пете из Instance
local function collectPetData(petInstance)
	local name     = safeText(petInstance, "Name")
	local rarity   = normalizeRarity(safeText(petInstance, "Rarity"))
	local mutation = normalizeMutation(safeText(petInstance, "Mutation"))
	local timer    = safeText(petInstance, "Timer")
	local earnings = safeText(petInstance, "Earnings")
	local imageId  = safeImage(petInstance)
	return {
		instance = petInstance,
		name     = name,
		rarity   = rarity,
		mutation = mutation,
		timer    = timer,
		earnings = earnings,
		imageId  = imageId,
	}
end

-- ──────────────────────────────────────────────────────────────────
-- СКАНИРОВАНИЕ СПАВНЕРОВ
-- ──────────────────────────────────────────────────────────────────

local spawnerConnections = {} -- хранит соединения ChildAdded/ChildRemoved

--- Регистрирует одного пета
local function registerPet(petInstance)
	if petRegistry[petInstance] then return end
	petRegistry[petInstance] = collectPetData(petInstance)
	listDirty = true
end

--- Удаляет пета из реестра
local function unregisterPet(petInstance)
	if petRegistry[petInstance] then
		petRegistry[petInstance] = nil
		listDirty = true
	end
end

--- Подключает слежение за одной папкой-спавнером
local function watchFolder(folder)
	-- Регистрируем уже существующих петов
	for _, child in ipairs(folder:GetChildren()) do
		registerPet(child)
	end
	-- Слушаем новых
	local addConn = folder.ChildAdded:Connect(function(child)
		registerPet(child)
	end)
	local remConn = folder.ChildRemoved:Connect(function(child)
		unregisterPet(child)
	end)
	table.insert(spawnerConnections, addConn)
	table.insert(spawnerConnections, remConn)
end

--- Инициализирует слежение за всеми папками
local function initSpawnerWatchers()
	local itemSpawners = workspace:FindFirstChild("ItemSpawners")
	if not itemSpawners then
		warn("[PetMonitor] workspace.ItemSpawners не найден!")
		return
	end
	for _, folderName in ipairs(SPAWNER_FOLDERS) do
		local folder = itemSpawners:FindFirstChild(folderName)
		if folder then
			watchFolder(folder)
		end
	end
	-- На случай если папки появляются позже
	itemSpawners.ChildAdded:Connect(function(newFolder)
		task.wait(0.1)
		watchFolder(newFolder)
	end)
end

-- ──────────────────────────────────────────────────────────────────
-- STEAL-ЛОГИКА
-- ──────────────────────────────────────────────────────────────────

local isStealBusy = false

local function stealPet(petData)
	if isStealBusy then return end
	isStealBusy = true

	local petInstance = petData.instance
	if not petInstance or not petInstance.Parent then
		isStealBusy = false
		return
	end

	-- Обновляем персонажа (мог переспавниться)
	character = player.Character
	if not character then
		isStealBusy = false
		return
	end

	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		isStealBusy = false
		return
	end

	-- 1. Телепортируем к Head пета
	local head = petInstance:FindFirstChild("Head")
	if head then
		hrp.CFrame = head.CFrame * CFrame.new(0, 0, -3)
	end

	task.wait(0.3)

	-- 2. Активируем ProximityPrompt
	if head then
		local prompt = head:FindFirstChildWhichIsA("ProximityPrompt")
		if prompt then
			-- Используем FireProximityPrompt для активации без нажатия E
			local ok = pcall(function()
				game:GetService("VirtualInputManager"):SendKeyEvent(true, Enum.KeyCode.E, false, game)
			end)
			if not ok then
				-- Fallback: ручная активация через API
				pcall(function() prompt:InputHoldBegin() end)
				task.wait(prompt.HoldDuration + 0.05)
				pcall(function() prompt:InputHoldEnd() end)
			end
		end
	end

	task.wait(0.4)

	-- 3. Телепортируем в SafeZone
	local safeZone = workspace:FindFirstChild("SafeZone")
	if safeZone then
		character = player.Character
		hrp = character and character:FindFirstChild("HumanoidRootPart")
		if hrp then
			if safeZone:IsA("BasePart") then
				hrp.CFrame = safeZone.CFrame + Vector3.new(0, 3, 0)
			elseif safeZone:IsA("Model") and safeZone.PrimaryPart then
				hrp.CFrame = safeZone.PrimaryPart.CFrame + Vector3.new(0, 3, 0)
			else
				-- Берём позицию первого BasePart внутри SafeZone
				for _, part in ipairs(safeZone:GetDescendants()) do
					if part:IsA("BasePart") then
						hrp.CFrame = part.CFrame + Vector3.new(0, 3, 0)
						break
					end
				end
			end
		end
	end

	task.wait(0.5)
	isStealBusy = false
end

-- ──────────────────────────────────────────────────────────────────
-- ПОСТРОЕНИЕ GUI
-- ──────────────────────────────────────────────────────────────────

-- Очищаем старый GUI если был
if playerGui:FindFirstChild("PetMonitorGui") then
	playerGui.PetMonitorGui:Destroy()
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name            = "PetMonitorGui"
screenGui.ResetOnSpawn    = false
screenGui.ZIndexBehavior  = Enum.ZIndexBehavior.Sibling
screenGui.IgnoreGuiInset  = true
screenGui.Parent          = playerGui

-- ── MAIN FRAME ─────────────────────────────────────────────────────

local mainFrame = Instance.new("Frame")
mainFrame.Name            = "MainFrame"
mainFrame.Size            = UDim2.new(0, 520, 0, 620)
mainFrame.Position        = UDim2.new(0.5, -260, 0.5, -310)
mainFrame.BackgroundColor3 = Color3.fromRGB(12, 14, 22)
mainFrame.BorderSizePixel = 0
mainFrame.ClipsDescendants = true
mainFrame.Parent          = screenGui

-- Закруглённые углы
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 14)
corner.Parent = mainFrame

-- Обводка
local stroke = Instance.new("UIStroke")
stroke.Color     = Color3.fromRGB(60, 70, 120)
stroke.Thickness = 1.5
stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
stroke.Parent    = mainFrame

-- Градиентный фон шапки
local headerFrame = Instance.new("Frame")
headerFrame.Name              = "Header"
headerFrame.Size              = UDim2.new(1, 0, 0, 54)
headerFrame.Position          = UDim2.new(0, 0, 0, 0)
headerFrame.BackgroundColor3  = Color3.fromRGB(18, 22, 40)
headerFrame.BorderSizePixel   = 0
headerFrame.Parent            = mainFrame

local headerCorner = Instance.new("UICorner")
headerCorner.CornerRadius = UDim.new(0, 14)
headerCorner.Parent = headerFrame

-- Нижний прямой угол у шапки (перекрытие)
local headerCoverBottom = Instance.new("Frame")
headerCoverBottom.Size             = UDim2.new(1, 0, 0, 14)
headerCoverBottom.Position         = UDim2.new(0, 0, 1, -14)
headerCoverBottom.BackgroundColor3 = Color3.fromRGB(18, 22, 40)
headerCoverBottom.BorderSizePixel  = 0
headerCoverBottom.Parent           = headerFrame

local headerGradient = Instance.new("UIGradient")
headerGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(30, 40, 90)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(18, 22, 40)),
})
headerGradient.Rotation = 90
headerGradient.Parent   = headerFrame

-- Заголовок
local titleLabel = Instance.new("TextLabel")
titleLabel.Name              = "Title"
titleLabel.Size              = UDim2.new(1, -110, 1, 0)
titleLabel.Position          = UDim2.new(0, 14, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text              = "🐾  PET MONITOR"
titleLabel.TextColor3        = Color3.fromRGB(200, 210, 255)
titleLabel.Font              = Enum.Font.GothamBold
titleLabel.TextSize          = 18
titleLabel.TextXAlignment    = Enum.TextXAlignment.Left
titleLabel.Parent            = headerFrame

-- Счётчик петов
local petCountLabel = Instance.new("TextLabel")
petCountLabel.Name              = "PetCount"
petCountLabel.Size              = UDim2.new(0, 80, 0, 20)
petCountLabel.Position          = UDim2.new(0, 14, 0, 32)
petCountLabel.BackgroundTransparency = 1
petCountLabel.Text              = "0 pets"
petCountLabel.TextColor3        = Color3.fromRGB(120, 130, 180)
petCountLabel.Font              = Enum.Font.Gotham
petCountLabel.TextSize          = 12
petCountLabel.TextXAlignment    = Enum.TextXAlignment.Left
petCountLabel.Parent            = headerFrame

-- Кнопка закрытия
local closeBtn = Instance.new("TextButton")
closeBtn.Name              = "CloseBtn"
closeBtn.Size              = UDim2.new(0, 32, 0, 32)
closeBtn.Position          = UDim2.new(1, -44, 0.5, -16)
closeBtn.BackgroundColor3  = Color3.fromRGB(200, 50, 60)
closeBtn.Text              = "✕"
closeBtn.TextColor3        = Color3.fromRGB(255, 255, 255)
closeBtn.Font              = Enum.Font.GothamBold
closeBtn.TextSize          = 16
closeBtn.BorderSizePixel   = 0
closeBtn.Parent            = headerFrame

local closeBtnCorner = Instance.new("UICorner")
closeBtnCorner.CornerRadius = UDim.new(0, 8)
closeBtnCorner.Parent = closeBtn

-- Кнопка свернуть/развернуть
local minimizeBtn = Instance.new("TextButton")
minimizeBtn.Name              = "MinimizeBtn"
minimizeBtn.Size              = UDim2.new(0, 32, 0, 32)
minimizeBtn.Position          = UDim2.new(1, -82, 0.5, -16)
minimizeBtn.BackgroundColor3  = Color3.fromRGB(50, 130, 200)
minimizeBtn.Text              = "—"
minimizeBtn.TextColor3        = Color3.fromRGB(255, 255, 255)
minimizeBtn.Font              = Enum.Font.GothamBold
minimizeBtn.TextSize          = 18
minimizeBtn.BorderSizePixel   = 0
minimizeBtn.Parent            = headerFrame

local minimizeBtnCorner = Instance.new("UICorner")
minimizeBtnCorner.CornerRadius = UDim.new(0, 8)
minimizeBtnCorner.Parent = minimizeBtn

-- ── ФИЛЬТРЫ ────────────────────────────────────────────────────────

local filtersFrame = Instance.new("Frame")
filtersFrame.Name              = "FiltersFrame"
filtersFrame.Size              = UDim2.new(1, -16, 0, 130)
filtersFrame.Position          = UDim2.new(0, 8, 0, 60)
filtersFrame.BackgroundColor3  = Color3.fromRGB(16, 20, 34)
filtersFrame.BorderSizePixel   = 0
filtersFrame.Parent            = mainFrame

local filtersCorner = Instance.new("UICorner")
filtersCorner.CornerRadius = UDim.new(0, 10)
filtersCorner.Parent = filtersFrame

local filtersStroke = Instance.new("UIStroke")
filtersStroke.Color     = Color3.fromRGB(40, 50, 90)
filtersStroke.Thickness = 1
filtersStroke.Parent    = filtersFrame

-- Заголовок фильтров
local filterTitle = Instance.new("TextLabel")
filterTitle.Size              = UDim2.new(1, -10, 0, 22)
filterTitle.Position          = UDim2.new(0, 10, 0, 4)
filterTitle.BackgroundTransparency = 1
filterTitle.Text              = "FILTERS"
filterTitle.TextColor3        = Color3.fromRGB(100, 110, 180)
filterTitle.Font              = Enum.Font.GothamBold
filterTitle.TextSize          = 11
filterTitle.TextXAlignment    = Enum.TextXAlignment.Left
filterTitle.Parent            = filtersFrame

-- ── Редкости чекбоксы ──────────────────────────────────────────────

local rarityRow = Instance.new("Frame")
rarityRow.Name              = "RarityRow"
rarityRow.Size              = UDim2.new(1, -10, 0, 28)
rarityRow.Position          = UDim2.new(0, 5, 0, 28)
rarityRow.BackgroundTransparency = 1
rarityRow.Parent            = filtersFrame

local rarityList = Instance.new("UIListLayout")
rarityList.FillDirection  = Enum.FillDirection.Horizontal
rarityList.Padding        = UDim.new(0, 4)
rarityList.VerticalAlignment = Enum.VerticalAlignment.Center
rarityList.Parent = rarityRow

local RARITY_NAMES = {"Common","Epic","Mythic","Legendary","OG","Special"}

local rarityCheckboxes = {} -- rarityCheckboxes[name] = button

local function makeRarityCheckbox(rarityName)
	local col = RARITY_COLORS[rarityName] or DEFAULT_COLOR

	local btn = Instance.new("TextButton")
	btn.Name              = rarityName
	btn.Size              = UDim2.new(0, 72, 0, 24)
	btn.BackgroundColor3  = col
	btn.BackgroundTransparency = filters.rarities[rarityName] and 0.3 or 0.75
	btn.Text              = rarityName
	btn.TextColor3        = Color3.fromRGB(255, 255, 255)
	btn.Font              = Enum.Font.GothamBold
	btn.TextSize          = 11
	btn.BorderSizePixel   = 0
	btn.Parent            = rarityRow

	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 6)
	c.Parent = btn

	local st = Instance.new("UIStroke")
	st.Color     = col
	st.Thickness = filters.rarities[rarityName] and 1.5 or 0
	st.Parent    = btn

	btn.MouseButton1Click:Connect(function()
		filters.rarities[rarityName] = not filters.rarities[rarityName]
		btn.BackgroundTransparency = filters.rarities[rarityName] and 0.3 or 0.75
		st.Thickness = filters.rarities[rarityName] and 1.5 or 0
		listDirty = true
	end)

	rarityCheckboxes[rarityName] = btn
end

for _, rn in ipairs(RARITY_NAMES) do
	makeRarityCheckbox(rn)
end

-- ── Мутации чекбоксы ──────────────────────────────────────────────

local MUTATION_NAMES = {"Normal","Golden","Diamond","Ruby","Rainbow","Blood","Neon","Divine"}

local mutRow1 = Instance.new("Frame")
mutRow1.Name              = "MutRow1"
mutRow1.Size              = UDim2.new(1, -10, 0, 26)
mutRow1.Position          = UDim2.new(0, 5, 0, 62)
mutRow1.BackgroundTransparency = 1
mutRow1.Parent            = filtersFrame

local mutList1 = Instance.new("UIListLayout")
mutList1.FillDirection  = Enum.FillDirection.Horizontal
mutList1.Padding        = UDim.new(0, 4)
mutList1.VerticalAlignment = Enum.VerticalAlignment.Center
mutList1.Parent = mutRow1

local mutRow2 = Instance.new("Frame")
mutRow2.Name              = "MutRow2"
mutRow2.Size              = UDim2.new(1, -10, 0, 26)
mutRow2.Position          = UDim2.new(0, 5, 0, 94)
mutRow2.BackgroundTransparency = 1
mutRow2.Parent            = filtersFrame

local mutList2 = Instance.new("UIListLayout")
mutList2.FillDirection  = Enum.FillDirection.Horizontal
mutList2.Padding        = UDim.new(0, 4)
mutList2.VerticalAlignment = Enum.VerticalAlignment.Center
mutList2.Parent = mutRow2

local mutationCheckboxes = {}

local function makeMutationCheckbox(mutName, parentRow)
	local col = MUTATION_COLORS[mutName] or DEFAULT_COLOR

	local btn = Instance.new("TextButton")
	btn.Name              = mutName
	btn.Size              = UDim2.new(0, 60, 0, 22)
	btn.BackgroundColor3  = col
	btn.BackgroundTransparency = filters.mutations[mutName] and 0.3 or 0.75
	btn.Text              = mutName
	btn.TextColor3        = Color3.fromRGB(255, 255, 255)
	btn.Font              = Enum.Font.GothamBold
	btn.TextSize          = 10
	btn.BorderSizePixel   = 0
	btn.Parent            = parentRow

	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 6)
	c.Parent = btn

	local st = Instance.new("UIStroke")
	st.Color     = col
	st.Thickness = filters.mutations[mutName] and 1.2 or 0
	st.Parent    = btn

	btn.MouseButton1Click:Connect(function()
		filters.mutations[mutName] = not filters.mutations[mutName]
		btn.BackgroundTransparency = filters.mutations[mutName] and 0.3 or 0.75
		st.Thickness = filters.mutations[mutName] and 1.2 or 0
		listDirty = true
	end)

	mutationCheckboxes[mutName] = btn
end

for i, mn in ipairs(MUTATION_NAMES) do
	if i <= 4 then
		makeMutationCheckbox(mn, mutRow1)
	else
		makeMutationCheckbox(mn, mutRow2)
	end
end

-- ── СПИСОК ПЕТОВ (скроллируемый) ───────────────────────────────────

local listOuter = Instance.new("Frame")
listOuter.Name              = "ListOuter"
listOuter.Size              = UDim2.new(1, -16, 1, -202)
listOuter.Position          = UDim2.new(0, 8, 0, 198)
listOuter.BackgroundColor3  = Color3.fromRGB(10, 12, 20)
listOuter.BorderSizePixel   = 0
listOuter.ClipsDescendants  = true
listOuter.Parent            = mainFrame

local listOuterCorner = Instance.new("UICorner")
listOuterCorner.CornerRadius = UDim.new(0, 10)
listOuterCorner.Parent = listOuter

local listOuterStroke = Instance.new("UIStroke")
listOuterStroke.Color     = Color3.fromRGB(40, 50, 90)
listOuterStroke.Thickness = 1
listOuterStroke.Parent    = listOuter

local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Name              = "ScrollFrame"
scrollFrame.Size              = UDim2.new(1, 0, 1, 0)
scrollFrame.Position          = UDim2.new(0, 0, 0, 0)
scrollFrame.BackgroundTransparency = 1
scrollFrame.ScrollBarThickness    = 4
scrollFrame.ScrollBarImageColor3  = Color3.fromRGB(80, 100, 200)
scrollFrame.BorderSizePixel   = 0
scrollFrame.CanvasSize        = UDim2.new(0, 0, 0, 0)
scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
scrollFrame.Parent            = listOuter

local listLayout = Instance.new("UIListLayout")
listLayout.Padding          = UDim.new(0, 6)
listLayout.SortOrder        = Enum.SortOrder.LayoutOrder
listLayout.FillDirection    = Enum.FillDirection.Vertical
listLayout.Parent           = scrollFrame

local listPadding = Instance.new("UIPadding")
listPadding.PaddingTop    = UDim.new(0, 6)
listPadding.PaddingBottom = UDim.new(0, 6)
listPadding.PaddingLeft   = UDim.new(0, 6)
listPadding.PaddingRight  = UDim.new(0, 6)
listPadding.Parent        = scrollFrame

-- Пустой текст если ничего нет
local emptyLabel = Instance.new("TextLabel")
emptyLabel.Name              = "EmptyLabel"
emptyLabel.Size              = UDim2.new(1, 0, 0, 60)
emptyLabel.BackgroundTransparency = 1
emptyLabel.Text              = "No pets match your filters"
emptyLabel.TextColor3        = Color3.fromRGB(80, 90, 130)
emptyLabel.Font              = Enum.Font.Gotham
emptyLabel.TextSize          = 14
emptyLabel.Visible           = false
emptyLabel.Parent            = scrollFrame

-- ──────────────────────────────────────────────────────────────────
-- КАРТОЧКИ ПЕТОВ
-- petCards[instance] = { frame, timerLabel, stealBtn }
-- ──────────────────────────────────────────────────────────────────

local petCards = {}  -- хранит UI-карточки (ключ = Instance)

--- Создаёт UI-карточку для одного пета
local function createPetCard(petData)
	local inst     = petData.instance
	local rarCol   = RARITY_COLORS[petData.rarity]   or DEFAULT_COLOR
	local mutCol   = MUTATION_COLORS[petData.mutation] or DEFAULT_COLOR

	-- Основная рамка карточки
	local card = Instance.new("Frame")
	card.Name              = "PetCard_" .. inst.Name
	card.Size              = UDim2.new(1, -2, 0, 72)
	card.BackgroundColor3  = Color3.fromRGB(18, 22, 38)
	card.BorderSizePixel   = 0

	local cardCorner = Instance.new("UICorner")
	cardCorner.CornerRadius = UDim.new(0, 10)
	cardCorner.Parent = card

	local cardStroke = Instance.new("UIStroke")
	cardStroke.Color     = rarCol
	cardStroke.Thickness = 1
	cardStroke.Transparency = 0.5
	cardStroke.Parent    = card

	-- Левая цветная полоска (по редкости)
	local accent = Instance.new("Frame")
	accent.Size              = UDim2.new(0, 4, 1, -12)
	accent.Position          = UDim2.new(0, 6, 0, 6)
	accent.BackgroundColor3  = rarCol
	accent.BorderSizePixel   = 0
	accent.Parent            = card

	local accentCorner = Instance.new("UICorner")
	accentCorner.CornerRadius = UDim.new(0, 2)
	accentCorner.Parent = accent

	-- Картинка пета (если есть)
	local imgLabel = Instance.new("ImageLabel")
	imgLabel.Size              = UDim2.new(0, 54, 0, 54)
	imgLabel.Position          = UDim2.new(0, 16, 0.5, -27)
	imgLabel.BackgroundColor3  = Color3.fromRGB(12, 16, 30)
	imgLabel.BorderSizePixel   = 0
	imgLabel.Image             = petData.imageId ~= "" and petData.imageId or "rbxassetid://0"
	imgLabel.ScaleType         = Enum.ScaleType.Fit
	imgLabel.Parent            = card

	local imgCorner = Instance.new("UICorner")
	imgCorner.CornerRadius = UDim.new(0, 8)
	imgCorner.Parent = imgLabel

	-- Если нет картинки — иконка вопроса
	if petData.imageId == "" then
		local noImg = Instance.new("TextLabel")
		noImg.Size              = UDim2.new(1, 0, 1, 0)
		noImg.BackgroundTransparency = 1
		noImg.Text              = "🐾"
		noImg.Font              = Enum.Font.Gotham
		noImg.TextSize          = 26
		noImg.Parent            = imgLabel
	end

	-- Имя пета
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name              = "Name"
	nameLabel.Size              = UDim2.new(0, 180, 0, 18)
	nameLabel.Position          = UDim2.new(0, 78, 0, 8)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text              = petData.name ~= "" and petData.name or inst.Name
	nameLabel.TextColor3        = Color3.fromRGB(230, 235, 255)
	nameLabel.Font              = Enum.Font.GothamBold
	nameLabel.TextSize          = 14
	nameLabel.TextXAlignment    = Enum.TextXAlignment.Left
	nameLabel.TextTruncate      = Enum.TextTruncate.AtEnd
	nameLabel.Parent            = card

	-- Редкость
	local rarityLabel = Instance.new("TextLabel")
	rarityLabel.Name              = "Rarity"
	rarityLabel.Size              = UDim2.new(0, 90, 0, 16)
	rarityLabel.Position          = UDim2.new(0, 78, 0, 28)
	rarityLabel.BackgroundColor3  = rarCol
	rarityLabel.BackgroundTransparency = 0.75
	rarityLabel.Text              = petData.rarity
	rarityLabel.TextColor3        = rarCol
	rarityLabel.Font              = Enum.Font.GothamBold
	rarityLabel.TextSize          = 11
	rarityLabel.TextXAlignment    = Enum.TextXAlignment.Center
	rarityLabel.BorderSizePixel   = 0
	rarityLabel.Parent            = card

	local rarCorner = Instance.new("UICorner")
	rarCorner.CornerRadius = UDim.new(0, 4)
	rarCorner.Parent = rarityLabel

	-- Мутация
	local mutLabel = Instance.new("TextLabel")
	mutLabel.Name              = "Mutation"
	mutLabel.Size              = UDim2.new(0, 80, 0, 16)
	mutLabel.Position          = UDim2.new(0, 174, 0, 28)
	mutLabel.BackgroundColor3  = mutCol
	mutLabel.BackgroundTransparency = 0.75
	mutLabel.Text              = petData.mutation
	mutLabel.TextColor3        = mutCol
	mutLabel.Font              = Enum.Font.GothamBold
	mutLabel.TextSize          = 11
	mutLabel.TextXAlignment    = Enum.TextXAlignment.Center
	mutLabel.BorderSizePixel   = 0
	mutLabel.Parent            = card

	local mutCorner = Instance.new("UICorner")
	mutCorner.CornerRadius = UDim.new(0, 4)
	mutCorner.Parent = mutLabel

	-- Таймер
	local timerLabel = Instance.new("TextLabel")
	timerLabel.Name              = "Timer"
	timerLabel.Size              = UDim2.new(0, 100, 0, 16)
	timerLabel.Position          = UDim2.new(0, 78, 0, 48)
	timerLabel.BackgroundTransparency = 1
	timerLabel.Text              = "⏱ " .. petData.timer
	timerLabel.TextColor3        = Color3.fromRGB(180, 200, 100)
	timerLabel.Font              = Enum.Font.Gotham
	timerLabel.TextSize          = 12
	timerLabel.TextXAlignment    = Enum.TextXAlignment.Left
	timerLabel.Parent            = card

	-- Earnings
	local earningsLabel = Instance.new("TextLabel")
	earningsLabel.Name              = "Earnings"
	earningsLabel.Size              = UDim2.new(0, 120, 0, 16)
	earningsLabel.Position          = UDim2.new(0, 190, 0, 48)
	earningsLabel.BackgroundTransparency = 1
	earningsLabel.Text              = "💰 " .. petData.earnings
	earningsLabel.TextColor3        = Color3.fromRGB(100, 220, 120)
	earningsLabel.Font              = Enum.Font.Gotham
	earningsLabel.TextSize          = 12
	earningsLabel.TextXAlignment    = Enum.TextXAlignment.Left
	earningsLabel.Parent            = card

	-- Кнопка Steal
	local stealBtn = Instance.new("TextButton")
	stealBtn.Name              = "StealBtn"
	stealBtn.Size              = UDim2.new(0, 70, 0, 40)
	stealBtn.Position          = UDim2.new(1, -82, 0.5, -20)
	stealBtn.BackgroundColor3  = Color3.fromRGB(220, 60, 80)
	stealBtn.Text              = "STEAL"
	stealBtn.TextColor3        = Color3.fromRGB(255, 255, 255)
	stealBtn.Font              = Enum.Font.GothamBold
	stealBtn.TextSize          = 13
	stealBtn.BorderSizePixel   = 0
	stealBtn.Parent            = card

	local stealCorner = Instance.new("UICorner")
	stealCorner.CornerRadius = UDim.new(0, 8)
	stealCorner.Parent = stealBtn

	local stealGrad = Instance.new("UIGradient")
	stealGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 100)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 30, 60)),
	})
	stealGrad.Rotation = 90
	stealGrad.Parent   = stealBtn

	stealBtn.MouseButton1Click:Connect(function()
		task.spawn(stealPet, petData)
	end)

	-- Hover-эффект на кнопку Steal
	stealBtn.MouseEnter:Connect(function()
		TweenService:Create(stealBtn, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(255, 90, 110)}):Play()
	end)
	stealBtn.MouseLeave:Connect(function()
		TweenService:Create(stealBtn, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(220, 60, 80)}):Play()
	end)

	return {
		frame       = card,
		timerLabel  = timerLabel,
		earningsLabel = earningsLabel,
		stealBtn    = stealBtn,
	}
end

-- ──────────────────────────────────────────────────────────────────
-- СОРТИРОВКА ПЕТОВ
-- ──────────────────────────────────────────────────────────────────

--- Сравниватель: редкость → мутация → таймер
local function comparePets(a, b)
	local rA = RARITY_ORDER[a.rarity]   or 99
	local rB = RARITY_ORDER[b.rarity]   or 99
	if rA ~= rB then return rA < rB end

	local mA = MUTATION_ORDER[a.mutation] or 99
	local mB = MUTATION_ORDER[b.mutation] or 99
	if mA ~= mB then return mA < mB end

	-- Пытаемся сравнить таймер как число
	local tA = tonumber(a.timer) or 9999
	local tB = tonumber(b.timer) or 9999
	return tA < tB
end

-- ──────────────────────────────────────────────────────────────────
-- ПЕРЕРИСОВКА СПИСКА
-- ──────────────────────────────────────────────────────────────────

--- Проверяет, проходит ли пет текущие фильтры
local function petPassesFilters(petData)
	if not filters.rarities[petData.rarity] then return false end
	if not filters.mutations[petData.mutation] then return false end
	return true
end

--- Полная перерисовка списка (вызывается когда listDirty = true)
local function rebuildList()
	-- Удаляем старые карточки из scrollFrame
	for _, child in ipairs(scrollFrame:GetChildren()) do
		if child:IsA("Frame") and child.Name:sub(1, 7) == "PetCard" then
			child:Destroy()
		end
	end
	petCards = {}

	-- Собираем список петов, проходящих фильтр
	local filtered = {}
	for _, petData in pairs(petRegistry) do
		-- Обновляем данные из Instance
		petData.name     = safeText(petData.instance, "Name")
		petData.rarity   = normalizeRarity(safeText(petData.instance, "Rarity"))
		petData.mutation = normalizeMutation(safeText(petData.instance, "Mutation"))
		petData.timer    = safeText(petData.instance, "Timer")
		petData.earnings = safeText(petData.instance, "Earnings")

		if petPassesFilters(petData) then
			table.insert(filtered, petData)
		end
	end

	-- Сортируем
	table.sort(filtered, comparePets)

	emptyLabel.Visible = (#filtered == 0)
	petCountLabel.Text = #filtered .. " pet" .. (#filtered ~= 1 and "s" or "")

	-- Создаём карточки
	for order, petData in ipairs(filtered) do
		local cardData = createPetCard(petData)
		cardData.frame.LayoutOrder = order
		cardData.frame.Parent      = scrollFrame
		petCards[petData.instance] = cardData
	end
end

-- ──────────────────────────────────────────────────────────────────
-- ПЕРЕТАСКИВАНИЕ (Draggable)
-- ──────────────────────────────────────────────────────────────────

do
	local dragging      = false
	local dragStart     = Vector2.new()
	local frameStartPos = UDim2.new()

	headerFrame.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dragging      = true
			dragStart     = input.Position
			frameStartPos = mainFrame.Position
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch) then
			local delta = input.Position - dragStart
			mainFrame.Position = UDim2.new(
				frameStartPos.X.Scale,
				frameStartPos.X.Offset + delta.X,
				frameStartPos.Y.Scale,
				frameStartPos.Y.Offset + delta.Y
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

-- ──────────────────────────────────────────────────────────────────
-- СВЕРНУТЬ / РАЗВЕРНУТЬ
-- ──────────────────────────────────────────────────────────────────

local isMinimized = false

minimizeBtn.MouseButton1Click:Connect(function()
	isMinimized = not isMinimized
	if isMinimized then
		-- Скрываем всё кроме шапки
		TweenService:Create(mainFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
			{Size = UDim2.new(0, 520, 0, 54)}):Play()
		minimizeBtn.Text = "▲"
	else
		TweenService:Create(mainFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
			{Size = UDim2.new(0, 520, 0, 620)}):Play()
		minimizeBtn.Text = "—"
	end
end)

-- ── ЗАКРЫТЬ ────────────────────────────────────────────────────────

closeBtn.MouseButton1Click:Connect(function()
	TweenService:Create(mainFrame, TweenInfo.new(0.2), {Size = UDim2.new(0, 0, 0, 0), BackgroundTransparency = 1}):Play()
	task.delay(0.25, function() screenGui:Destroy() end)
end)

-- ──────────────────────────────────────────────────────────────────
-- ГЛАВНЫЙ ЦИКЛ ОБНОВЛЕНИЯ (RunService)
-- ──────────────────────────────────────────────────────────────────

local timeSinceTimerUpdate = 0
local timeSinceRebuild     = 0
local REBUILD_INTERVAL     = 0.5  -- секунд между полными перестройками
local TIMER_UPDATE_INTERVAL = 1.0 -- секунд между обновлением таймеров

RunService.Heartbeat:Connect(function(dt)
	timeSinceTimerUpdate = timeSinceTimerUpdate + dt
	timeSinceRebuild     = timeSinceRebuild     + dt

	-- Обновляем только таймеры и earnings без перестройки списка
	if timeSinceTimerUpdate >= TIMER_UPDATE_INTERVAL then
		timeSinceTimerUpdate = 0
		for inst, cardData in pairs(petCards) do
			if inst and inst.Parent then
				local newTimer    = safeText(inst, "Timer")
				local newEarnings = safeText(inst, "Earnings")
				cardData.timerLabel.Text    = "⏱ " .. newTimer
				cardData.earningsLabel.Text = "💰 " .. newEarnings
				-- Обновляем в реестре
				if petRegistry[inst] then
					petRegistry[inst].timer    = newTimer
					petRegistry[inst].earnings = newEarnings
				end
			end
		end
	end

	-- Полная перестройка только если нужна
	if listDirty and timeSinceRebuild >= REBUILD_INTERVAL then
		timeSinceRebuild = 0
		listDirty        = false
		rebuildList()
	end
end)

-- ──────────────────────────────────────────────────────────────────
-- ЗАПУСК
-- ──────────────────────────────────────────────────────────────────

-- Небольшая анимация появления
mainFrame.Size = UDim2.new(0, 0, 0, 0)
mainFrame.BackgroundTransparency = 1
TweenService:Create(mainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
	Size = UDim2.new(0, 520, 0, 620),
	BackgroundTransparency = 0,
}):Play()

initSpawnerWatchers()

print("[PetMonitor] GUI запущен. Отслеживаем спавнеры:", table.concat(SPAWNER_FOLDERS, ", "))
