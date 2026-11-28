-- A loja, aberta pelo balcão da praça.
--
-- Só personalização de pet por enquanto. A lista vem de ShopConfig, então
-- item novo é uma linha de configuração, não tela nova.
--
-- Quem já comprou vê "Vestir" no lugar do preço; tocar de novo tira a peça.
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ShopConfig = require(Shared.Config.ShopConfig)
local Theme = require(Shared.UI.Theme)
local Localization = require(Shared.Util.Localization)
local Remotes = require(Shared.Remotes)

local player = Players.LocalPlayer

local ShopController = {}

local gui: ScreenGui
local painel: Frame
local moedasLabel: TextLabel
local lista: ScrollingFrame
local abas: Frame
local aviso: TextLabel

local categoriaAtual = "cor"
local carteira = 0
local comprados: { [string]: boolean } = {}
local equipados: { [string]: string } = {}

local function num(v: number): string
	return tostring(math.floor((v or 0) + 0.5))
end

local function arredondar(alvo, raio)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, raio)
	c.Parent = alvo
	return c
end

local function rotulo(nome, pai, texto, tamanho, cor, fonte)
	local l = Instance.new("TextLabel")
	l.Name = nome
	l.BackgroundTransparency = 1
	l.Font = fonte or Theme.FontBody
	l.TextSize = tamanho
	l.TextColor3 = cor or Theme.Colors.Text
	l.Text = texto
	l.Parent = pai
	return l
end

-- Amostra da cor ou do acessório, para o item não ser só um nome
local function amostra(pai: Instance, item)
	local caixa = Instance.new("Frame")
	caixa.Name = "Amostra"
	caixa.Size = UDim2.fromOffset(44, 44)
	caixa.Position = UDim2.fromOffset(10, 10)
	caixa.BorderSizePixel = 0
	caixa.BackgroundColor3 = Theme.Colors.Background
	caixa.Parent = pai
	arredondar(caixa, 10)

	local efeito = item.Efeito
	local bolinha = Instance.new("Frame")
	bolinha.AnchorPoint = Vector2.new(0.5, 0.5)
	bolinha.Position = UDim2.fromScale(0.5, 0.5)
	bolinha.Size = UDim2.fromOffset(28, 28)
	bolinha.BorderSizePixel = 0
	bolinha.BackgroundColor3 = (efeito.Cor or (efeito.Peca and efeito.Peca.Cor)) or Theme.Colors.Accent
	bolinha.Parent = caixa
	arredondar(bolinha, 14)
	if efeito.Tipo == "Brilho" then
		local anel = Instance.new("UIStroke")
		anel.Color = bolinha.BackgroundColor3
		anel.Thickness = 3
		anel.Transparency = 0.3
		anel.Parent = caixa
	end
	return caixa
end

local function desenhar()
	for _, c in lista:GetChildren() do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end

	moedasLabel.Text = Localization.Get(player, "Shop.Coins", { moedas = num(carteira) })

	local indice = 0
	for _, item in ShopConfig.Itens do
		if item.Categoria ~= categoriaAtual then
			continue
		end
		indice += 1
		local jaTem = comprados[item.Id] == true
		local vestido = equipados[item.Categoria] == item.Id

		local linha = Instance.new("Frame")
		linha.Name = item.Id
		linha.Size = UDim2.new(1, -8, 0, 64)
		linha.LayoutOrder = indice
		linha.BackgroundColor3 = Theme.Colors.Background
		linha.BackgroundTransparency = 0.2
		linha.BorderSizePixel = 0
		linha.Parent = lista
		arredondar(linha, 12)
		if vestido then
			local borda = Instance.new("UIStroke")
			borda.Color = Theme.Colors.Primary
			borda.Thickness = 2
			borda.Parent = linha
		end

		amostra(linha, item)

		local nome = rotulo("Nome", linha, Localization.Get(player, item.NomeChave), 17, Theme.Colors.Text, Theme.Font)
		nome.Size = UDim2.new(1, -190, 0, 22)
		nome.Position = UDim2.fromOffset(66, 12)
		nome.TextXAlignment = Enum.TextXAlignment.Left

		local estado = rotulo("Estado", linha,
			if vestido then Localization.Get(player, "Shop.Wearing")
			elseif jaTem then Localization.Get(player, "Shop.Owned")
			else Localization.Get(player, "Shop.Price", { moedas = num(item.Preco) }),
			14,
			if vestido then Theme.Colors.Primary elseif jaTem then Theme.Colors.TextMuted else Theme.Colors.Accent)
		estado.Size = UDim2.new(1, -190, 0, 18)
		estado.Position = UDim2.fromOffset(66, 34)
		estado.TextXAlignment = Enum.TextXAlignment.Left

		local botao = Instance.new("TextButton")
		botao.Name = "Acao"
		botao.AnchorPoint = Vector2.new(1, 0.5)
		botao.Position = UDim2.new(1, -10, 0.5, 0)
		botao.Size = UDim2.fromOffset(104, 42)
		botao.BorderSizePixel = 0
		botao.Font = Theme.Font
		botao.TextSize = 16
		botao.Parent = linha
		arredondar(botao, 10)

		if not jaTem then
			local dinheiro = carteira >= item.Preco
			botao.Text = Localization.Get(player, "Shop.Buy")
			botao.BackgroundColor3 = if dinheiro then Theme.Colors.Accent else Theme.Colors.Panel
			botao.TextColor3 = if dinheiro then Theme.Colors.Background else Theme.Colors.TextMuted
			botao.AutoButtonColor = dinheiro
			botao.Activated:Connect(function()
				(Remotes.Get("ShopBuy") :: RemoteEvent):FireServer(item.Id)
			end)
		else
			botao.Text = if vestido then Localization.Get(player, "Shop.Remove") else Localization.Get(player, "Shop.Wear")
			botao.BackgroundColor3 = if vestido then Theme.Colors.Panel else Theme.Colors.Primary
			botao.TextColor3 = if vestido then Theme.Colors.Text else Theme.Colors.Background
			botao.Activated:Connect(function()
				(Remotes.Get("ShopEquip") :: RemoteEvent):FireServer(item.Id)
			end)
		end
	end

	lista.CanvasSize = UDim2.fromOffset(0, indice * 72 + 8)
end

local function desenharAbas()
	for _, c in abas:GetChildren() do
		if c:IsA("TextButton") then
			c:Destroy()
		end
	end
	for indice, cat in ShopConfig.Categorias do
		local b = Instance.new("TextButton")
		b.Name = cat.Id
		b.Size = UDim2.fromOffset(120, 36)
		b.LayoutOrder = indice
		b.BorderSizePixel = 0
		b.Font = Theme.Font
		b.TextSize = 16
		b.Text = Localization.Get(player, cat.NomeChave)
		b.BackgroundColor3 = if cat.Id == categoriaAtual then Theme.Colors.Accent else Theme.Colors.Background
		b.TextColor3 = if cat.Id == categoriaAtual then Theme.Colors.Background else Theme.Colors.TextMuted
		b.Parent = abas
		arredondar(b, 10)
		b.Activated:Connect(function()
			categoriaAtual = cat.Id
			desenharAbas()
			desenhar()
		end)
	end
end

function ShopController:SetOpen(aberto: boolean)
	painel.Visible = aberto
	if aberto then
		desenharAbas()
		desenhar()
		painel.Position = UDim2.fromScale(0.5, 0.56)
		TweenService:Create(painel, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.fromScale(0.5, 0.5),
		}):Play()
	end
end

-- Construção ---------------------------------------------------------------------

function ShopController:Init()
	gui = Instance.new("ScreenGui")
	gui.Name = "ShopUI"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 45

	painel = Instance.new("Frame")
	painel.Name = "Painel"
	painel.AnchorPoint = Vector2.new(0.5, 0.5)
	painel.Position = UDim2.fromScale(0.5, 0.5)
	painel.Size = UDim2.fromOffset(520, 520)
	painel.BackgroundColor3 = Theme.Colors.Panel
	painel.BorderSizePixel = 0
	painel.Visible = false
	painel.Parent = gui
	arredondar(painel, 16)
	local borda = Instance.new("UIStroke")
	borda.Color = Theme.Colors.Accent
	borda.Thickness = 2
	borda.Parent = painel

	local titulo = rotulo("Titulo", painel, Localization.Get(player, "Shop.Title"), 24, Theme.Colors.Text, Theme.Font)
	titulo.Size = UDim2.new(1, -140, 0, 32)
	titulo.Position = UDim2.fromOffset(20, 16)
	titulo.TextXAlignment = Enum.TextXAlignment.Left

	moedasLabel = rotulo("Moedas", painel, "", 18, Theme.Colors.Accent, Theme.Font)
	moedasLabel.AnchorPoint = Vector2.new(1, 0)
	moedasLabel.Size = UDim2.fromOffset(180, 32)
	moedasLabel.Position = UDim2.new(1, -56, 0, 16)
	moedasLabel.TextXAlignment = Enum.TextXAlignment.Right

	local fechar = Instance.new("TextButton")
	fechar.Name = "Fechar"
	fechar.AnchorPoint = Vector2.new(1, 0)
	fechar.Position = UDim2.new(1, -14, 0, 14)
	fechar.Size = UDim2.fromOffset(36, 36)
	fechar.BackgroundColor3 = Theme.Colors.Background
	fechar.BorderSizePixel = 0
	fechar.Font = Theme.Font
	fechar.TextSize = 20
	fechar.TextColor3 = Theme.Colors.Text
	fechar.Text = "X"
	fechar.Parent = painel
	arredondar(fechar, 10)
	fechar.Activated:Connect(function()
		painel.Visible = false
	end)

	abas = Instance.new("Frame")
	abas.Name = "Abas"
	abas.Position = UDim2.fromOffset(20, 60)
	abas.Size = UDim2.new(1, -40, 0, 36)
	abas.BackgroundTransparency = 1
	abas.Parent = painel
	local layoutAbas = Instance.new("UIListLayout")
	layoutAbas.FillDirection = Enum.FillDirection.Horizontal
	layoutAbas.Padding = UDim.new(0, 8)
	layoutAbas.SortOrder = Enum.SortOrder.LayoutOrder
	layoutAbas.Parent = abas

	lista = Instance.new("ScrollingFrame")
	lista.Name = "Lista"
	lista.Position = UDim2.fromOffset(20, 108)
	lista.Size = UDim2.new(1, -40, 1, -164)
	lista.BackgroundTransparency = 1
	lista.BorderSizePixel = 0
	lista.ScrollBarThickness = 5
	lista.Parent = painel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = lista

	aviso = rotulo("Aviso", painel, "", 15, Theme.Colors.Danger)
	aviso.AnchorPoint = Vector2.new(0.5, 1)
	aviso.Position = UDim2.new(0.5, 0, 1, -14)
	aviso.Size = UDim2.new(1, -40, 0, 24)

	Theme.ApplyScale(painel)
	gui.Parent = player:WaitForChild("PlayerGui")
end

function ShopController:Start()
	(Remotes.Get("ShopUpdate") :: RemoteEvent).OnClientEvent:Connect(function(dados)
		carteira = dados.Coins or 0
		comprados = dados.Comprados or {}
		equipados = dados.Equipados or {}
		if painel.Visible then
			desenhar()
		end
	end)

	;(Remotes.Get("ShopResult") :: RemoteEvent).OnClientEvent:Connect(function(dados)
		if dados.Erro == "semMoedas" then
			aviso.Text = Localization.Get(player, "Shop.NoCoins")
			task.delay(2.5, function()
				aviso.Text = ""
			end)
		elseif dados.Comprado then
			aviso.Text = ""
		end
	end)

	;(Remotes.Get("WalletUpdate") :: RemoteEvent).OnClientEvent:Connect(function(dados)
		carteira = dados.Coins or carteira
		if painel.Visible then
			desenhar()
		end
	end)

	-- abre pelo balcão da praça
	ProximityPromptService.PromptTriggered:Connect(function(prompt, quemAcionou)
		if quemAcionou == player and prompt.Name == "LojaPrompt" then
			ShopController:SetOpen(true)
		end
	end)
end

return ShopController
