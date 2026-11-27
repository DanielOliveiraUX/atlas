-- Mostra o passo atual do tutorial e avisa o servidor quando a parte do
-- cliente termina. Quem decide o passo é sempre o servidor.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared.UI.Theme)
local Localization = require(Shared.Util.Localization)
local Remotes = require(Shared.Remotes)

local CollectionController = require(script.Parent.CollectionController)

local player = Players.LocalPlayer

local TutorialController = {}

local gui: ScreenGui
local banner: Frame
local titleLabel: TextLabel
local bodyLabel: TextLabel
local stepLabel: TextLabel

local revealCard: Frame
local revealTitle: TextLabel
local revealBody: TextLabel
local revealButton: TextButton

local currentStep: any = nil
local collectionConnection: RBXScriptConnection? = nil

local function sendAction(stepId: string)
	local action = Remotes.Get("TutorialAction") :: RemoteEvent
	action:FireServer(stepId)
end

-- Desenho --------------------------------------------------------------------

local function showBanner(step)
	titleLabel.Text = Localization.Get(player, step.TitleKey)
	bodyLabel.Text = Localization.Get(player, step.BodyKey)
	stepLabel.Text = string.format("%d/%d", step.Index, step.Total)

	if not banner.Visible then
		banner.Visible = true
		banner.BackgroundTransparency = 1
		TweenService:Create(banner, TweenInfo.new(0.3), { BackgroundTransparency = 0.05 }):Play()
	end
end

local function hideBanner()
	banner.Visible = false
end

local function showReveal(step)
	revealTitle.Text = Localization.Get(player, step.TitleKey)
	revealBody.Text = Localization.Get(player, step.BodyKey)
	revealButton.Text = Localization.Get(player, "Tutorial.Continue")
	revealCard.Visible = true
end

local function hideReveal()
	revealCard.Visible = false
end

-- Passos ---------------------------------------------------------------------

local function clearConnections()
	if collectionConnection then
		collectionConnection:Disconnect()
		collectionConnection = nil
	end
end

local function applyStep(step)
	clearConnections()
	currentStep = step

	if not step then
		hideBanner()
		hideReveal()
		return
	end

	showBanner(step)

	if step.Id == "ReceivePet" then
		showReveal(step)
		return
	end

	hideReveal()

	if step.Id == "OpenCollection" then
		-- Se já estiver aberta, conta na hora
		if CollectionController:IsOpen() then
			task.defer(sendAction, "OpenCollection")
			return
		end
		collectionConnection = CollectionController.Opened:Connect(function()
			sendAction("OpenCollection")
		end)
	end
end

-- Construção -----------------------------------------------------------------

function TutorialController:Init()
	gui = Instance.new("ScreenGui")
	gui.Name = "TutorialUI"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 50

	-- Faixa de objetivo, no topo
	banner = Instance.new("Frame")
	banner.Name = "Banner"
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Position = UDim2.new(0.5, 0, 0, 24)
	banner.Size = UDim2.fromOffset(560, 92)
	banner.BackgroundColor3 = Theme.Colors.Panel
	banner.BackgroundTransparency = 0.05
	banner.BorderSizePixel = 0
	banner.Visible = false
	banner.Parent = gui
	Theme.Round(banner)
	Theme.ApplyScale(banner)

	local accent = Instance.new("Frame")
	accent.Size = UDim2.fromOffset(6, 60)
	accent.Position = UDim2.fromOffset(14, 16)
	accent.BackgroundColor3 = Theme.Colors.Accent
	accent.BorderSizePixel = 0
	accent.Parent = banner
	Theme.Round(accent)

	titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, -120, 0, 30)
	titleLabel.Position = UDim2.fromOffset(32, 14)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Theme.Font
	titleLabel.TextSize = 24
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.TextColor3 = Theme.Colors.Text
	titleLabel.Text = ""
	titleLabel.Parent = banner

	bodyLabel = Instance.new("TextLabel")
	bodyLabel.Size = UDim2.new(1, -120, 0, 40)
	bodyLabel.Position = UDim2.fromOffset(32, 44)
	bodyLabel.BackgroundTransparency = 1
	bodyLabel.Font = Theme.FontBody
	bodyLabel.TextSize = 18
	bodyLabel.TextXAlignment = Enum.TextXAlignment.Left
	bodyLabel.TextYAlignment = Enum.TextYAlignment.Top
	bodyLabel.TextWrapped = true
	bodyLabel.TextColor3 = Theme.Colors.TextMuted
	bodyLabel.Text = ""
	bodyLabel.Parent = banner

	stepLabel = Instance.new("TextLabel")
	stepLabel.AnchorPoint = Vector2.new(1, 0)
	stepLabel.Size = UDim2.fromOffset(70, 30)
	stepLabel.Position = UDim2.new(1, -16, 0, 14)
	stepLabel.BackgroundTransparency = 1
	stepLabel.Font = Theme.Font
	stepLabel.TextSize = 20
	stepLabel.TextXAlignment = Enum.TextXAlignment.Right
	stepLabel.TextColor3 = Theme.Colors.Accent
	stepLabel.Text = ""
	stepLabel.Parent = banner

	-- Cartão de apresentação do pet inicial
	revealCard = Instance.new("Frame")
	revealCard.Name = "Reveal"
	revealCard.AnchorPoint = Vector2.new(0.5, 0.5)
	revealCard.Position = UDim2.fromScale(0.5, 0.5)
	revealCard.Size = UDim2.fromOffset(420, 260)
	revealCard.BackgroundColor3 = Theme.Colors.Background
	revealCard.BorderSizePixel = 0
	revealCard.Visible = false
	revealCard.Parent = gui
	Theme.Round(revealCard)
	Theme.ApplyScale(revealCard)

	local revealStroke = Instance.new("UIStroke")
	revealStroke.Color = Theme.Colors.Accent
	revealStroke.Thickness = 2
	revealStroke.Parent = revealCard

	revealTitle = Instance.new("TextLabel")
	revealTitle.Size = UDim2.new(1, -40, 0, 40)
	revealTitle.Position = UDim2.fromOffset(20, 24)
	revealTitle.BackgroundTransparency = 1
	revealTitle.Font = Theme.Font
	revealTitle.TextSize = 30
	revealTitle.TextColor3 = Theme.Colors.Accent
	revealTitle.Text = ""
	revealTitle.Parent = revealCard

	revealBody = Instance.new("TextLabel")
	revealBody.Size = UDim2.new(1, -48, 0, 110)
	revealBody.Position = UDim2.fromOffset(24, 72)
	revealBody.BackgroundTransparency = 1
	revealBody.Font = Theme.FontBody
	revealBody.TextSize = 19
	revealBody.TextWrapped = true
	revealBody.TextYAlignment = Enum.TextYAlignment.Top
	revealBody.TextColor3 = Theme.Colors.Text
	revealBody.Text = ""
	revealBody.Parent = revealCard

	revealButton = Instance.new("TextButton")
	revealButton.AnchorPoint = Vector2.new(0.5, 1)
	revealButton.Position = UDim2.new(0.5, 0, 1, -20)
	revealButton.Size = UDim2.fromOffset(240, Theme.MinTouchSize)
	revealButton.BackgroundColor3 = Theme.Colors.Primary
	revealButton.BorderSizePixel = 0
	revealButton.Font = Theme.Font
	revealButton.TextSize = 22
	revealButton.TextColor3 = Theme.Colors.Background
	revealButton.Text = ""
	revealButton.Parent = revealCard
	Theme.Round(revealButton)

	revealButton.Activated:Connect(function()
		if currentStep and currentStep.Id == "ReceivePet" then
			hideReveal()
			sendAction("ReceivePet")
		end
	end)

	gui.Parent = player:WaitForChild("PlayerGui")
end

function TutorialController:Start()
	local update = Remotes.Get("TutorialUpdate") :: RemoteEvent
	update.OnClientEvent:Connect(function(step)
		applyStep(step)
	end)
end

return TutorialController
