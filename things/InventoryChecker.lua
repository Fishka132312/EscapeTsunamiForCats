-- ============================================================
--  PetInventoryViewer  |  LocalScript → StarterGui / ScreenGui
--  Просмотр инвентаря петов любого игрока на сервере
-- ============================================================

local Players      = game:GetService("Players")
local LocalPlayer  = Players.LocalPlayer

-- ─────────────────────────────────────────────────────────────
--  КОНСТАНТЫ
-- ─────────────────────────────────────────────────────────────
local IGNORED_TOOLS = { Bat = true, Slap = true }

local RARITY_ORDER = {
	SpecialItemSpawn = 1, OG = 2, Mythical = 3, Legendary = 4,
	Epic = 5, Rare = 6, Uncommon = 7, Common = 8,
}
local RARITY_COLORS = {
	Common          = Color3.fromRGB(180, 180, 180),
	Uncommon        = Color3.fromRGB(71,  231, 160),
	Rare            = Color3.fromRGB(0,   242, 255),
	Epic            = Color3.fromRGB(255, 71,  255),
	Legendary       = Color3.fromRGB(255, 162, 0),
	Mythical        = Color3.fromRGB(255, 99,  152),
	OG              = Color3.fromRGB(52,  214, 137),
	SpecialItemSpawn= Color3.fromRGB(80,  220, 255),
}
local MUTATION_ORDER = {
	Divine = 1, Neon = 2, Blood = 3, Rainbow = 4,
	Ruby = 5, Diamond = 6, Golden = 7, Normal = 8,
}
local MUTATION_COLORS = {
	Normal  = Color3.fromRGB(200, 200, 200),
	Golden  = Color3.fromRGB(255, 247, 0),
	Diamond = Color3.fromRGB(25,  255, 255),
	Ruby    = Color3.fromRGB(255, 23,  55),
	Rainbow = Color3.fromRGB(0,   255, 170),
	Blood   = Color3.fromRGB(255, 0,   0),
	Neon    = Color3.fromRGB(215, 255, 0),
	Divine  = Color3.fromRGB(255, 232, 36),
}

-- ─────────────────────────────────────────────────────────────
--  ПОСТРОЕНИЕ GUI
-- ─────────────────────────────────────────────────────────────
local function makeTweenProps(size, pos)
	return { Size = size, Position = pos }
end

-- Удалим старый GUI если уже существует (при повторном запуске)
local oldGui = LocalPlayer.PlayerGui:FindFirstChild("PetInventoryViewer")
if oldGui then oldGui:Destroy() end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name             = "PetInventoryViewer"
ScreenGui.ResetOnSpawn     = false
ScreenGui.ZIndexBehavior   = Enum.ZIndexBehavior.Sibling
ScreenGui.IgnoreGuiInset   = true
ScreenGui.Parent           = LocalPlayer.PlayerGui

-- ── Кнопка-триггер (маленькая кнопка «👁 Инвентарь») ──────────
local TriggerBtn = Instance.new("TextButton")
TriggerBtn.Name            = "TriggerBtn"
TriggerBtn.Size            = UDim2.new(0, 160, 0, 38)
TriggerBtn.Position        = UDim2.new(0, 10, 0.5, -19)
TriggerBtn.BackgroundColor3= Color3.fromRGB(20, 20, 30)
TriggerBtn.BorderSizePixel = 0
TriggerBtn.Text            = "👁  Pet Viewer"
TriggerBtn.TextColor3      = Color3.fromRGB(200, 230, 255)
TriggerBtn.TextSize        = 15
TriggerBtn.Font            = Enum.Font.GothamBold
TriggerBtn.ZIndex          = 2
TriggerBtn.Parent          = ScreenGui
Instance.new("UICorner", TriggerBtn).CornerRadius = UDim.new(0, 8)
local TriggerStroke = Instance.new("UIStroke", TriggerBtn)
TriggerStroke.Color     = Color3.fromRGB(80, 160, 255)
TriggerStroke.Thickness = 1.5

-- ── Главное окно ──────────────────────────────────────────────
local MainFrame = Instance.new("Frame")
MainFrame.Name              = "MainFrame"
MainFrame.Size              = UDim2.new(0, 680, 0, 520)
MainFrame.Position          = UDim2.new(0.5, -340, 0.5, -260)
MainFrame.BackgroundColor3  = Color3.fromRGB(10, 12, 22)
MainFrame.BorderSizePixel   = 0
MainFrame.Visible           = false
MainFrame.ZIndex            = 5
MainFrame.Parent            = ScreenGui
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 12)
local MainStroke = Instance.new("UIStroke", MainFrame)
MainStroke.Color     = Color3.fromRGB(60, 100, 200)
MainStroke.Thickness = 2

-- Тень (тёмный Frame позади)
local Shadow = Instance.new("Frame")
Shadow.Size              = UDim2.new(1, 20, 1, 20)
Shadow.Position          = UDim2.new(0, -10, 0, 10)
Shadow.BackgroundColor3  = Color3.fromRGB(0, 0, 0)
Shadow.BackgroundTransparency = 0.55
Shadow.BorderSizePixel   = 0
Shadow.ZIndex            = 4
Shadow.Parent            = MainFrame
Instance.new("UICorner", Shadow).CornerRadius = UDim.new(0, 14)

-- Заголовок
local TitleBar = Instance.new("Frame")
TitleBar.Size             = UDim2.new(1, 0, 0, 44)
TitleBar.BackgroundColor3 = Color3.fromRGB(14, 18, 35)
TitleBar.BorderSizePixel  = 0
TitleBar.ZIndex           = 6
TitleBar.Parent           = MainFrame
Instance.new("UICorner", TitleBar).CornerRadius = UDim.new(0, 12)

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size             = UDim2.new(1, -50, 1, 0)
TitleLabel.Position         = UDim2.new(0, 14, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text             = "🐾  Pet Inventory Viewer"
TitleLabel.TextColor3       = Color3.fromRGB(180, 210, 255)
TitleLabel.TextSize         = 17
TitleLabel.Font             = Enum.Font.GothamBold
TitleLabel.TextXAlignment   = Enum.TextXAlignment.Left
TitleLabel.ZIndex           = 7
TitleLabel.Parent           = TitleBar

-- Кнопка закрыть
local CloseBtn = Instance.new("TextButton")
CloseBtn.Size             = UDim2.new(0, 32, 0, 32)
CloseBtn.Position         = UDim2.new(1, -40, 0, 6)
CloseBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 60)
CloseBtn.Text             = "✕"
CloseBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
CloseBtn.TextSize         = 16
CloseBtn.Font             = Enum.Font.GothamBold
CloseBtn.ZIndex           = 8
CloseBtn.Parent           = TitleBar
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 6)

-- ── Левая панель: список игроков ─────────────────────────────
local LeftPanel = Instance.new("Frame")
LeftPanel.Size              = UDim2.new(0, 170, 1, -50)
LeftPanel.Position          = UDim2.new(0, 8, 0, 50)
LeftPanel.BackgroundColor3  = Color3.fromRGB(14, 18, 35)
LeftPanel.BorderSizePixel   = 0
LeftPanel.ZIndex            = 6
LeftPanel.Parent            = MainFrame
Instance.new("UICorner", LeftPanel).CornerRadius = UDim.new(0, 8)

local PlayersLabel = Instance.new("TextLabel")
PlayersLabel.Size           = UDim2.new(1, 0, 0, 28)
PlayersLabel.BackgroundTransparency = 1
PlayersLabel.Text           = "  Игроки на сервере"
PlayersLabel.TextColor3     = Color3.fromRGB(120, 160, 220)
PlayersLabel.TextSize       = 12
PlayersLabel.Font           = Enum.Font.GothamBold
PlayersLabel.TextXAlignment = Enum.TextXAlignment.Left
PlayersLabel.ZIndex         = 7
PlayersLabel.Parent         = LeftPanel

local PlayerScroll = Instance.new("ScrollingFrame")
PlayerScroll.Size              = UDim2.new(1, -4, 1, -34)
PlayerScroll.Position          = UDim2.new(0, 2, 0, 30)
PlayerScroll.BackgroundTransparency = 1
PlayerScroll.BorderSizePixel   = 0
PlayerScroll.ScrollBarThickness= 3
PlayerScroll.ScrollBarImageColor3 = Color3.fromRGB(80, 130, 220)
PlayerScroll.CanvasSize        = UDim2.new(0, 0, 0, 0)
PlayerScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
PlayerScroll.ZIndex            = 7
PlayerScroll.Parent            = LeftPanel
Instance.new("UIListLayout", PlayerScroll).Padding = UDim.new(0, 3)

-- ── Правая панель: карточки петов ───────────────────────────
local RightPanel = Instance.new("Frame")
RightPanel.Size             = UDim2.new(1, -186, 1, -96)
RightPanel.Position         = UDim2.new(0, 182, 0, 50)
RightPanel.BackgroundTransparency = 1
RightPanel.ZIndex           = 6
RightPanel.Parent           = MainFrame

-- Панель сортировки
local SortBar = Instance.new("Frame")
SortBar.Size              = UDim2.new(1, 0, 0, 34)
SortBar.BackgroundColor3  = Color3.fromRGB(14, 18, 35)
SortBar.BorderSizePixel   = 0
SortBar.ZIndex            = 7
SortBar.Parent            = RightPanel
Instance.new("UICorner", SortBar).CornerRadius = UDim.new(0, 8)

local SortLayout = Instance.new("UIListLayout", SortBar)
SortLayout.FillDirection  = Enum.FillDirection.Horizontal
SortLayout.VerticalAlignment = Enum.VerticalAlignment.Center
SortLayout.Padding        = UDim.new(0, 4)
Instance.new("UIPadding", SortBar).PaddingLeft = UDim.new(0, 6)

local sortLabel = Instance.new("TextLabel")
sortLabel.Size             = UDim2.new(0, 68, 1, 0)
sortLabel.BackgroundTransparency = 1
sortLabel.Text             = "Сортировка:"
sortLabel.TextColor3       = Color3.fromRGB(140, 160, 200)
sortLabel.TextSize         = 12
sortLabel.Font             = Enum.Font.Gotham
sortLabel.ZIndex           = 8
sortLabel.Parent           = SortBar

local SORT_MODES = {"Редкость","Мутация","Название","Количество"}
local sortButtons  = {}
local currentSort  = "Редкость"

local function makeSortBtn(label)
	local btn = Instance.new("TextButton")
	btn.Size              = UDim2.new(0, 78, 0, 24)
	btn.BackgroundColor3  = Color3.fromRGB(25, 30, 52)
	btn.Text              = label
	btn.TextColor3        = Color3.fromRGB(160, 190, 240)
	btn.TextSize          = 12
	btn.Font              = Enum.Font.GothamBold
	btn.ZIndex            = 8
	btn.Parent            = SortBar
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 5)
	return btn
end

for _, mode in ipairs(SORT_MODES) do
	sortButtons[mode] = makeSortBtn(mode)
end

-- Статус / кол-во петов
local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size             = UDim2.new(1, 0, 0, 22)
StatusLabel.Position         = UDim2.new(0, 0, 0, 38)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text             = "Выберите игрока слева"
StatusLabel.TextColor3       = Color3.fromRGB(120, 140, 180)
StatusLabel.TextSize         = 12
StatusLabel.Font             = Enum.Font.Gotham
StatusLabel.TextXAlignment   = Enum.TextXAlignment.Left
StatusLabel.ZIndex           = 7
StatusLabel.Parent           = RightPanel

-- Скролл для карточек
local CardScroll = Instance.new("ScrollingFrame")
CardScroll.Size              = UDim2.new(1, 0, 1, -64)
CardScroll.Position          = UDim2.new(0, 0, 0, 62)
CardScroll.BackgroundTransparency = 1
CardScroll.BorderSizePixel   = 0
CardScroll.ScrollBarThickness= 4
CardScroll.ScrollBarImageColor3 = Color3.fromRGB(80, 130, 220)
CardScroll.CanvasSize        = UDim2.new(0, 0, 0, 0)
CardScroll.ZIndex            = 7
CardScroll.Parent            = RightPanel

local CardGrid = Instance.new("UIGridLayout", CardScroll)
CardGrid.CellSize     = UDim2.new(0, 142, 0, 190)
CardGrid.CellPadding  = UDim2.new(0, 8, 0, 8)
CardGrid.SortOrder    = Enum.SortOrder.LayoutOrder
Instance.new("UIPadding", CardScroll).PaddingTop = UDim.new(0, 4)

-- ── Кнопка «Загрузить инвентарь» ─────────────────────────────
local LoadBtn = Instance.new("TextButton")
LoadBtn.Size              = UDim2.new(1, -16, 0, 34)
LoadBtn.Position          = UDim2.new(0, 8, 1, -42)
LoadBtn.BackgroundColor3  = Color3.fromRGB(30, 80, 200)
LoadBtn.Text              = "🔍  Загрузить инвентарь"
LoadBtn.TextColor3        = Color3.fromRGB(220, 235, 255)
LoadBtn.TextSize          = 14
LoadBtn.Font              = Enum.Font.GothamBold
LoadBtn.ZIndex            = 6
LoadBtn.Parent            = MainFrame
Instance.new("UICorner", LoadBtn).CornerRadius = UDim.new(0, 8)

-- ─────────────────────────────────────────────────────────────
--  СОСТОЯНИЕ
-- ─────────────────────────────────────────────────────────────
local selectedPlayer = nil  -- объект Player
local cachedPets     = {}   -- таблица данных петов текущего игрока

-- ─────────────────────────────────────────────────────────────
--  ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
-- ─────────────────────────────────────────────────────────────

-- Получить все данные петов из Backpack игрока
local function getPetsFromBackpack(player)
	local backpack = player:FindFirstChild("Backpack")
	if not backpack then return {} end

	local pets = {}
	local countMap = {} -- name+mutation -> count

	for _, tool in ipairs(backpack:GetChildren()) do
		if tool:IsA("Tool") and not IGNORED_TOOLS[tool.Name] then
			local infoGUI  = tool:FindFirstChild("InfoGUI")
			if infoGUI then
				-- Читаем текстовые метки
				local function getText(labelName)
					local lbl = infoGUI:FindFirstChild(labelName)
					if lbl and lbl:IsA("TextLabel") then
						-- Значение может быть после двоеточия: "Rarity: Legendary"
						local v = lbl.Text
						local after = v:match(":%s*(.+)$")
						return after and after:match("^%s*(.-)%s*$") or v:match("^%s*(.-)%s*$")
					end
					return "?"
				end

				local petName    = getText("Name")
				local rarity     = getText("Rarity")
				local mutation   = getText("Mutation")
				local earnings   = getText("Earnings")

				-- Картинка через ImageLabel внутри Open This
				local imageId = ""
				local openThis = tool:FindFirstChild("Open This")
				if openThis then
					local imgObj = openThis:FindFirstChild("Paste the link to the image in here")
					if imgObj and imgObj:IsA("ImageLabel") then
						imageId = imgObj.Image
					end
				end

				local key = petName .. "|" .. mutation
				countMap[key] = (countMap[key] or 0) + 1

				table.insert(pets, {
					name     = petName,
					rarity   = rarity,
					mutation = mutation,
					earnings = earnings,
					image    = imageId,
					key      = key,
				})
			end
		end
	end

	-- Добавим count в каждую запись
	for _, pet in ipairs(pets) do
		pet.count = countMap[pet.key]
	end

	return pets
end

-- Сортировка
local function sortPets(pets, mode)
	local sorted = {}
	for _, p in ipairs(pets) do table.insert(sorted, p) end

	if mode == "Редкость" then
		table.sort(sorted, function(a, b)
			local ra = RARITY_ORDER[a.rarity]   or 99
			local rb = RARITY_ORDER[b.rarity]   or 99
			if ra ~= rb then return ra < rb end
			local ma = MUTATION_ORDER[a.mutation] or 99
			local mb = MUTATION_ORDER[b.mutation] or 99
			return ma < mb
		end)
	elseif mode == "Мутация" then
		table.sort(sorted, function(a, b)
			local ma = MUTATION_ORDER[a.mutation] or 99
			local mb = MUTATION_ORDER[b.mutation] or 99
			if ma ~= mb then return ma < mb end
			local ra = RARITY_ORDER[a.rarity]   or 99
			local rb = RARITY_ORDER[b.rarity]   or 99
			return ra < rb
		end)
	elseif mode == "Название" then
		table.sort(sorted, function(a, b)
			return a.name:lower() < b.name:lower()
		end)
	elseif mode == "Количество" then
		table.sort(sorted, function(a, b)
			if a.count ~= b.count then return a.count > b.count end
			local ra = RARITY_ORDER[a.rarity] or 99
			local rb = RARITY_ORDER[b.rarity] or 99
			return ra < rb
		end)
	end
	return sorted
end

-- Создать карточку пета
local function makeCard(pet, order)
	local rarityColor   = RARITY_COLORS[pet.rarity]   or Color3.fromRGB(180,180,180)
	local mutationColor = MUTATION_COLORS[pet.mutation] or Color3.fromRGB(200,200,200)

	local card = Instance.new("Frame")
	card.Size              = UDim2.new(0, 142, 0, 190)
	card.BackgroundColor3  = Color3.fromRGB(16, 20, 38)
	card.BorderSizePixel   = 0
	card.LayoutOrder       = order
	card.ZIndex            = 8
	Instance.new("UICorner", card).CornerRadius = UDim.new(0, 10)

	-- Цветная полоска редкости сверху
	local topBar = Instance.new("Frame", card)
	topBar.Size             = UDim2.new(1, 0, 0, 4)
	topBar.BackgroundColor3 = rarityColor
	topBar.BorderSizePixel  = 0
	topBar.ZIndex           = 9
	Instance.new("UICorner", topBar).CornerRadius = UDim.new(0, 10)

	-- Обводка карточки цветом редкости
	local stroke = Instance.new("UIStroke", card)
	stroke.Color     = rarityColor
	stroke.Thickness = 1.2
	stroke.Transparency = 0.45

	-- Картинка пета
	local img = Instance.new("ImageLabel", card)
	img.Size              = UDim2.new(0, 100, 0, 88)
	img.Position          = UDim2.new(0.5, -50, 0, 10)
	img.BackgroundColor3  = Color3.fromRGB(10, 13, 25)
	img.BorderSizePixel   = 0
	img.Image             = pet.image ~= "" and pet.image or "rbxasset://textures/ui/GuiImagePlaceholder.png"
	img.ScaleType         = Enum.ScaleType.Fit
	img.ZIndex            = 9
	Instance.new("UICorner", img).CornerRadius = UDim.new(0, 8)

	-- Если количество > 1 — значок x2 etc.
	if pet.count and pet.count > 1 then
		local badge = Instance.new("TextLabel", card)
		badge.Size             = UDim2.new(0, 34, 0, 18)
		badge.Position         = UDim2.new(1, -38, 0, 14)
		badge.BackgroundColor3 = Color3.fromRGB(255, 160, 0)
		badge.Text             = "×" .. pet.count
		badge.TextColor3       = Color3.fromRGB(20, 20, 20)
		badge.TextSize         = 12
		badge.Font             = Enum.Font.GothamBold
		badge.ZIndex           = 11
		Instance.new("UICorner", badge).CornerRadius = UDim.new(0, 5)
	end

	-- Название
	local nameLabel = Instance.new("TextLabel", card)
	nameLabel.Size             = UDim2.new(1, -8, 0, 20)
	nameLabel.Position         = UDim2.new(0, 4, 0, 102)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text             = pet.name
	nameLabel.TextColor3       = Color3.fromRGB(225, 235, 255)
	nameLabel.TextSize         = 12
	nameLabel.Font             = Enum.Font.GothamBold
	nameLabel.TextTruncate     = Enum.TextTruncate.AtEnd
	nameLabel.ZIndex           = 9

	-- Редкость
	local rarLabel = Instance.new("TextLabel", card)
	rarLabel.Size              = UDim2.new(1, -8, 0, 16)
	rarLabel.Position          = UDim2.new(0, 4, 0, 122)
	rarLabel.BackgroundTransparency = 1
	rarLabel.Text              = "✦ " .. (pet.rarity or "?")
	rarLabel.TextColor3        = rarityColor
	rarLabel.TextSize          = 11
	rarLabel.Font              = Enum.Font.GothamBold
	rarLabel.ZIndex            = 9

	-- Мутация
	local mutLabel = Instance.new("TextLabel", card)
	mutLabel.Size              = UDim2.new(1, -8, 0, 16)
	mutLabel.Position          = UDim2.new(0, 4, 0, 139)
	mutLabel.BackgroundTransparency = 1
	mutLabel.Text              = "◈ " .. (pet.mutation or "?")
	mutLabel.TextColor3        = mutationColor
	mutLabel.TextSize          = 11
	mutLabel.Font              = Enum.Font.Gotham
	mutLabel.ZIndex            = 9

	-- Заработок
	local earnLabel = Instance.new("TextLabel", card)
	earnLabel.Size             = UDim2.new(1, -8, 0, 16)
	earnLabel.Position         = UDim2.new(0, 4, 0, 157)
	earnLabel.BackgroundTransparency = 1
	earnLabel.Text             = "💰 " .. (pet.earnings or "?") .. "/сек"
	earnLabel.TextColor3       = Color3.fromRGB(255, 220, 100)
	earnLabel.TextSize         = 11
	earnLabel.Font             = Enum.Font.Gotham
	earnLabel.ZIndex           = 9

	return card
end

-- ─────────────────────────────────────────────────────────────
--  ОБНОВЛЕНИЕ КАРТОЧЕК
-- ─────────────────────────────────────────────────────────────
local function renderCards(pets)
	-- Удалить старые карточки
	for _, child in ipairs(CardScroll:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end

	if #pets == 0 then
		StatusLabel.Text = "⚠  Петов не найдено в инвентаре"
		return
	end

	-- Дедупликация для отображения: показываем одну карточку на key,
	-- но с полем count (уже проставлено при парсинге)
	local seen    = {}
	local unique  = {}
	for _, pet in ipairs(pets) do
		if not seen[pet.key] then
			seen[pet.key] = true
			table.insert(unique, pet)
		end
	end

	StatusLabel.Text = string.format("🐾  Всего петов: %d  |  Уникальных: %d  |  Сортировка: %s",
		#pets, #unique, currentSort)

	for i, pet in ipairs(unique) do
		local card = makeCard(pet, i)
		card.Parent = CardScroll
	end

	-- Обновить высоту скролла
	local cols = math.floor(CardScroll.AbsoluteSize.X / (142 + 8))
	if cols < 1 then cols = 1 end
	local rows = math.ceil(#unique / cols)
	CardScroll.CanvasSize = UDim2.new(0, 0, 0, rows * (190 + 8) + 8)
end

-- ─────────────────────────────────────────────────────────────
--  СПИСОК ИГРОКОВ
-- ─────────────────────────────────────────────────────────────
local function updateSortButtons()
	for mode, btn in pairs(sortButtons) do
		if mode == currentSort then
			btn.BackgroundColor3 = Color3.fromRGB(30, 80, 200)
			btn.TextColor3       = Color3.fromRGB(255, 255, 255)
		else
			btn.BackgroundColor3 = Color3.fromRGB(25, 30, 52)
			btn.TextColor3       = Color3.fromRGB(160, 190, 240)
		end
	end
end

local playerBtns = {}

local function clearPlayerList()
	for _, btn in pairs(playerBtns) do btn:Destroy() end
	playerBtns = {}
end

local function buildPlayerList()
	clearPlayerList()
	for _, player in ipairs(Players:GetPlayers()) do
		local isLocal = (player == LocalPlayer)
		local btn = Instance.new("TextButton")
		btn.Size              = UDim2.new(1, -6, 0, 30)
		btn.BackgroundColor3  = isLocal
			and Color3.fromRGB(20, 40, 80)
			or  Color3.fromRGB(20, 24, 44)
		btn.Text              = (isLocal and "★ " or "  ") .. player.Name
		btn.TextColor3        = isLocal
			and Color3.fromRGB(160, 200, 255)
			or  Color3.fromRGB(200, 210, 230)
		btn.TextSize          = 13
		btn.Font              = Enum.Font.Gotham
		btn.TextXAlignment    = Enum.TextXAlignment.Left
		btn.ZIndex            = 8
		btn.Parent            = PlayerScroll
		Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
		Instance.new("UIPadding", btn).PaddingLeft = UDim.new(0, 8)

		playerBtns[player.Name] = btn

		btn.MouseButton1Click:Connect(function()
			selectedPlayer = player
			-- Сбросить выделение
			for _, b in pairs(playerBtns) do
				b.BackgroundColor3 = Color3.fromRGB(20, 24, 44)
				b.TextColor3       = Color3.fromRGB(200, 210, 230)
			end
			btn.BackgroundColor3 = Color3.fromRGB(30, 70, 180)
			btn.TextColor3       = Color3.fromRGB(255, 255, 255)
			StatusLabel.Text     = "Выбран: " .. player.Name .. " — нажмите «Загрузить»"
		end)
	end
end

-- ─────────────────────────────────────────────────────────────
--  ЛОГИКА КНОПОК
-- ─────────────────────────────────────────────────────────────

-- Открыть/закрыть главное окно
TriggerBtn.MouseButton1Click:Connect(function()
	MainFrame.Visible = not MainFrame.Visible
	if MainFrame.Visible then
		buildPlayerList()
	end
end)

CloseBtn.MouseButton1Click:Connect(function()
	MainFrame.Visible = false
end)

-- Загрузить инвентарь
LoadBtn.MouseButton1Click:Connect(function()
	if not selectedPlayer then
		StatusLabel.Text = "⚠  Сначала выберите игрока!"
		return
	end
	if not Players:FindFirstChild(selectedPlayer.Name) then
		StatusLabel.Text = "⚠  Игрок покинул сервер"
		selectedPlayer = nil
		return
	end

	StatusLabel.Text = "⏳  Загружаю инвентарь " .. selectedPlayer.Name .. "..."

	-- Очищаем карточки
	for _, child in ipairs(CardScroll:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end

	local pets = getPetsFromBackpack(selectedPlayer)
	cachedPets = pets

	local sorted = sortPets(pets, currentSort)
	renderCards(sorted)
end)

-- Кнопки сортировки
for mode, btn in pairs(sortButtons) do
	btn.MouseButton1Click:Connect(function()
		currentSort = mode
		updateSortButtons()
		if #cachedPets > 0 then
			local sorted = sortPets(cachedPets, currentSort)
			renderCards(sorted)
		end
	end)
end

-- ─────────────────────────────────────────────────────────────
--  АВТО-ОБНОВЛЕНИЕ СПИСКА ИГРОКОВ
-- ─────────────────────────────────────────────────────────────
Players.PlayerAdded:Connect(function()
	if MainFrame.Visible then buildPlayerList() end
end)
Players.PlayerRemoving:Connect(function(player)
	if selectedPlayer == player then
		selectedPlayer = nil
		StatusLabel.Text = "⚠  Выбранный игрок покинул сервер"
	end
	if MainFrame.Visible then buildPlayerList() end
end)

-- ─────────────────────────────────────────────────────────────
--  ИНИЦИАЛИЗАЦИЯ
-- ─────────────────────────────────────────────────────────────
updateSortButtons()
