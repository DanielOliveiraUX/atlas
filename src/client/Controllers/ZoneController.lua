-- Em que lugar o jogador está, e o que isso muda na tela.
--
-- Faz duas coisas que andam juntas:
--
-- 1. Anuncia a entrada. Cruzou a fronteira de uma base ou de um bioma, o
--    nome do lugar aparece no meio da tela e some sozinho.
--
-- 2. Fecha o horizonte. Sem isso o jogador via o mapa inteiro de qualquer
--    ponto e nada parecia distante. Na vila dá para adivinhar os biomas ao
--    longe; dentro de um bioma, a vila e os vizinhos somem na bruma. O zoom
--    máximo da câmera também encolhe, porque de longe o mapa aparecia todo.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared.UI.Theme)
local Localization = require(Shared.Util.Localization)
local WorldConfig = require(Shared.Config.WorldConfig)

local player = Players.LocalPlayer

local ZoneController = {}

local INTERVALO = 0.35 -- de quanto em quanto tempo conferimos onde ele está
local ENTRADA = 0.5
local PERMANENCIA = 2.5
local SAIDA = 0.9
local TRANSICAO_FOG = 1.6

local gui: ScreenGui
local cartaz: Frame
local tituloLabel: TextLabel
local subLabel: TextLabel
local risco: Frame

local atmosfera: Atmosphere
local zonaAtual: any = nil
local anuncioToken = 0
local centroDaBase: Vector3? = nil

-- Cartaz ----------------------------------------------------------------------

local function anunciar(zona)
	anuncioToken += 1
	local token = anuncioToken

	tituloLabel.Text = Localization.Get(player, zona.NomeChave)
	subLabel.Text = Localization.Get(player, zona.SubChave)

	cartaz.Visible = true
	tituloLabel.TextTransparency = 1
	subLabel.TextTransparency = 1
	risco.BackgroundTransparency = 1
	risco.Size = UDim2.fromOffset(0, 2)

	local entra = TweenInfo.new(ENTRADA, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(tituloLabel, entra, { TextTransparency = 0 }):Play()
	TweenService:Create(subLabel, entra, { TextTransparency = 0.15 }):Play()
	TweenService:Create(risco, TweenInfo.new(ENTRADA + 0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
		BackgroundTransparency = 0.2,
		Size = UDim2.fromOffset(260, 2),
	}):Play()

	task.delay(ENTRADA + PERMANENCIA, function()
		if anuncioToken ~= token then
			return -- entrou em outro lugar antes de este sumir
		end
		local sai = TweenInfo.new(SAIDA, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		TweenService:Create(tituloLabel, sai, { TextTransparency = 1 }):Play()
		TweenService:Create(subLabel, sai, { TextTransparency = 1 }):Play()
		TweenService:Create(risco, sai, { BackgroundTransparency = 1 }):Play()
		task.delay(SAIDA, function()
			if anuncioToken == token then
				cartaz.Visible = false
			end
		end)
	end)
end

-- Horizonte ---------------------------------------------------------------------

local function aplicarFog(zona)
	local f = zona.Fog
	if not f then
		return
	end
	local info = TweenInfo.new(TRANSICAO_FOG, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local alvo: { [string]: any } = {
		Density = f.Densidade,
		Haze = f.Bruma,
		Color = f.Cor,
	}
	if f.Decay then
		alvo.Decay = f.Decay
	end
	TweenService:Create(atmosfera, info, alvo):Play()
	if f.Zoom then
		player.CameraMaxZoomDistance = f.Zoom
	end
end

-- Onde ele está -------------------------------------------------------------------

-- O lote do jogador. O servidor grava o número dele no atributo "BaseLot"
-- do próprio jogador (BaseService), que replica para cá.
local function acharCentroDaBase(): Vector3?
	local indice = player:GetAttribute("BaseLot")
	if type(indice) ~= "number" then
		return nil
	end
	local bases = workspace:FindFirstChild(WorldConfig.BasesFolder)
	local lote = bases and bases:FindFirstChild(WorldConfig.LotName(indice))
	if not lote then
		return nil
	end
	local chao = lote:FindFirstChild("Ground")
	return (chao and chao:IsA("BasePart") and chao.Position) or lote:GetPivot().Position
end

local function conferir()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		return
	end

	local zona = WorldConfig.ZoneAt(root.Position, centroDaBase)
	if zona == zonaAtual then
		return
	end
	zonaAtual = zona
	aplicarFog(zona)
	anunciar(zona)
end

-- Construção -------------------------------------------------------------------------

function ZoneController:Init()
	-- uma Atmosphere já existe no place; se não, criamos
	atmosfera = Lighting:FindFirstChildWhichIsA("Atmosphere")
	if not atmosfera then
		atmosfera = Instance.new("Atmosphere")
		atmosfera.Parent = Lighting
	end

	gui = Instance.new("ScreenGui")
	gui.Name = "ZoneUI"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 40

	cartaz = Instance.new("Frame")
	cartaz.Name = "Cartaz"
	cartaz.AnchorPoint = Vector2.new(0.5, 0.5)
	cartaz.Position = UDim2.fromScale(0.5, 0.42)
	cartaz.Size = UDim2.fromOffset(620, 120)
	cartaz.BackgroundTransparency = 1
	cartaz.Visible = false
	cartaz.Parent = gui

	tituloLabel = Instance.new("TextLabel")
	tituloLabel.Name = "Titulo"
	tituloLabel.Size = UDim2.new(1, 0, 0, 56)
	tituloLabel.BackgroundTransparency = 1
	tituloLabel.Font = Theme.Font
	tituloLabel.TextSize = 46
	tituloLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	tituloLabel.TextStrokeTransparency = 0.45
	tituloLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	tituloLabel.Text = ""
	tituloLabel.TextTransparency = 1
	tituloLabel.Parent = cartaz

	risco = Instance.new("Frame")
	risco.Name = "Risco"
	risco.AnchorPoint = Vector2.new(0.5, 0)
	risco.Position = UDim2.new(0.5, 0, 0, 62)
	risco.Size = UDim2.fromOffset(0, 2)
	risco.BackgroundColor3 = Theme.Colors.Accent
	risco.BorderSizePixel = 0
	risco.BackgroundTransparency = 1
	risco.Parent = cartaz

	subLabel = Instance.new("TextLabel")
	subLabel.Name = "Sub"
	subLabel.Position = UDim2.fromOffset(0, 74)
	subLabel.Size = UDim2.new(1, 0, 0, 28)
	subLabel.BackgroundTransparency = 1
	subLabel.Font = Theme.FontBody
	subLabel.TextSize = 20
	subLabel.TextColor3 = Color3.fromRGB(240, 240, 240)
	subLabel.TextStrokeTransparency = 0.6
	subLabel.Text = ""
	subLabel.TextTransparency = 1
	subLabel.Parent = cartaz

	gui.Parent = player:WaitForChild("PlayerGui")
end

function ZoneController:Start()
	-- o lote só é atribuído depois que o servidor carrega o perfil
	task.spawn(function()
		for _ = 1, 40 do
			centroDaBase = acharCentroDaBase()
			if centroDaBase then
				break
			end
			task.wait(0.5)
		end
	end)

	local acumulado = 0
	RunService.Heartbeat:Connect(function(dt)
		acumulado += dt
		if acumulado < INTERVALO then
			return
		end
		acumulado = 0
		conferir()
	end)
end

return ZoneController
