-- Correr: segurar Shift no PC, ou o botão "Correr" no celular.
--
-- A velocidade é do personagem local, então mora no cliente mesmo — é o
-- cliente que simula o próprio corpo. O servidor devolve a velocidade padrão
-- a cada nascimento, então nada fica preso em modo corrida.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Theme = require(Shared.UI.Theme)
local Localization = require(Shared.Util.Localization)

local player = Players.LocalPlayer

local SprintController = {}

local ACTION = "AtlasCorrer"

local sprinting = false
local humanoid: Humanoid? = nil
local gui: ScreenGui
local botao: TextButton

-- Velocidade ------------------------------------------------------------------

local function alvo(): number
	return if sprinting then GameConfig.RunSpeed else GameConfig.WalkSpeed
end

local function pintarBotao()
	if not botao then
		return
	end
	botao.BackgroundColor3 = if sprinting then Theme.Colors.Accent else Theme.Colors.Panel
	botao.TextColor3 = if sprinting then Theme.Colors.Background else Theme.Colors.Text
end

local function setSprint(ligado: boolean)
	if sprinting == ligado then
		return
	end
	sprinting = ligado
	pintarBotao()
end

-- Rampa: trocar WalkSpeed de uma vez dá um tranco na câmera e na animação.
local function atualizar(delta: number)
	local h = humanoid
	if not (h and h.Parent) then
		return
	end
	local destino = alvo()
	local atual = h.WalkSpeed
	if math.abs(destino - atual) < 0.05 then
		h.WalkSpeed = destino
		return
	end
	local passo = math.clamp(delta / math.max(GameConfig.SpeedRamp, 0.01), 0, 1)
	h.WalkSpeed = atual + (destino - atual) * passo
end

-- Entrada ----------------------------------------------------------------------

local function aoAgir(_, estado: Enum.UserInputState)
	if estado == Enum.UserInputState.Begin then
		setSprint(true)
	elseif estado == Enum.UserInputState.End or estado == Enum.UserInputState.Cancel then
		setSprint(false)
	end
	return Enum.ContextActionResult.Pass
end

-- Personagem --------------------------------------------------------------------

local function ligarPersonagem(character: Model)
	local h = character:WaitForChild("Humanoid", 10)
	if h and h:IsA("Humanoid") then
		humanoid = h
		h.WalkSpeed = GameConfig.WalkSpeed
	end
	-- nasceu de novo: ninguém continua correndo sem segurar nada
	setSprint(false)
end

-- Construção ----------------------------------------------------------------------

function SprintController:Init()
	gui = Instance.new("ScreenGui")
	gui.Name = "SprintUI"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 15
	-- no PC é Shift; o botão só existe para quem joga no toque
	gui.Enabled = UserInputService.TouchEnabled

	-- Fica à esquerda, acima do joystick, longe do botão de pulo (direita),
	-- da Coleção (direita) e da caixa de diálogo (centro).
	botao = Instance.new("TextButton")
	botao.Name = "Correr"
	botao.AnchorPoint = Vector2.new(0, 1)
	botao.Position = UDim2.new(0, 24, 1, -210)
	botao.Size = UDim2.fromOffset(104, Theme.MinTouchSize)
	botao.BackgroundColor3 = Theme.Colors.Panel
	botao.BackgroundTransparency = 0.15
	botao.BorderSizePixel = 0
	botao.Font = Theme.Font
	botao.TextSize = 18
	botao.TextColor3 = Theme.Colors.Text
	botao.Text = Localization.Get(player, "UI.Sprint")
	botao.AutoButtonColor = false
	botao.Parent = gui
	Theme.Round(botao)

	-- segurar o botão corre; soltar para
	botao.MouseButton1Down:Connect(function()
		setSprint(true)
	end)
	botao.MouseButton1Up:Connect(function()
		setSprint(false)
	end)
	botao.MouseLeave:Connect(function()
		setSprint(false)
	end)
	pintarBotao()

	gui.Parent = player:WaitForChild("PlayerGui")
end

function SprintController:Start()
	ContextActionService:BindAction(ACTION, aoAgir, false, Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift)

	if player.Character then
		ligarPersonagem(player.Character)
	end
	player.CharacterAdded:Connect(ligarPersonagem)

	RunService.RenderStepped:Connect(atualizar)
end

return SprintController
