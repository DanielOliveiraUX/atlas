-- Seta de objetivo: uma marca flutuante sobre o alvo do passo atual, com a
-- distância. Sem isso o jogador fica solto num mapa aberto sem saber para
-- onde ir — era o único ponto do onboarding capaz de travar alguém.
--
-- A seta fica sempre visível (AlwaysOnTop), inclusive atrás de casas e árvores.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared.UI.Theme)
local WorldConfig = require(Shared.Config.WorldConfig)
local Localization = require(Shared.Util.Localization)

local player = Players.LocalPlayer

local ObjectiveArrowController = {}

local billboard: BillboardGui
local arrowLabel: TextLabel
local titleLabel: TextLabel
local distanceLabel: TextLabel
local anchor: Part

local currentTarget: BasePart? = nil
local currentHeight = 6
local bobConnection: RBXScriptConnection? = nil

-- Indicador em tela, além da marca no mundo. Dois motivos: no celular o
-- alvo costuma estar fora do campo de visão, e aí a marca no mundo não
-- ajuda em nada; e ela some atrás da interface quando o alvo fica no topo.
local screenGui: ScreenGui
local marker: Frame
local markerArrow: TextLabel
local markerTitle: TextLabel
local markerDistance: TextLabel
local EDGE_MARGIN = 64

-- Alvos ----------------------------------------------------------------------

local function mentorPart(): BasePart?
	local hub = workspace:FindFirstChild(WorldConfig.HubFolder)
	local mentor = hub and hub:FindFirstChild(WorldConfig.MentorPart)
	if not mentor then
		return nil
	end
	if mentor:IsA("Model") then
		return (mentor.PrimaryPart or mentor:FindFirstChildWhichIsA("BasePart")) :: BasePart?
	end
	return mentor :: BasePart
end

local function basePart(lot: number?): BasePart?
	if not lot then
		return nil
	end
	local bases = workspace:FindFirstChild(WorldConfig.BasesFolder)
	local lotModel = bases and bases:FindFirstChild(WorldConfig.LotName(lot))
	if not lotModel then
		return nil
	end
	local found = lotModel:FindFirstChild(WorldConfig.LotSpawnPart, true)
	return if found and found:IsA("BasePart") then found else nil
end

-- Ciclo ----------------------------------------------------------------------

local function stop()
	if bobConnection then
		bobConnection:Disconnect()
		bobConnection = nil
	end
	billboard.Enabled = false
	screenGui.Enabled = false
	currentTarget = nil
end

-- Põe o marcador sobre o alvo; se o alvo estiver fora da tela (ou atrás),
-- prende na borda apontando para a direção certa.
local function placeMarker(worldPosition: Vector3)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local viewport = camera.ViewportSize
	local point, inFront = camera:WorldToViewportPoint(worldPosition)
	local center = Vector2.new(viewport.X / 2, viewport.Y / 2)

	local onScreen = inFront
		and point.X >= EDGE_MARGIN and point.X <= viewport.X - EDGE_MARGIN
		and point.Y >= EDGE_MARGIN and point.Y <= viewport.Y - EDGE_MARGIN

	if onScreen then
		marker.Position = UDim2.fromOffset(point.X, point.Y)
		markerArrow.Rotation = 0
		markerArrow.Text = "▼"
		markerTitle.Visible = true
		return
	end

	local direction = Vector2.new(point.X, point.Y) - center
	if not inFront then
		direction = -direction
	end
	if direction.Magnitude < 1 then
		direction = Vector2.new(0, -1)
	end
	direction = direction.Unit

	local halfX = viewport.X / 2 - EDGE_MARGIN
	local halfY = viewport.Y / 2 - EDGE_MARGIN
	local scale = math.min(
		halfX / math.max(math.abs(direction.X), 1e-4),
		halfY / math.max(math.abs(direction.Y), 1e-4)
	)
	local edge = center + direction * scale

	marker.Position = UDim2.fromOffset(edge.X, edge.Y)
	-- "▼" aponta para baixo; girar para a direção do alvo
	markerArrow.Text = "▼"
	markerArrow.Rotation = math.deg(math.atan2(direction.X, direction.Y)) + 180
	markerTitle.Visible = true
end

local function follow()
	local elapsed = 0
	screenGui.Enabled = true
	bobConnection = RunService.RenderStepped:Connect(function(delta)
		elapsed += delta
		local target = currentTarget
		if not target or not target.Parent then
			stop()
			return
		end

		local height = currentHeight + math.sin(elapsed * 2.6) * 0.5
		local worldPosition = target.Position + Vector3.new(0, height, 0)
		anchor.CFrame = CFrame.new(worldPosition)

		local text = ""
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			local flat = Vector3.new(root.Position.X - target.Position.X, 0, root.Position.Z - target.Position.Z)
			text = string.format("%d m", math.floor(flat.Magnitude / 3 + 0.5))
		end
		distanceLabel.Text = text
		markerDistance.Text = text

		placeMarker(worldPosition)
	end)
end

-- API -------------------------------------------------------------------------

-- kind: "Mentor" | "Base" | nil (esconde)
function ObjectiveArrowController:SetTarget(kind: string?, lot: number?)
	stop()
	if not kind then
		return
	end

	local target: BasePart? = nil
	local labelKey: string? = nil
	local height = 6

	if kind == "Mentor" then
		target = mentorPart()
		labelKey = "Objective.Mentor"
		-- A altura sai do topo do MODELO, não da peça: medir pelo torso
		-- jogava a seta lá em cima, atrás da faixa de objetivo.
		local hub = workspace:FindFirstChild(WorldConfig.HubFolder)
		local mentor = hub and hub:FindFirstChild(WorldConfig.MentorPart)
		if target and mentor and mentor:IsA("Model") then
			local pivot, size = mentor:GetBoundingBox()
			height = (pivot.Position.Y + size.Y / 2) - target.Position.Y + 2.4
		end
	elseif kind == "Base" then
		target = basePart(lot)
		labelKey = "Objective.Base"
		height = 8
	end

	if not target then
		warn("[ObjectiveArrow] alvo não encontrado:", kind)
		return
	end

	currentTarget = target
	currentHeight = height
	local text = Localization.Get(player, labelKey)
	titleLabel.Text = text
	markerTitle.Text = text
	billboard.Enabled = true
	follow()
end

-- Construção ------------------------------------------------------------------

function ObjectiveArrowController:Init()
	-- Âncora invisível: o billboard precisa de algo no mundo para seguir
	anchor = Instance.new("Part")
	anchor.Name = "ObjectiveAnchor"
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	-- No Workspace, não na Camera: dentro da Camera o BillboardGui não
	-- renderiza de forma confiável. Criada no cliente, a âncora é local de
	-- qualquer jeito — os outros jogadores não a veem.
	anchor.Parent = workspace

	billboard = Instance.new("BillboardGui")
	billboard.Name = "ObjectiveArrow"
	billboard.Adornee = anchor
	billboard.AlwaysOnTop = true
	billboard.Size = UDim2.fromOffset(190, 108)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 0, 0)
	billboard.Enabled = false
	billboard.Parent = anchor

	local plate = Instance.new("Frame")
	plate.Name = "Plate"
	plate.AnchorPoint = Vector2.new(0.5, 0)
	plate.Position = UDim2.fromScale(0.5, 0)
	plate.Size = UDim2.fromOffset(186, 52)
	plate.BackgroundColor3 = Theme.Colors.Panel
	plate.BackgroundTransparency = 0.1
	plate.BorderSizePixel = 0
	plate.Parent = billboard
	Theme.Round(plate)

	local plateStroke = Instance.new("UIStroke")
	plateStroke.Color = Theme.Colors.Accent
	plateStroke.Thickness = 2
	plateStroke.Parent = plate

	titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.new(1, -12, 0, 26)
	titleLabel.Position = UDim2.fromOffset(6, 4)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Theme.Font
	titleLabel.TextSize = 18
	titleLabel.TextColor3 = Theme.Colors.Text
	titleLabel.Text = ""
	titleLabel.Parent = plate

	distanceLabel = Instance.new("TextLabel")
	distanceLabel.Name = "Distance"
	distanceLabel.Size = UDim2.new(1, -12, 0, 18)
	distanceLabel.Position = UDim2.fromOffset(6, 28)
	distanceLabel.BackgroundTransparency = 1
	distanceLabel.Font = Theme.FontBody
	distanceLabel.TextSize = 15
	distanceLabel.TextColor3 = Theme.Colors.Accent
	distanceLabel.Text = ""
	distanceLabel.Parent = plate

	arrowLabel = Instance.new("TextLabel")
	arrowLabel.Name = "Arrow"
	arrowLabel.AnchorPoint = Vector2.new(0.5, 1)
	arrowLabel.Position = UDim2.fromScale(0.5, 1)
	arrowLabel.Size = UDim2.fromOffset(60, 52)
	arrowLabel.BackgroundTransparency = 1
	arrowLabel.Font = Theme.Font
	arrowLabel.TextSize = 46
	arrowLabel.TextColor3 = Theme.Colors.Accent
	arrowLabel.Text = "▼"
	arrowLabel.Parent = billboard

	-- Indicador em tela ------------------------------------------------------
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ObjectiveUI"
	screenGui.IgnoreGuiInset = true
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 40
	screenGui.Enabled = false

	marker = Instance.new("Frame")
	marker.Name = "Marker"
	marker.AnchorPoint = Vector2.new(0.5, 0.5)
	marker.Size = UDim2.fromOffset(170, 84)
	marker.BackgroundTransparency = 1
	marker.Parent = screenGui

	markerArrow = Instance.new("TextLabel")
	markerArrow.Name = "Arrow"
	markerArrow.AnchorPoint = Vector2.new(0.5, 0.5)
	markerArrow.Position = UDim2.fromScale(0.5, 0.74)
	markerArrow.Size = UDim2.fromOffset(52, 44)
	markerArrow.BackgroundTransparency = 1
	markerArrow.Font = Theme.Font
	markerArrow.TextSize = 40
	markerArrow.TextColor3 = Theme.Colors.Accent
	markerArrow.Text = "▼"
	markerArrow.Parent = marker

	markerTitle = Instance.new("TextLabel")
	markerTitle.Name = "Title"
	markerTitle.AnchorPoint = Vector2.new(0.5, 0)
	markerTitle.Position = UDim2.fromScale(0.5, 0)
	markerTitle.Size = UDim2.fromOffset(170, 24)
	markerTitle.BackgroundTransparency = 1
	markerTitle.Font = Theme.Font
	markerTitle.TextSize = 19
	markerTitle.TextColor3 = Theme.Colors.Accent
	markerTitle.TextStrokeTransparency = 0.4
	markerTitle.TextStrokeColor3 = Color3.fromRGB(10, 14, 20)
	markerTitle.Text = ""
	markerTitle.Parent = marker

	markerDistance = Instance.new("TextLabel")
	markerDistance.Name = "Distance"
	markerDistance.AnchorPoint = Vector2.new(0.5, 0)
	markerDistance.Position = UDim2.new(0.5, 0, 0, 24)
	markerDistance.Size = UDim2.fromOffset(170, 20)
	markerDistance.BackgroundTransparency = 1
	markerDistance.Font = Theme.FontBody
	markerDistance.TextSize = 16
	markerDistance.TextColor3 = Theme.Colors.Text
	markerDistance.TextStrokeTransparency = 0.5
	markerDistance.TextStrokeColor3 = Color3.fromRGB(10, 14, 20)
	markerDistance.Text = ""
	markerDistance.Parent = marker

	screenGui.Parent = player:WaitForChild("PlayerGui")
end

function ObjectiveArrowController:Start()
	-- se algo limpar o Workspace, a âncora volta
	anchor.AncestryChanged:Connect(function(_, parent)
		if not parent then
			anchor.Parent = workspace
		end
	end)
end

return ObjectiveArrowController
