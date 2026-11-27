-- Tela de carregamento: aparece até o servidor terminar de carregar o perfil.
-- Também serve de teste da Fase 1 (escala mobile + tradução + dados).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared.UI.Theme)
local Localization = require(Shared.Util.Localization)

local player = Players.LocalPlayer

local LoadingController = {}

local gui: ScreenGui
local label: TextLabel

function LoadingController:Init()
	gui = Instance.new("ScreenGui")
	gui.Name = "LoadingUI"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 100

	local background = Instance.new("Frame")
	background.Name = "Background"
	background.Size = UDim2.fromScale(1, 1)
	background.BackgroundColor3 = Theme.Colors.Background
	background.BorderSizePixel = 0
	background.Parent = gui

	local content = Instance.new("Frame")
	content.Name = "Content"
	content.AnchorPoint = Vector2.new(0.5, 0.5)
	content.Position = UDim2.fromScale(0.5, 0.5)
	content.Size = UDim2.fromOffset(600, 200)
	content.BackgroundTransparency = 1
	content.Parent = background
	Theme.ApplyScale(content)

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 80)
	title.BackgroundTransparency = 1
	title.Font = Theme.Font
	title.TextSize = 56
	title.TextColor3 = Theme.Colors.Primary
	title.Text = "ATLAS"
	title.Parent = content

	label = Instance.new("TextLabel")
	label.Name = "Status"
	label.Position = UDim2.fromOffset(0, 96)
	label.Size = UDim2.new(1, 0, 0, 40)
	label.BackgroundTransparency = 1
	label.Font = Theme.FontBody
	label.TextSize = 28
	label.TextColor3 = Theme.Colors.TextMuted
	label.Text = Localization.Get(player, "UI.Loading")
	label.Parent = content

	gui.Parent = player:WaitForChild("PlayerGui")
end

local function hide()
	label.Text = Localization.Get(player, "UI.Welcome")
	task.wait(1)
	local fade = TweenInfo.new(0.5)
	for _, descendant in gui:GetDescendants() do
		if descendant:IsA("TextLabel") then
			TweenService:Create(descendant, fade, { TextTransparency = 1 }):Play()
		elseif descendant:IsA("Frame") and descendant.BackgroundTransparency < 1 then
			TweenService:Create(descendant, fade, { BackgroundTransparency = 1 }):Play()
		end
	end
	task.wait(0.5)
	gui:Destroy()
end

function LoadingController:Start()
	if not player:GetAttribute("ProfileLoaded") then
		player:GetAttributeChangedSignal("ProfileLoaded"):Wait()
	end
	hide()
end

return LoadingController
