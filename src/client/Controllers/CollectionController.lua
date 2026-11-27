-- Coleção e equipe: cards das criaturas, três slots e equipar/retirar.
--
-- Só desenha o que o servidor manda. Todo pedido vai por Remote e é validado lá.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CreatureConfig = require(Shared.Config.CreatureConfig)
local GameConfig = require(Shared.Config.GameConfig)
local Theme = require(Shared.UI.Theme)
local Localization = require(Shared.Util.Localization)
local Remotes = require(Shared.Remotes)
local TeamUtil = require(Shared.Util.TeamUtil)

local player = Players.LocalPlayer

local CollectionController = {}

local openedEvent = Instance.new("BindableEvent")
-- Dispara quando o jogador abre o painel (o tutorial escuta isto)
CollectionController.Opened = openedEvent.Event

local gui: ScreenGui
local panel: Frame
local cardsFrame: ScrollingFrame
local slotsRow: Frame
local titleLabel: TextLabel
local toggleButton: TextButton

local creatures: { [string]: any } = {}
local collectionLimit = GameConfig.CollectionLimit
local activeTeam = { Slot1 = false, Slot2 = false, Slot3 = false }
local isOpen = false

-- Helpers --------------------------------------------------------------------

local function speciesName(speciesId: string): string
	local species = CreatureConfig.Get(speciesId)
	if not species then
		return speciesId
	end
	return Localization.Get(player, species.NameKey)
end

local function creatureLabel(creature): string
	return creature.Nickname or speciesName(creature.SpeciesId)
end

local function fatigueText(creature): string
	local untilTime = creature.FatigueUntil
	if untilTime and os.time() < untilTime then
		return Localization.Get(player, "Fatigue.Remaining", { seconds = untilTime - os.time() })
	end
	return Localization.Get(player, "Fatigue.Ready")
end

local function button(text: string, size: UDim2, parent: Instance): TextButton
	local b = Instance.new("TextButton")
	b.Size = size
	b.BackgroundColor3 = Theme.Colors.Primary
	b.BorderSizePixel = 0
	b.Font = Theme.Font
	b.TextSize = 20
	b.TextColor3 = Theme.Colors.Background
	b.Text = text
	b.AutoButtonColor = true
	b.Parent = parent
	Theme.Round(b)
	return b
end

-- Desenho --------------------------------------------------------------------

local function refreshSlots()
	for _, child in slotsRow:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	for index, key in TeamUtil.SlotKeys do
		local slot = Instance.new("Frame")
		slot.Name = key
		slot.Size = UDim2.fromOffset(190, 72)
		slot.BackgroundColor3 = Theme.Colors.Panel
		slot.BorderSizePixel = 0
		slot.LayoutOrder = index
		slot.Parent = slotsRow
		Theme.Round(slot)

		local caption = Instance.new("TextLabel")
		caption.Size = UDim2.new(1, -16, 0, 20)
		caption.Position = UDim2.fromOffset(8, 6)
		caption.BackgroundTransparency = 1
		caption.Font = Theme.FontBody
		caption.TextSize = 16
		caption.TextXAlignment = Enum.TextXAlignment.Left
		caption.TextColor3 = Theme.Colors.TextMuted
		caption.Text = Localization.Get(player, "Team.Slot", { slot = index })
		caption.Parent = slot

		local creatureId = activeTeam[key]
		local creature = creatureId and creatures[creatureId]

		local name = Instance.new("TextLabel")
		name.Size = UDim2.new(1, -16, 0, 24)
		name.Position = UDim2.fromOffset(8, 28)
		name.BackgroundTransparency = 1
		name.Font = Theme.Font
		name.TextSize = 20
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.TextColor3 = if creature then Theme.Colors.Text else Theme.Colors.TextMuted
		name.Text = if creature then creatureLabel(creature) else Localization.Get(player, "Team.Empty")
		name.Parent = slot

		if creature then
			local remove = button(Localization.Get(player, "Team.Unequip"), UDim2.fromOffset(78, 28), slot)
			remove.Position = UDim2.new(1, -86, 1, -34)
			remove.TextSize = 15
			remove.BackgroundColor3 = Theme.Colors.Danger
			remove.Activated:Connect(function()
				local request = Remotes.Get("TeamUnequipRequest") :: RemoteEvent
				request:FireServer(index)
			end)
		end
	end
end

local function refreshCards()
	for _, child in cardsFrame:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	local count = 0
	for _ in creatures do
		count += 1
	end
	titleLabel.Text = string.format("%s  %d/%d", Localization.Get(player, "Collection.Title"), count, collectionLimit)

	local order = {}
	for id in creatures do
		table.insert(order, id)
	end
	table.sort(order, function(a, b)
		return (creatures[a].CaptureDate or 0) < (creatures[b].CaptureDate or 0)
	end)

	for index, id in order do
		local creature = creatures[id]
		local card = Instance.new("Frame")
		card.Name = id
		card.Size = UDim2.fromOffset(168, 184)
		card.BackgroundColor3 = Theme.Colors.Panel
		card.BorderSizePixel = 0
		card.LayoutOrder = index
		card.Parent = cardsFrame
		Theme.Round(card)

		local equipped = TeamUtil.IsEquipped(activeTeam, id)
		if equipped then
			local stroke = Instance.new("UIStroke")
			stroke.Color = Theme.Colors.Primary
			stroke.Thickness = 2
			stroke.Parent = card
		end

		local name = Instance.new("TextLabel")
		name.Size = UDim2.new(1, -16, 0, 26)
		name.Position = UDim2.fromOffset(8, 8)
		name.BackgroundTransparency = 1
		name.Font = Theme.Font
		name.TextSize = 20
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.TextColor3 = Theme.Colors.Text
		name.Text = creatureLabel(creature)
		name.Parent = card

		local level = Instance.new("TextLabel")
		level.Size = UDim2.new(1, -16, 0, 20)
		level.Position = UDim2.fromOffset(8, 34)
		level.BackgroundTransparency = 1
		level.Font = Theme.FontBody
		level.TextSize = 16
		level.TextXAlignment = Enum.TextXAlignment.Left
		level.TextColor3 = Theme.Colors.Accent
		level.Text = Localization.Get(player, "Creature.Level", { level = creature.Level })
		level.Parent = card

		local state = Instance.new("TextLabel")
		state.Size = UDim2.new(1, -16, 0, 20)
		state.Position = UDim2.fromOffset(8, 56)
		state.BackgroundTransparency = 1
		state.Font = Theme.FontBody
		state.TextSize = 15
		state.TextXAlignment = Enum.TextXAlignment.Left
		state.TextColor3 = Theme.Colors.TextMuted
		state.Text = fatigueText(creature)
		state.Parent = card

		local storage = Instance.new("TextLabel")
		storage.Size = UDim2.new(1, -16, 0, 20)
		storage.Position = UDim2.fromOffset(8, 78)
		storage.BackgroundTransparency = 1
		storage.Font = Theme.FontBody
		storage.TextSize = 15
		storage.TextXAlignment = Enum.TextXAlignment.Left
		storage.TextColor3 = Theme.Colors.TextMuted
		storage.Text = Localization.Get(player, if equipped then "Collection.Equipped" else "Collection.Stored")
		storage.Parent = card

		if not equipped then
			local equip = button(Localization.Get(player, "Team.Equip"), UDim2.new(1, -16, 0, 40), card)
			equip.Position = UDim2.new(0, 8, 1, -48)
			equip.Activated:Connect(function()
				local request = Remotes.Get("TeamEquipRequest") :: RemoteEvent
				request:FireServer(id)
			end)
		end
	end

	cardsFrame.CanvasSize = UDim2.fromOffset(0, math.ceil(count / 3) * 196 + 12)
end

local function refresh()
	refreshSlots()
	refreshCards()
end

-- Abrir e fechar -------------------------------------------------------------

function CollectionController:SetOpen(open: boolean)
	isOpen = open
	panel.Visible = open
	if open then
		refresh()
		openedEvent:Fire()
	end
end

function CollectionController:IsOpen(): boolean
	return isOpen
end

-- Construção -----------------------------------------------------------------

function CollectionController:Init()
	gui = Instance.new("ScreenGui")
	gui.Name = "CollectionUI"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 20

	-- Botão de abrir (canto inferior direito, alvo de toque grande)
	toggleButton = Instance.new("TextButton")
	toggleButton.Name = "Toggle"
	toggleButton.AnchorPoint = Vector2.new(1, 1)
	toggleButton.Position = UDim2.new(1, -20, 1, -20)
	toggleButton.Size = UDim2.fromOffset(150, Theme.MinTouchSize)
	toggleButton.BackgroundColor3 = Theme.Colors.Primary
	toggleButton.BorderSizePixel = 0
	toggleButton.Font = Theme.Font
	toggleButton.TextSize = 22
	toggleButton.TextColor3 = Theme.Colors.Background
	toggleButton.Text = Localization.Get(player, "Collection.Title")
	toggleButton.Parent = gui
	Theme.Round(toggleButton)

	panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(600, 480)
	panel.BackgroundColor3 = Theme.Colors.Background
	panel.BorderSizePixel = 0
	panel.Visible = false
	panel.Parent = gui
	Theme.Round(panel)
	Theme.ApplyScale(panel)

	titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, -140, 0, 40)
	titleLabel.Position = UDim2.fromOffset(16, 12)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Theme.Font
	titleLabel.TextSize = 28
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.TextColor3 = Theme.Colors.Text
	titleLabel.Text = Localization.Get(player, "Collection.Title")
	titleLabel.Parent = panel

	local close = button("X", UDim2.fromOffset(Theme.MinTouchSize, Theme.MinTouchSize), panel)
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -12, 0, 10)
	close.BackgroundColor3 = Theme.Colors.Panel
	close.TextColor3 = Theme.Colors.Text
	close.Activated:Connect(function()
		self:SetOpen(false)
	end)

	slotsRow = Instance.new("Frame")
	slotsRow.Name = "Slots"
	slotsRow.Position = UDim2.fromOffset(16, 70)
	slotsRow.Size = UDim2.new(1, -32, 0, 72)
	slotsRow.BackgroundTransparency = 1
	slotsRow.Parent = panel

	local slotsLayout = Instance.new("UIListLayout")
	slotsLayout.FillDirection = Enum.FillDirection.Horizontal
	slotsLayout.Padding = UDim.new(0, 8)
	slotsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	slotsLayout.Parent = slotsRow

	cardsFrame = Instance.new("ScrollingFrame")
	cardsFrame.Name = "Cards"
	cardsFrame.Position = UDim2.fromOffset(16, 154)
	cardsFrame.Size = UDim2.new(1, -32, 1, -170)
	cardsFrame.BackgroundTransparency = 1
	cardsFrame.BorderSizePixel = 0
	cardsFrame.ScrollBarThickness = 6
	cardsFrame.CanvasSize = UDim2.fromOffset(0, 0)
	cardsFrame.Parent = panel

	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(168, 184)
	grid.CellPadding = UDim2.fromOffset(12, 12)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = cardsFrame

	toggleButton.Activated:Connect(function()
		self:SetOpen(not isOpen)
	end)

	gui.Parent = player:WaitForChild("PlayerGui")
end

function CollectionController:Start()
	local creatureUpdate = Remotes.Get("CreatureUpdate") :: RemoteEvent
	creatureUpdate.OnClientEvent:Connect(function(newCreatures, limit)
		creatures = newCreatures or {}
		collectionLimit = limit or collectionLimit
		if isOpen then
			refresh()
		end
	end)

	local teamUpdate = Remotes.Get("TeamUpdate") :: RemoteEvent
	teamUpdate.OnClientEvent:Connect(function(team)
		activeTeam = team or activeTeam
		if isOpen then
			refresh()
		end
	end)

	-- Estado inicial
	task.spawn(function()
		local snapshot = (Remotes.Get("GetProfileSnapshot") :: RemoteFunction):InvokeServer()
		if snapshot then
			creatures = snapshot.Creatures or {}
			collectionLimit = snapshot.CollectionLimit or collectionLimit
			activeTeam = snapshot.ActiveTeam or activeTeam
			if isOpen then
				refresh()
			end
		end
	end)
end

return CollectionController
