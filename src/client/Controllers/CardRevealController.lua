-- Revelação do pet: sempre que o jogador recebe uma criatura, o card entra
-- animado. Vale para o tutorial, para a captura e para prêmios de batalha —
-- quem dispara é o servidor, por CreatureGranted.
--
-- Vários pets de uma vez entram numa fila, um card de cada vez.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared.UI.Theme)
local Localization = require(Shared.Util.Localization)
local Remotes = require(Shared.Remotes)

local CreatureCard = require(script.Parent.Parent.UI.CreatureCard)

local player = Players.LocalPlayer

local CardRevealController = {}

local dismissedEvent = Instance.new("BindableEvent")
-- Dispara (creature) quando o jogador fecha a revelação
CardRevealController.Dismissed = dismissedEvent.Event

local gui: ScreenGui
local backdrop: Frame
local holder: Frame
local headline: TextLabel
local dismissButton: TextButton

local queue: { any } = {}
local showing = false
local currentCard: Frame? = nil
local currentCreature: any = nil

local POP_IN = TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local FADE = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local BAR_FILL = TweenInfo.new(0.55, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

-- Animação ------------------------------------------------------------------

local function sweepShine(card: Frame)
	local shine = Instance.new("Frame")
	shine.Name = "Shine"
	shine.BackgroundColor3 = Theme.Card.Shine
	shine.BackgroundTransparency = 0.78
	shine.BorderSizePixel = 0
	shine.Size = UDim2.new(0, 90, 2, 0)
	shine.AnchorPoint = Vector2.new(0.5, 0.5)
	shine.Position = UDim2.new(-0.25, 0, 0.5, 0)
	shine.Rotation = 18
	shine.ZIndex = 10
	shine.Parent = card

	local tween = TweenService:Create(shine, TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
		Position = UDim2.new(1.25, 0, 0.5, 0),
	})
	tween.Completed:Connect(function()
		shine:Destroy()
	end)
	tween:Play()
end

local function animateIn(card: Frame)
	local scale = Instance.new("UIScale")
	scale.Scale = 0.55
	scale.Parent = card

	card.Rotation = -7
	TweenService:Create(scale, POP_IN, { Scale = 1 }):Play()
	TweenService:Create(card, POP_IN, { Rotation = 0 }):Play()

	-- barras sobem depois que o card assenta, uma de cada vez
	task.delay(0.3, function()
		if not card.Parent then
			return
		end
		sweepShine(card)
		for index, bar in CreatureCard.AnimatedBars(card) do
			local target = bar:GetAttribute("TargetScale") or 0
			task.delay(index * 0.08, function()
				if bar.Parent then
					TweenService:Create(bar, BAR_FILL, { Size = UDim2.fromScale(target, 1) }):Play()
				end
			end)
		end
	end)
end

-- Fila ------------------------------------------------------------------------

local function clearCard()
	if currentCard then
		currentCard:Destroy()
		currentCard = nil
	end
end

local function hide()
	local creature = currentCreature
	currentCreature = nil
	showing = false

	TweenService:Create(backdrop, FADE, { BackgroundTransparency = 1 }):Play()
	if currentCard then
		local card = currentCard
		currentCard = nil
		local scale = card:FindFirstChildOfClass("UIScale") or Instance.new("UIScale", card)
		TweenService:Create(scale, FADE, { Scale = 0.85 }):Play()
		task.delay(FADE.Time, function()
			card:Destroy()
		end)
	end
	gui.Enabled = false

	if creature then
		dismissedEvent:Fire(creature)
	end

	task.defer(function()
		if #queue > 0 then
			local nextCreature = table.remove(queue, 1)
			CardRevealController:Show(nextCreature)
		end
	end)
end

-- API -------------------------------------------------------------------------

function CardRevealController:Show(creature)
	if showing then
		table.insert(queue, creature)
		return
	end
	showing = true
	currentCreature = creature

	clearCard()
	gui.Enabled = true
	backdrop.BackgroundTransparency = 1
	TweenService:Create(backdrop, FADE, { BackgroundTransparency = 0.45 }):Play()

	headline.Text = Localization.Get(player, "Card.NewPet")

	local card = CreatureCard.Build(creature)
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.5)
	card.Parent = holder
	currentCard = card

	dismissButton.Text = Localization.Get(player, "Tutorial.Continue")
	animateIn(card)
end

function CardRevealController:IsShowing(): boolean
	return showing
end

-- Construção --------------------------------------------------------------------

function CardRevealController:Init()
	gui = Instance.new("ScreenGui")
	gui.Name = "CardRevealUI"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 80
	gui.Enabled = false

	backdrop = Instance.new("Frame")
	backdrop.Name = "Backdrop"
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = Color3.fromRGB(8, 12, 18)
	backdrop.BackgroundTransparency = 1
	backdrop.BorderSizePixel = 0
	backdrop.Parent = gui

	holder = Instance.new("Frame")
	holder.Name = "Holder"
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.48)
	holder.Size = UDim2.fromOffset(CreatureCard.Size.X, CreatureCard.Size.Y)
	holder.BackgroundTransparency = 1
	holder.Parent = backdrop

	-- O conjunto é alto (título + card + botão). Theme.ApplyScale usa uma
	-- resolução de referência e não garante que caiba; aqui a escala vem da
	-- altura real do conjunto, senão o título e o botão saem da tela.
	local fit = Instance.new("UIScale")
	fit.Parent = holder

	local TOTAL_HEIGHT = 42 + 18 + CreatureCard.Size.Y + 20 + Theme.MinTouchSize
	local TOTAL_WIDTH = CreatureCard.Size.X + 40

	local function fitToViewport()
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local viewport = camera.ViewportSize
		local byHeight = (viewport.Y - 48) / TOTAL_HEIGHT
		local byWidth = (viewport.X - 32) / TOTAL_WIDTH
		fit.Scale = math.clamp(math.min(byHeight, byWidth), 0.42, 1)
	end

	fitToViewport()
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(fitToViewport)
	end
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		fitToViewport()
		local newCamera = workspace.CurrentCamera
		if newCamera then
			newCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fitToViewport)
		end
	end)

	headline = Instance.new("TextLabel")
	headline.Name = "Headline"
	headline.AnchorPoint = Vector2.new(0.5, 1)
	headline.Position = UDim2.new(0.5, 0, 0, -18)
	headline.Size = UDim2.fromOffset(CreatureCard.Size.X, 42)
	headline.BackgroundTransparency = 1
	headline.Font = Theme.Font
	headline.TextSize = 34
	headline.TextColor3 = Theme.Colors.Accent
	headline.Text = ""
	headline.Parent = holder

	dismissButton = Instance.new("TextButton")
	dismissButton.Name = "Dismiss"
	dismissButton.AnchorPoint = Vector2.new(0.5, 0)
	dismissButton.Position = UDim2.new(0.5, 0, 1, 20)
	dismissButton.Size = UDim2.fromOffset(240, Theme.MinTouchSize)
	dismissButton.BackgroundColor3 = Theme.Colors.Primary
	dismissButton.BorderSizePixel = 0
	dismissButton.Font = Theme.Font
	dismissButton.TextSize = 22
	dismissButton.TextColor3 = Theme.Colors.Background
	dismissButton.Text = ""
	dismissButton.Parent = holder
	Theme.Round(dismissButton)

	dismissButton.Activated:Connect(function()
		if showing then
			hide()
		end
	end)

	gui.Parent = player:WaitForChild("PlayerGui")
end

function CardRevealController:Start()
	local granted = Remotes.Get("CreatureGranted") :: RemoteEvent
	granted.OnClientEvent:Connect(function(creature)
		if type(creature) == "table" and creature.SpeciesId then
			self:Show(creature)
		end
	end)
end

return CardRevealController
