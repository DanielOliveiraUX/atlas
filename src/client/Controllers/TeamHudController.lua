-- Os três slots da equipe, sempre visíveis na tela.
--
-- O jogador precisa ver com quem está andando sem abrir nada. Slot com pet
-- mostra o bicho; slot vazio convida a escolher. Tocar num slot cheio retira;
-- tocar num vazio abre a coleção.
--
-- Fica na borda direita, acima do botão Coleção: longe do joystick (esquerda),
-- do botão de pulo e da caixa de diálogo (centro).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CreatureConfig = require(Shared.Config.CreatureConfig)
local Theme = require(Shared.UI.Theme)
local Localization = require(Shared.Util.Localization)
local Remotes = require(Shared.Remotes)
local TeamUtil = require(Shared.Util.TeamUtil)

local player = Players.LocalPlayer

local TeamHudController = {}

local SLOT = 74 -- lado do quadrado de cada slot
local GAP = 8
local MARGIN = 18
local BOTTOM = 96 -- espaço reservado para o botão Coleção

local gui: ScreenGui
local coluna: Frame
local slots: { [number]: Frame } = {}

local creatures: { [string]: any } = {}
local activeTeam = { Slot1 = false, Slot2 = false, Slot3 = false }

-- Retrato ---------------------------------------------------------------------

local function limparRetrato(slot: Frame)
	local antigo = slot:FindFirstChild("Retrato")
	if antigo then
		antigo:Destroy()
	end
end

-- Mesma ideia do card: um ViewportFrame com o modelo de verdade dentro.
local function montarRetrato(slot: Frame, speciesId: string)
	local species = CreatureConfig.Get(speciesId)
	local modelName = (species and species.ModelName) or speciesId
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local pets = assets and assets:FindFirstChild("Pets")
	local source = pets and pets:FindFirstChild(modelName)
	if not (source and source:IsA("Model")) then
		return
	end

	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "Retrato"
	viewport.Size = UDim2.new(1, -10, 1, -22)
	viewport.Position = UDim2.fromOffset(5, 5)
	viewport.BackgroundTransparency = 1
	viewport.Parent = slot

	local modelo = source:Clone()
	for _, d in modelo:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	modelo.Parent = viewport

	local camera = Instance.new("Camera")
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	local pivot = modelo:GetPivot()
	local extents = modelo:GetExtentsSize()
	local reach = math.max(extents.X, extents.Y, extents.Z)
	camera.CFrame = CFrame.lookAt(
		pivot.Position + Vector3.new(reach * 0.55, reach * 0.40, -reach * 1.45),
		pivot.Position
	)
end

-- Desenho -----------------------------------------------------------------------

local function pintarSlot(index: number, key: string)
	local slot = slots[index]
	if not slot then
		return
	end

	local creatureId = activeTeam[key]
	local creature = creatureId and creatures[creatureId]

	limparRetrato(slot)

	local numero = slot:FindFirstChild("Numero") :: TextLabel
	local rotulo = slot:FindFirstChild("Rotulo") :: TextLabel
	local vazio = slot:FindFirstChild("Vazio") :: TextLabel
	local borda = slot:FindFirstChild("Borda") :: UIStroke

	if creature then
		montarRetrato(slot, creature.SpeciesId)
		local species = CreatureConfig.Get(creature.SpeciesId)
		rotulo.Text = creature.Nickname
			or (species and Localization.Get(player, species.NameKey))
			or creature.SpeciesId
		rotulo.TextColor3 = Theme.Colors.Text
		vazio.Visible = false
		borda.Color = Theme.Colors.Accent
		borda.Transparency = 0
		slot.BackgroundTransparency = 0.1
	else
		rotulo.Text = Localization.Get(player, "Team.Empty")
		rotulo.TextColor3 = Theme.Colors.TextMuted
		vazio.Visible = true
		borda.Color = Theme.Colors.TextMuted
		borda.Transparency = 0.45
		slot.BackgroundTransparency = 0.45
	end

	numero.Text = tostring(index)
end

local function pintarTudo()
	for index, key in TeamUtil.SlotKeys do
		pintarSlot(index, key)
	end
end

-- Construção ----------------------------------------------------------------------

local function construirSlot(index: number): Frame
	local slot = Instance.new("Frame")
	slot.Name = "Slot" .. index
	slot.Size = UDim2.fromOffset(SLOT, SLOT)
	slot.BackgroundColor3 = Theme.Colors.Panel
	slot.BorderSizePixel = 0
	slot.LayoutOrder = index
	slot.Parent = coluna
	Theme.Round(slot)

	local borda = Instance.new("UIStroke")
	borda.Name = "Borda"
	borda.Thickness = 2
	borda.Color = Theme.Colors.TextMuted
	borda.Parent = slot

	local numero = Instance.new("TextLabel")
	numero.Name = "Numero"
	numero.Size = UDim2.fromOffset(16, 16)
	numero.Position = UDim2.fromOffset(5, 3)
	numero.BackgroundTransparency = 1
	numero.Font = Theme.Font
	numero.TextSize = 14
	numero.TextXAlignment = Enum.TextXAlignment.Left
	numero.TextColor3 = Theme.Colors.Accent
	numero.Text = tostring(index)
	numero.ZIndex = 3
	numero.Parent = slot

	-- marca do slot livre
	local vazio = Instance.new("TextLabel")
	vazio.Name = "Vazio"
	vazio.Size = UDim2.new(1, 0, 1, -18)
	vazio.BackgroundTransparency = 1
	vazio.Font = Theme.Font
	vazio.TextSize = 30
	vazio.TextColor3 = Theme.Colors.TextMuted
	vazio.Text = "+"
	vazio.Parent = slot

	local rotulo = Instance.new("TextLabel")
	rotulo.Name = "Rotulo"
	rotulo.AnchorPoint = Vector2.new(0.5, 1)
	rotulo.Position = UDim2.new(0.5, 0, 1, -3)
	rotulo.Size = UDim2.new(1, -8, 0, 15)
	rotulo.BackgroundTransparency = 1
	rotulo.Font = Theme.FontBody
	rotulo.TextSize = 13
	rotulo.TextScaled = false
	rotulo.TextTruncate = Enum.TextTruncate.AtEnd
	rotulo.TextColor3 = Theme.Colors.TextMuted
	rotulo.Text = ""
	rotulo.ZIndex = 3
	rotulo.Parent = slot

	local toque = Instance.new("TextButton")
	toque.Name = "Toque"
	toque.Size = UDim2.fromScale(1, 1)
	toque.BackgroundTransparency = 1
	toque.Text = ""
	toque.ZIndex = 5
	toque.Parent = slot

	toque.Activated:Connect(function()
		local key = TeamUtil.SlotKeys[index]
		if activeTeam[key] then
			local pedido = Remotes.Get("TeamUnequipRequest") :: RemoteEvent
			pedido:FireServer(index)
		else
			-- slot livre: leva o jogador para escolher
			local CollectionController = require(script.Parent.CollectionController)
			CollectionController:SetOpen(true)
		end
		-- confirmação de toque, para o dedo saber que pegou
		TweenService:Create(slot, TweenInfo.new(0.09), { Size = UDim2.fromOffset(SLOT - 6, SLOT - 6) }):Play()
		task.delay(0.1, function()
			TweenService:Create(slot, TweenInfo.new(0.12), { Size = UDim2.fromOffset(SLOT, SLOT) }):Play()
		end)
	end)

	return slot
end

function TeamHudController:Init()
	gui = Instance.new("ScreenGui")
	gui.Name = "TeamHudUI"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 18

	coluna = Instance.new("Frame")
	coluna.Name = "Slots"
	coluna.AnchorPoint = Vector2.new(1, 1)
	coluna.Position = UDim2.new(1, -MARGIN, 1, -BOTTOM)
	coluna.Size = UDim2.fromOffset(SLOT, SLOT * 3 + GAP * 2)
	coluna.BackgroundTransparency = 1
	coluna.Parent = gui

	local lista = Instance.new("UIListLayout")
	lista.FillDirection = Enum.FillDirection.Vertical
	lista.Padding = UDim.new(0, GAP)
	lista.SortOrder = Enum.SortOrder.LayoutOrder
	lista.Parent = coluna

	for index = 1, #TeamUtil.SlotKeys do
		slots[index] = construirSlot(index)
	end

	pintarTudo()
	gui.Parent = player:WaitForChild("PlayerGui")
end

function TeamHudController:Start()
	local teamUpdate = Remotes.Get("TeamUpdate") :: RemoteEvent
	teamUpdate.OnClientEvent:Connect(function(team)
		activeTeam = team or activeTeam
		pintarTudo()
	end)

	local creatureUpdate = Remotes.Get("CreatureUpdate") :: RemoteEvent
	creatureUpdate.OnClientEvent:Connect(function(novas)
		creatures = novas or {}
		pintarTudo()
	end)

	task.spawn(function()
		local snapshot = (Remotes.Get("GetProfileSnapshot") :: RemoteFunction):InvokeServer()
		if snapshot then
			creatures = snapshot.Creatures or {}
			activeTeam = snapshot.ActiveTeam or activeTeam
			pintarTudo()
		end
	end)
end

return TeamHudController
