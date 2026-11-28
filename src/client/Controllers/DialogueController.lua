-- Caixa de diálogo do NPC. Falas curtas, uma por vez, o jogador avança no
-- próprio ritmo. O texto entra letra a letra e um toque completa a linha
-- na hora — quem já leu não espera a digitação.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared.UI.Theme)
local Localization = require(Shared.Util.Localization)

local player = Players.LocalPlayer

local DialogueController = {}

local finishedEvent = Instance.new("BindableEvent")
-- Dispara quando a última fala da sequência é lida
DialogueController.Finished = finishedEvent.Event

local gui: ScreenGui
local panel: Frame
local speakerLabel: TextLabel
local textLabel: TextLabel
local hintLabel: TextLabel
local tapButton: TextButton

local lines: { string } = {}
local lineIndex = 0
local fullText = ""
local typing = false
local typeToken = 0
local active = false

local CHARS_PER_SECOND = 48

-- Digitação -------------------------------------------------------------------

local function typeLine(text: string)
	fullText = text
	typing = true
	typeToken += 1
	local token = typeToken

	textLabel.Text = ""
	hintLabel.Text = ""

	task.spawn(function()
		local total = utf8.len(text) or #text
		local shown = 0
		while shown < total do
			if typeToken ~= token then
				return
			end
			shown += 1
			local offset = utf8.offset(text, shown + 1)
			textLabel.Text = if offset then string.sub(text, 1, offset - 1) else text
			task.wait(1 / CHARS_PER_SECOND)
		end
		if typeToken == token then
			typing = false
			textLabel.Text = text
			hintLabel.Text = Localization.Get(player, "Dialogue.Continue")
		end
	end)
end

local function showLine(index: number)
	lineIndex = index
	local key = lines[index]
	if not key then
		return
	end
	typeLine(Localization.Get(player, key))
end

local function finish()
	active = false
	typeToken += 1
	gui.Enabled = false
	finishedEvent:Fire()
end

local function advance()
	if not active then
		return
	end
	if typing then
		-- primeiro toque completa a linha em vez de pular
		typeToken += 1
		typing = false
		textLabel.Text = fullText
		hintLabel.Text = Localization.Get(player, "Dialogue.Continue")
		return
	end
	if lineIndex >= #lines then
		finish()
		return
	end
	showLine(lineIndex + 1)
end

-- API --------------------------------------------------------------------------

function DialogueController:Play(speakerKey: string, lineKeys: { string })
	if not lineKeys or #lineKeys == 0 then
		finishedEvent:Fire()
		return
	end
	lines = lineKeys
	active = true
	speakerLabel.Text = Localization.Get(player, speakerKey)
	gui.Enabled = true

	panel.Position = UDim2.new(0.5, 0, 1, 40)
	TweenService:Create(panel, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 1, -28),
	}):Play()

	showLine(1)
end

function DialogueController:IsActive(): boolean
	return active
end

function DialogueController:Stop()
	if active then
		finish()
	end
end

-- Construção ---------------------------------------------------------------------

function DialogueController:Init()
	gui = Instance.new("ScreenGui")
	gui.Name = "DialogueUI"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 60
	gui.Enabled = false

	-- Toque na parte de baixo da tela avança. Já foi a tela inteira, e isso
	-- virou um bloqueio invisível: com uma fala aberta, nenhum clique chegava
	-- ao resto do jogo — nem o de atacar numa batalha.
	tapButton = Instance.new("TextButton")
	tapButton.Name = "Tap"
	tapButton.AnchorPoint = Vector2.new(0.5, 1)
	tapButton.Position = UDim2.fromScale(0.5, 1)
	tapButton.Size = UDim2.new(1, 0, 0.34, 0)
	tapButton.BackgroundTransparency = 1
	tapButton.Text = ""
	tapButton.AutoButtonColor = false
	tapButton.Parent = gui

	panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 1)
	panel.Position = UDim2.new(0.5, 0, 1, -28)
	panel.Size = UDim2.fromOffset(620, 136)
	panel.BackgroundColor3 = Theme.Colors.Panel
	panel.BackgroundTransparency = 0.03
	panel.BorderSizePixel = 0
	panel.Parent = gui
	Theme.Round(panel)
	Theme.ApplyScale(panel)

	local edge = Instance.new("UIStroke")
	edge.Color = Theme.Colors.Accent
	edge.Thickness = 2
	edge.Parent = panel

	local nameplate = Instance.new("Frame")
	nameplate.Name = "Nameplate"
	nameplate.Position = UDim2.fromOffset(20, -16)
	nameplate.Size = UDim2.fromOffset(210, 32)
	nameplate.BackgroundColor3 = Theme.Colors.Accent
	nameplate.BorderSizePixel = 0
	nameplate.Parent = panel
	Theme.Round(nameplate)

	speakerLabel = Instance.new("TextLabel")
	speakerLabel.Name = "Speaker"
	speakerLabel.Size = UDim2.fromScale(1, 1)
	speakerLabel.BackgroundTransparency = 1
	speakerLabel.Font = Theme.Font
	speakerLabel.TextSize = 18
	speakerLabel.TextColor3 = Theme.Colors.Background
	speakerLabel.Text = ""
	speakerLabel.Parent = nameplate

	textLabel = Instance.new("TextLabel")
	textLabel.Name = "Text"
	textLabel.Position = UDim2.fromOffset(24, 30)
	textLabel.Size = UDim2.new(1, -48, 0, 72)
	textLabel.BackgroundTransparency = 1
	textLabel.Font = Theme.FontBody
	textLabel.TextSize = 21
	textLabel.TextColor3 = Theme.Colors.Text
	textLabel.TextXAlignment = Enum.TextXAlignment.Left
	textLabel.TextYAlignment = Enum.TextYAlignment.Top
	textLabel.TextWrapped = true
	textLabel.Text = ""
	textLabel.Parent = panel

	hintLabel = Instance.new("TextLabel")
	hintLabel.Name = "Hint"
	hintLabel.AnchorPoint = Vector2.new(1, 1)
	hintLabel.Position = UDim2.new(1, -20, 1, -8)
	hintLabel.Size = UDim2.fromOffset(240, 22)
	hintLabel.BackgroundTransparency = 1
	hintLabel.Font = Theme.FontBody
	hintLabel.TextSize = 15
	hintLabel.TextColor3 = Theme.Colors.TextMuted
	hintLabel.TextXAlignment = Enum.TextXAlignment.Right
	hintLabel.Text = ""
	hintLabel.Parent = panel

	tapButton.Activated:Connect(advance)

	gui.Parent = player:WaitForChild("PlayerGui")
end

return DialogueController
