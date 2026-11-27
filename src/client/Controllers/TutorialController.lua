-- Orquestra o que o jogador vê em cada passo do tutorial: a faixa de
-- objetivo, a seta sobre o alvo, as falas do mentor, a chegada do pet e o
-- card de revelação. Quem decide o passo é sempre o servidor.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared.UI.Theme)
local Localization = require(Shared.Util.Localization)
local Remotes = require(Shared.Remotes)

local CardRevealController = require(script.Parent.CardRevealController)
local CollectionController = require(script.Parent.CollectionController)
local DialogueController = require(script.Parent.DialogueController)
local ObjectiveArrowController = require(script.Parent.ObjectiveArrowController)
local PetArrivalController = require(script.Parent.PetArrivalController)

local player = Players.LocalPlayer

local TutorialController = {}

local gui: ScreenGui
local banner: Frame
local titleLabel: TextLabel
local bodyLabel: TextLabel
local stepLabel: TextLabel

local connections: { RBXScriptConnection } = {}

local function sendAction(stepId: string)
	local action = Remotes.Get("TutorialAction") :: RemoteEvent
	action:FireServer(stepId)
end

-- Faixa de objetivo ----------------------------------------------------------

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

-- Passos ----------------------------------------------------------------------

local function clearConnections()
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
end

local function once(signal: RBXScriptSignal, handler: (...any) -> ())
	local connection
	connection = signal:Connect(function(...)
		connection:Disconnect()
		handler(...)
	end)
	table.insert(connections, connection)
end

local function applyStep(step)
	clearConnections()

	if not step then
		banner.Visible = false
		ObjectiveArrowController:SetTarget(nil)
		DialogueController:Stop()
		return
	end

	showBanner(step)
	ObjectiveArrowController:SetTarget(step.Target, step.BaseLot)

	if step.Advance == "Dialogue" then
		-- Na chegada do pet, as falas correm junto com a corrida; só avança
		-- quando as duas coisas terminam.
		if step.PetArrival then
			local dialogueDone, petDone = false, false
			local function tryFinish()
				if dialogueDone and petDone then
					sendAction(step.Id)
				end
			end
			once(PetArrivalController.Arrived, function()
				petDone = true
				tryFinish()
			end)
			once(DialogueController.Finished, function()
				dialogueDone = true
				tryFinish()
			end)
			DialogueController:Play(step.SpeakerKey, step.Lines)
			return
		end

		once(DialogueController.Finished, function()
			sendAction(step.Id)
		end)
		DialogueController:Play(step.SpeakerKey, step.Lines)
		return
	end

	if step.Advance == "Card" then
		if not CardRevealController:IsShowing() then
			-- o card já foi fechado antes deste passo chegar
			task.defer(sendAction, step.Id)
			return
		end
		once(CardRevealController.Dismissed, function()
			sendAction(step.Id)
		end)
		return
	end

	if step.Id == "OpenCollection" then
		if CollectionController:IsOpen() then
			task.defer(sendAction, step.Id)
			return
		end
		once(CollectionController.Opened, function()
			sendAction(step.Id)
		end)
		return
	end

	-- Passos com falas que não dependem delas para avançar (ex.: voltar à base)
	if step.Lines and #step.Lines > 0 then
		DialogueController:Play(step.SpeakerKey, step.Lines)
	end
end

-- Construção -------------------------------------------------------------------

function TutorialController:Init()
	gui = Instance.new("ScreenGui")
	gui.Name = "TutorialUI"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 50

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

	gui.Parent = player:WaitForChild("PlayerGui")
end

function TutorialController:Start()
	local update = Remotes.Get("TutorialUpdate") :: RemoteEvent
	update.OnClientEvent:Connect(function(step)
		applyStep(step)
	end)
end

return TutorialController
