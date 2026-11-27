-- Card da criatura. Um componente só, usado na revelação (grande) e na
-- grade da coleção (compacto) — assim os dois nunca saem de sintonia.
--
-- O retrato é um ViewportFrame com o modelo 3D de verdade, não uma imagem:
-- a criatura que aparece no card é a mesma que anda no mundo.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CreatureConfig = require(Shared.Config.CreatureConfig)
local GameConfig = require(Shared.Config.GameConfig)
local Theme = require(Shared.UI.Theme)
local Localization = require(Shared.Util.Localization)

local player = Players.LocalPlayer

local CreatureCard = {}

CreatureCard.Size = Vector2.new(360, 620)
CreatureCard.CompactSize = Vector2.new(168, 212)

-- Barras mostradas no card, nesta ordem (igual à referência)
local STAT_ORDER = { "Attack", "Defense", "Speed" }

-- Helpers --------------------------------------------------------------------

local function corner(gui: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = gui
	return c
end

local function stroke(gui: Instance, color: Color3, thickness: number)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.Parent = gui
	return s
end

local function frame(name: string, parent: Instance, color: Color3?): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BackgroundColor3 = color or Theme.Card.Face
	f.BackgroundTransparency = if color then 0 else 1
	f.BorderSizePixel = 0
	f.Parent = parent
	return f
end

local function label(name: string, parent: Instance, text: string, size: number, color: Color3, font: Enum.Font?): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Font = font or Theme.FontBody
	l.TextSize = size
	l.TextColor3 = color
	l.Text = text
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Parent = parent
	return l
end

local function num(value: number): string
	return tostring(math.floor(value + 0.5))
end

-- Dados da criatura ----------------------------------------------------------

local function speciesOf(creature)
	return CreatureConfig.Get(creature.SpeciesId)
end

local function displayName(creature): string
	if creature.Nickname and creature.Nickname ~= "" then
		return creature.Nickname
	end
	local species = speciesOf(creature)
	return if species then Localization.Get(player, species.NameKey) else creature.SpeciesId
end

local function speciesTitle(creature): string
	local species = speciesOf(creature)
	if species and species.TitleKey then
		return Localization.Get(player, species.TitleKey)
	end
	return ""
end

local function rarityOf(creature): string
	local species = speciesOf(creature)
	return (species and species.Rarity) or "Common"
end

local function isResting(creature): (boolean, number)
	local untilTime = creature.FatigueUntil
	if untilTime and os.time() < untilTime then
		return true, untilTime - os.time()
	end
	return false, 0
end

-- Retrato 3D -----------------------------------------------------------------

local function buildPortrait(creature, parent: Instance): ViewportFrame
	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "Portrait"
	viewport.BackgroundColor3 = Theme.Card.FaceAlt
	viewport.BorderSizePixel = 0
	viewport.Ambient = Color3.fromRGB(190, 205, 220)
	viewport.LightColor = Color3.fromRGB(255, 252, 244)
	viewport.LightDirection = Vector3.new(-0.5, -0.8, -0.6)
	viewport.Parent = parent

	local species = speciesOf(creature)
	local modelName = (species and species.ModelName) or creature.SpeciesId
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local pets = assets and assets:FindFirstChild("Pets")
	local source = pets and pets:FindFirstChild(modelName)

	if source and source:IsA("Model") then
		local model = source:Clone()
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
			end
		end
		model.Parent = viewport

		local camera = Instance.new("Camera")
		camera.Parent = viewport
		viewport.CurrentCamera = camera

		local pivot, size = model:GetBoundingBox()
		local reach = math.max(size.X, size.Y, size.Z)
		-- o modelo olha para -Z, então a câmera fica do lado -Z, um pouco acima
		local offset = Vector3.new(reach * 0.62, reach * 0.42, -reach * 1.5)
		local from = pivot.Position + offset
		camera.CFrame = CFrame.lookAt(from, pivot.Position + Vector3.new(0, reach * 0.05, 0))
	else
		-- sem modelo no place, o card ainda funciona
		local missing = label("Missing", viewport, "?", 48, Theme.Card.InkMuted, Theme.Font)
		missing.Size = UDim2.fromScale(1, 1)
		missing.TextXAlignment = Enum.TextXAlignment.Center
	end

	return viewport
end

-- Card completo --------------------------------------------------------------

local function buildFull(creature, options): Frame
	local rarity = rarityOf(creature)
	local rarityColor = Theme.RarityColor(rarity)

	local card = Instance.new("Frame")
	card.Name = "CreatureCard"
	card.Size = UDim2.fromOffset(CreatureCard.Size.X, CreatureCard.Size.Y)
	card.BackgroundColor3 = Theme.Card.Face
	card.BorderSizePixel = 0
	corner(card, 20)
	stroke(card, rarityColor, 3)

	local sheen = Instance.new("UIGradient")
	sheen.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Theme.Card.FaceAlt)
	sheen.Rotation = 90
	sheen.Parent = card

	-- Faixa com o nome
	local banner = frame("Banner", card, rarityColor)
	banner.Size = UDim2.new(1, -48, 0, 54)
	banner.Position = UDim2.fromOffset(24, 14)
	corner(banner, 12)
	stroke(banner, Color3.fromRGB(255, 255, 255), 2)

	local nameLabel = label("Name", banner, displayName(creature), 30, Color3.fromRGB(255, 255, 255), Theme.Font)
	nameLabel.Size = UDim2.fromScale(1, 1)
	nameLabel.TextXAlignment = Enum.TextXAlignment.Center

	-- Espécie
	local subtitle = label("Species", card, speciesTitle(creature), 19, Theme.Card.InkMuted)
	subtitle.Size = UDim2.new(1, -40, 0, 24)
	subtitle.Position = UDim2.fromOffset(20, 74)
	subtitle.TextXAlignment = Enum.TextXAlignment.Center

	-- Selo de raridade
	local pill = frame("Rarity", card, rarityColor)
	pill.Size = UDim2.fromOffset(104, 26)
	pill.Position = UDim2.new(0.5, -52, 0, 102)
	corner(pill, 13)
	local pillText = label("Text", pill, Localization.Get(player, "Rarity." .. rarity), 16, Color3.fromRGB(255, 255, 255), Theme.Font)
	pillText.Size = UDim2.fromScale(1, 1)
	pillText.TextXAlignment = Enum.TextXAlignment.Center

	-- Retrato
	local portraitHolder = frame("PortraitHolder", card, Theme.Card.FaceAlt)
	portraitHolder.Size = UDim2.new(1, -48, 0, 196)
	portraitHolder.Position = UDim2.fromOffset(24, 138)
	portraitHolder.ClipsDescendants = true
	corner(portraitHolder, 14)
	stroke(portraitHolder, rarityColor, 2)
	local portrait = buildPortrait(creature, portraitHolder)
	portrait.Size = UDim2.fromScale(1, 1)

	-- Nível, barra de XP e estágio
	local levelRow = frame("LevelRow", card)
	levelRow.Size = UDim2.new(1, -48, 0, 44)
	levelRow.Position = UDim2.fromOffset(24, 344)

	local levelText = label("Level", levelRow,
		Localization.Get(player, "Creature.Level", { level = num(creature.Level) }), 20, Theme.Card.Ink, Theme.Font)
	levelText.Size = UDim2.new(0, 160, 0, 20)

	local stage = frame("Stage", levelRow, Theme.Card.Slot)
	stage.AnchorPoint = Vector2.new(1, 0)
	stage.Size = UDim2.fromOffset(108, 22)
	stage.Position = UDim2.new(1, 0, 0, 0)
	corner(stage, 11)
	local stageText = label("Text", stage,
		Localization.Get(player, "Card.Stage", { stage = num(creature.EvolutionStage or 1) }), 15, Color3.fromRGB(226, 236, 248), Theme.Font)
	stageText.Size = UDim2.fromScale(1, 1)
	stageText.TextXAlignment = Enum.TextXAlignment.Center

	local xpTrack = frame("XpTrack", levelRow, Theme.Card.Slot)
	xpTrack.Size = UDim2.new(1, 0, 0, 12)
	xpTrack.Position = UDim2.fromOffset(0, 26)
	corner(xpTrack, 6)
	local xpFill = frame("Fill", xpTrack, rarityColor)
	xpFill.Size = UDim2.fromScale(0, 1)
	corner(xpFill, 6)
	local needed = GameConfig.XpForNextLevel(creature.Level or 1)
	xpFill:SetAttribute("TargetScale", math.clamp((creature.Experience or 0) / math.max(needed, 1), 0, 1))

	-- Barras de atributo
	local statsHolder = frame("Stats", card)
	statsHolder.Size = UDim2.new(1, -48, 0, 108)
	statsHolder.Position = UDim2.fromOffset(24, 396)
	local statsLayout = Instance.new("UIListLayout")
	statsLayout.Padding = UDim.new(0, 8)
	statsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	statsLayout.Parent = statsHolder

	for index, statName in STAT_ORDER do
		local value = (creature.Stats and creature.Stats[statName]) or 0
		local max = GameConfig.StatBarMax[statName] or 100
		local ratio = math.clamp(value / max, 0, 1)

		local row = frame("Stat" .. statName, statsHolder)
		row.Size = UDim2.new(1, 0, 0, 28)
		row.LayoutOrder = index

		-- Rótulo num selo colorido à esquerda, separado da barra: com valor
		-- baixo a barra fica curta e cortaria o texto se fossem a mesma peça.
		local chip = frame("Chip", row, Theme.Stat[statName])
		chip.Size = UDim2.fromOffset(104, 28)
		corner(chip, 14)
		local chipText = label("Text", chip, Localization.Get(player, "Stat." .. statName), 15, Color3.fromRGB(255, 255, 255), Theme.Font)
		chipText.Size = UDim2.fromScale(1, 1)
		chipText.TextXAlignment = Enum.TextXAlignment.Center

		local track = frame("Track", row, Theme.Card.Slot)
		track.Size = UDim2.new(1, -164, 0, 14)
		track.Position = UDim2.fromOffset(112, 7)
		corner(track, 7)

		local fill = frame("Fill", track, Theme.Stat[statName])
		fill.Size = UDim2.fromScale(0, 1)
		corner(fill, 7)
		fill:SetAttribute("TargetScale", ratio)

		local statValue = label("Value", row, num(value), 16, Theme.Card.Ink, Theme.Font)
		statValue.AnchorPoint = Vector2.new(1, 0)
		statValue.Size = UDim2.fromOffset(44, 28)
		statValue.Position = UDim2.new(1, 0, 0, 0)
		statValue.TextXAlignment = Enum.TextXAlignment.Right
	end

	-- Habilidades
	local skillsHolder = frame("Skills", card)
	skillsHolder.Size = UDim2.new(1, -48, 0, 30)
	skillsHolder.Position = UDim2.fromOffset(24, 506)
	local skillsLayout = Instance.new("UIListLayout")
	skillsLayout.FillDirection = Enum.FillDirection.Horizontal
	skillsLayout.Padding = UDim.new(0, 8)
	skillsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	skillsLayout.Parent = skillsHolder

	for index, skillId in (creature.Skills or {}) do
		local chip = frame("Skill" .. index, skillsHolder, Theme.Card.FaceAlt)
		chip.Size = UDim2.fromOffset(112, 28)
		chip.LayoutOrder = index
		corner(chip, 14)
		stroke(chip, rarityColor, 1)
		local text = label("Text", chip, Localization.Get(player, "Skill." .. skillId), 14, Theme.Card.Ink, Theme.Font)
		text.Size = UDim2.fromScale(1, 1)
		text.TextXAlignment = Enum.TextXAlignment.Center
	end

	-- Condição e situação na equipe
	local resting, seconds = isResting(creature)
	local condition = label("Condition", card,
		if resting
			then Localization.Get(player, "Fatigue.Remaining", { seconds = num(seconds) })
			else Localization.Get(player, "Fatigue.Ready"),
		16, if resting then Theme.Colors.Danger else Color3.fromRGB(62, 150, 96), Theme.Font)
	condition.Size = UDim2.new(1, -48, 0, 22)
	condition.Position = UDim2.fromOffset(24, 546)

	local slot = options and options.equippedSlot
	local tag = frame("TeamTag", card, if slot then Theme.Colors.Primary else Theme.Card.Slot)
	tag.AnchorPoint = Vector2.new(1, 1)
	tag.Size = UDim2.fromOffset(132, 28)
	tag.Position = UDim2.new(1, -24, 1, -16)
	corner(tag, 14)
	local tagText = label("Text", tag,
		if slot
			then Localization.Get(player, "Card.EquippedSlot", { slot = num(slot) })
			else Localization.Get(player, "Collection.Stored"),
		14, if slot then Theme.Colors.Background else Color3.fromRGB(226, 236, 248), Theme.Font)
	tagText.Size = UDim2.fromScale(1, 1)
	tagText.TextXAlignment = Enum.TextXAlignment.Center

	return card
end

-- Card compacto (grade da coleção) -------------------------------------------

local function buildCompact(creature, options): Frame
	local rarity = rarityOf(creature)
	local rarityColor = Theme.RarityColor(rarity)
	local slot = options and options.equippedSlot

	local card = Instance.new("Frame")
	card.Name = "CreatureCard"
	card.Size = UDim2.fromOffset(CreatureCard.CompactSize.X, CreatureCard.CompactSize.Y)
	card.BackgroundColor3 = Theme.Card.Face
	card.BorderSizePixel = 0
	corner(card, 14)
	stroke(card, if slot then Theme.Colors.Primary else rarityColor, if slot then 3 else 2)

	local banner = frame("Banner", card, rarityColor)
	banner.Size = UDim2.new(1, -16, 0, 28)
	banner.Position = UDim2.fromOffset(8, 8)
	corner(banner, 8)
	local nameLabel = label("Name", banner, displayName(creature), 17, Color3.fromRGB(255, 255, 255), Theme.Font)
	nameLabel.Size = UDim2.fromScale(1, 1)
	nameLabel.TextXAlignment = Enum.TextXAlignment.Center

	local portraitHolder = frame("PortraitHolder", card, Theme.Card.FaceAlt)
	portraitHolder.Size = UDim2.new(1, -16, 0, 96)
	portraitHolder.Position = UDim2.fromOffset(8, 42)
	portraitHolder.ClipsDescendants = true
	corner(portraitHolder, 10)
	local portrait = buildPortrait(creature, portraitHolder)
	portrait.Size = UDim2.fromScale(1, 1)

	local levelText = label("Level", card,
		Localization.Get(player, "Creature.Level", { level = num(creature.Level) }), 14, Theme.Card.Ink, Theme.Font)
	levelText.Size = UDim2.new(1, -16, 0, 16)
	levelText.Position = UDim2.fromOffset(10, 144)

	local xpTrack = frame("XpTrack", card, Theme.Card.Slot)
	xpTrack.Size = UDim2.new(1, -20, 0, 7)
	xpTrack.Position = UDim2.fromOffset(10, 162)
	corner(xpTrack, 4)
	local xpFill = frame("Fill", xpTrack, rarityColor)
	local needed = GameConfig.XpForNextLevel(creature.Level or 1)
	xpFill.Size = UDim2.fromScale(math.clamp((creature.Experience or 0) / math.max(needed, 1), 0, 1), 1)
	corner(xpFill, 4)

	local resting = isResting(creature)
	local state = label("State", card,
		if resting then Localization.Get(player, "Fatigue.Resting") else Localization.Get(player, "Fatigue.Ready"),
		12, if resting then Theme.Colors.Danger else Color3.fromRGB(62, 150, 96))
	state.Size = UDim2.new(1, -16, 0, 14)
	state.Position = UDim2.fromOffset(10, 174)

	local tagText = label("Tag", card,
		if slot
			then Localization.Get(player, "Card.EquippedSlot", { slot = num(slot) })
			else Localization.Get(player, "Collection.Stored"),
		12, if slot then Theme.Colors.Primary else Theme.Card.InkMuted, Theme.Font)
	tagText.Size = UDim2.new(1, -16, 0, 14)
	tagText.Position = UDim2.fromOffset(10, 190)

	return card
end

-- API ------------------------------------------------------------------------

-- options = { compact: boolean?, equippedSlot: number? }
function CreatureCard.Build(creature, options): Frame
	if options and options.compact then
		return buildCompact(creature, options)
	end
	return buildFull(creature, options)
end

-- Barras que devem ser animadas (guardam TargetScale como atributo)
function CreatureCard.AnimatedBars(card: Frame): { Frame }
	local bars = {}
	for _, descendant in card:GetDescendants() do
		if descendant:IsA("Frame") and descendant:GetAttribute("TargetScale") ~= nil then
			table.insert(bars, descendant)
		end
	end
	return bars
end

return CreatureCard
