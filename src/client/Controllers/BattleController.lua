-- A tela da batalha.
--
-- O jogador toca na criatura selvagem — na tela ou no próprio bicho no
-- mundo — e o pet da vez ataca. Nada acontece sozinho do lado dele.
--
-- Mostra a energia da criatura em cima dela e a energia de cada pet da
-- equipe num canto, para o jogador saber se está ganhando ou apanhando.
--
-- Terminada a luta, aparecem DUAS opções, não uma sequência: recolher os
-- espólios e capturar. Dá para fazer as duas, em qualquer ordem.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CreatureConfig = require(Shared.Config.CreatureConfig)
local Theme = require(Shared.UI.Theme)
local Localization = require(Shared.Util.Localization)
local Remotes = require(Shared.Remotes)

local player = Players.LocalPlayer

local BattleController = {}

local ALCANCE_DESAFIO = 18 -- igual a BattleConfig.ChallengeDistance

local gui: ScreenGui
local alvoQuadro: Frame -- barra da criatura, no alto
local alvoNome: TextLabel
local alvoBarra: Frame
local alvoVida: TextLabel
local dica: TextLabel
local botaoAtacar: TextButton
local botaoDesafiar: TextButton
local alvoProximo: Model? = nil
local equipeQuadro: Frame
local resultado: Frame
local resultadoTitulo: TextLabel
local espolioLista: Frame
local botaoEspolio: TextButton
local botaoCapturar: TextButton
local botaoSair: TextButton

local barrasDaEquipe: { [number]: { fundo: Frame, barra: Frame, texto: TextLabel, nome: TextLabel } } = {}
local emBatalha = false
local cameraConn: RBXScriptConnection? = nil
local zoomAnterior: number? = nil
local estadoAtual: any = nil
local espolioAtual: any = nil

-- Helpers ------------------------------------------------------------------------

local function num(v: number): string
	return tostring(math.floor(v + 0.5))
end

local function nomeDaEspecie(speciesId: string): string
	local species = CreatureConfig.Get(speciesId)
	return if species then Localization.Get(player, species.NameKey) else speciesId
end

local function corDaVida(razao: number): Color3
	if razao > 0.5 then
		return Color3.fromRGB(96, 200, 120)
	elseif razao > 0.22 then
		return Color3.fromRGB(240, 196, 80)
	end
	return Color3.fromRGB(232, 92, 92)
end

local function frame(nome, pai, cor)
	local f = Instance.new("Frame")
	f.Name = nome
	f.BackgroundColor3 = cor or Theme.Colors.Panel
	f.BackgroundTransparency = if cor then 0 else 1
	f.BorderSizePixel = 0
	f.Parent = pai
	return f
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

local function arredondar(gui_, raio)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, raio)
	c.Parent = gui_
	return c
end

-- Número de dano subindo --------------------------------------------------------------

local function mostrarDano(dano: number, ondeX: number, ondeY: number, cor: Color3)
	local l = Instance.new("TextLabel")
	l.AnchorPoint = Vector2.new(0.5, 0.5)
	l.Position = UDim2.fromScale(ondeX, ondeY)
	l.Size = UDim2.fromOffset(120, 46)
	l.BackgroundTransparency = 1
	l.Font = Theme.Font
	l.TextSize = 36
	l.TextColor3 = cor
	l.TextStrokeTransparency = 0.4
	l.Text = "-" .. num(dano)
	l.Parent = gui

	TweenService:Create(l, TweenInfo.new(0.85, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.fromScale(ondeX, ondeY - 0.09),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	}):Play()
	task.delay(0.9, function()
		l:Destroy()
	end)
end

-- Desenho -------------------------------------------------------------------------------

local function desenharEquipe(estado)
	for _, item in barrasDaEquipe do
		item.fundo:Destroy()
	end
	table.clear(barrasDaEquipe)

	for indice, lutador in estado.Equipe do
		local linha = frame("Lutador" .. indice, equipeQuadro, Theme.Colors.Panel)
		linha.Size = UDim2.new(1, 0, 0, 44)
		linha.Position = UDim2.fromOffset(0, (indice - 1) * 50)
		linha.BackgroundTransparency = 0.12
		arredondar(linha, 10)

		local nome = rotulo("Nome", linha, nomeDaEspecie(lutador.SpeciesId), 15, Theme.Colors.Text, Theme.Font)
		nome.Size = UDim2.new(1, -16, 0, 18)
		nome.Position = UDim2.fromOffset(10, 4)
		nome.TextXAlignment = Enum.TextXAlignment.Left

		local trilho = frame("Trilho", linha, Theme.Colors.Background)
		trilho.Size = UDim2.new(1, -78, 0, 10)
		trilho.Position = UDim2.fromOffset(10, 26)
		arredondar(trilho, 5)

		local razao = lutador.Vida / math.max(lutador.VidaMax, 1)
		local barra = frame("Barra", trilho, corDaVida(razao))
		barra.Size = UDim2.fromScale(math.clamp(razao, 0, 1), 1)
		arredondar(barra, 5)

		local texto = rotulo("Vida", linha, num(lutador.Vida) .. "/" .. num(lutador.VidaMax), 13, Theme.Colors.TextMuted)
		texto.AnchorPoint = Vector2.new(1, 0)
		texto.Size = UDim2.fromOffset(62, 18)
		texto.Position = UDim2.new(1, -8, 0, 22)
		texto.TextXAlignment = Enum.TextXAlignment.Right

		barrasDaEquipe[lutador.Slot] = { fundo = linha, barra = barra, texto = texto, nome = nome }
	end
	equipeQuadro.Size = UDim2.fromOffset(240, #estado.Equipe * 50)
end

local function atualizarEstado(estado)
	estadoAtual = estado

	alvoNome.Text = string.format("%s  ·  %s", nomeDaEspecie(estado.Selvagem.SpeciesId),
		Localization.Get(player, "Battle.Level", { level = num(estado.Selvagem.Nivel) }))

	local razao = estado.Selvagem.Vida / math.max(estado.Selvagem.VidaMax, 1)
	TweenService:Create(alvoBarra, TweenInfo.new(0.25), {
		Size = UDim2.fromScale(math.clamp(razao, 0, 1), 1),
		BackgroundColor3 = corDaVida(razao),
	}):Play()
	alvoVida.Text = num(estado.Selvagem.Vida) .. "/" .. num(estado.Selvagem.VidaMax)

	for _, lutador in estado.Equipe do
		local item = barrasDaEquipe[lutador.Slot]
		if item then
			local r = lutador.Vida / math.max(lutador.VidaMax, 1)
			TweenService:Create(item.barra, TweenInfo.new(0.25), {
				Size = UDim2.fromScale(math.clamp(r, 0, 1), 1),
				BackgroundColor3 = corDaVida(r),
			}):Play()
			item.texto.Text = num(lutador.Vida) .. "/" .. num(lutador.VidaMax)
			item.fundo.BackgroundTransparency = if lutador.Vida > 0 then 0.12 else 0.6
		end
	end
end

-- Espólio ---------------------------------------------------------------------------------

local function listarEspolio(espolio)
	for _, c in espolioLista:GetChildren() do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	if not espolio then
		return
	end

	local itens = {}
	if espolio.Moedas and espolio.Moedas > 0 then
		table.insert(itens, { chave = "Material.Coins", quantidade = espolio.Moedas })
	end
	for id, quantidade in (espolio.Materiais or {}) do
		table.insert(itens, { chave = "Material." .. id, quantidade = quantidade })
	end

	for indice, item in itens do
		local linha = frame("Item" .. indice, espolioLista, Theme.Colors.Background)
		linha.Size = UDim2.new(1, 0, 0, 28)
		linha.LayoutOrder = indice
		linha.BackgroundTransparency = 0.25
		arredondar(linha, 8)

		local nome = rotulo("Nome", linha, Localization.Get(player, item.chave), 15, Theme.Colors.Text)
		nome.Size = UDim2.new(1, -70, 1, 0)
		nome.Position = UDim2.fromOffset(10, 0)
		nome.TextXAlignment = Enum.TextXAlignment.Left

		local qtd = rotulo("Qtd", linha, "x" .. num(item.quantidade), 15, Theme.Colors.Accent, Theme.Font)
		qtd.AnchorPoint = Vector2.new(1, 0)
		qtd.Size = UDim2.fromOffset(56, 28)
		qtd.Position = UDim2.new(1, -10, 0, 0)
		qtd.TextXAlignment = Enum.TextXAlignment.Right
	end
	espolioLista.Size = UDim2.new(1, 0, 0, #itens * 32)
end


-- Câmera de combate -------------------------------------------------------------

-- Enquadra o jogador e a criatura ao mesmo tempo, de lado, como num duelo.
-- Com a câmera normal (atrás da nuca) o bicho saía do quadro e não dava
-- para ver golpe nenhum.
local function acharAlvoNoMundo(): Model?
	for _, d in workspace:GetChildren() do
		if d:IsA("Model") and d:GetAttribute("EmBatalha") == true then
			return d
		end
	end
	return nil
end

local function ligarCamera()
	if cameraConn then
		return
	end
	local camera = workspace.CurrentCamera
	zoomAnterior = player.CameraMaxZoomDistance
	camera.CameraType = Enum.CameraType.Scriptable

	local suave = camera.CFrame
	cameraConn = RunService.RenderStepped:Connect(function(dt)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local alvo = acharAlvoNoMundo()
		if not (root and alvo) then
			return
		end
		local a = root.Position
		local b = alvo:GetPivot().Position
		local meio = (a + b) / 2 + Vector3.new(0, 2.2, 0)
		local entre = b - a
		local distancia = math.max(entre.Magnitude, 6)
		-- de lado, perpendicular à linha entre os dois
		local lado = Vector3.new(entre.Z, 0, -entre.X)
		if lado.Magnitude < 0.1 then
			lado = Vector3.new(1, 0, 0)
		end
		lado = lado.Unit
		local recuo = math.clamp(distancia * 1.25 + 9, 14, 30)
		local desejada = CFrame.lookAt(meio + lado * recuo + Vector3.new(0, distancia * 0.35 + 4, 0), meio)
		suave = suave:Lerp(desejada, math.clamp(dt * 3, 0, 1))
		camera.CFrame = suave
	end)
end

local function desligarCamera()
	if cameraConn then
		cameraConn:Disconnect()
		cameraConn = nil
	end
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Custom
	if zoomAnterior then
		player.CameraMaxZoomDistance = zoomAnterior
		zoomAnterior = nil
	end
end


-- Procura de alvo ---------------------------------------------------------------

-- O cliente só decide o que DESENHAR; quem confere a distância de verdade
-- e começa a luta é o servidor.
local function procurarAlvo()
	if emBatalha then
		botaoDesafiar.Visible = false
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		botaoDesafiar.Visible = false
		return
	end

	local melhor, melhorDist = nil, ALCANCE_DESAFIO
	for _, d in workspace:GetChildren() do
		if d:IsA("Model") and d:GetAttribute("Selvagem") and not d:GetAttribute("EmBatalha") then
			local dist = (d:GetPivot().Position - root.Position).Magnitude
            if dist <= melhorDist then
				melhor, melhorDist = d, dist
			end
		end
	end

	alvoProximo = melhor
	if melhor then
		local species = CreatureConfig.Get(melhor:GetAttribute("SpeciesId") or "")
		local nome = if species then Localization.Get(player, species.NameKey) else "?"
		botaoDesafiar.Text = string.format("%s  %s", Localization.Get(player, "Battle.Challenge"), nome)
	end
	botaoDesafiar.Visible = melhor ~= nil
end

-- Começo e fim ----------------------------------------------------------------------------

local function abrir(estado)
	emBatalha = true
	botaoDesafiar.Visible = false
	ligarCamera()
	espolioAtual = nil
	resultado.Visible = false
	alvoQuadro.Visible = true
	equipeQuadro.Visible = true
	botaoAtacar.Visible = true
	botaoAtacar.Text = Localization.Get(player, "Battle.Attack")
	dica.Visible = true
	dica.Text = Localization.Get(player, "Battle.Tap")
	desenharEquipe(estado)
	atualizarEstado(estado)
end

local function fechar()
	emBatalha = false
	desligarCamera()
	resultado.Visible = false
	alvoQuadro.Visible = false
	equipeQuadro.Visible = false
	botaoAtacar.Visible = false
	dica.Visible = false
end

local function mostrarResultado(dados)
	alvoQuadro.Visible = dados.Resultado == "Vitoria"
	botaoAtacar.Visible = false
	dica.Visible = false
	espolioAtual = dados.Espolio

	local chave = if dados.Resultado == "Vitoria" then "Battle.Victory"
		elseif dados.Resultado == "Derrota" then "Battle.Defeat"
		else "Battle.Fled"
	resultadoTitulo.Text = Localization.Get(player, chave)

	listarEspolio(dados.Espolio)
	botaoEspolio.Visible = dados.Espolio ~= nil
	botaoEspolio.Text = Localization.Get(player, "Battle.Spoils")
	botaoEspolio.AutoButtonColor = true
	botaoEspolio.BackgroundColor3 = Theme.Colors.Accent

	botaoCapturar.Visible = dados.PodeCapturar == true
	botaoCapturar.Text = Localization.Get(player, "Battle.Capture")
	botaoCapturar.AutoButtonColor = true
	botaoCapturar.BackgroundColor3 = Theme.Colors.Primary

	resultado.Visible = true
	resultado.BackgroundTransparency = 1
	TweenService:Create(resultado, TweenInfo.new(0.35), { BackgroundTransparency = 0.05 }):Play()
end

-- Construção -----------------------------------------------------------------------------------

function BattleController:Init()
	gui = Instance.new("ScreenGui")
	gui.Name = "BattleUI"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 55
	-- fica sempre ligado: fora da batalha ele só mostra o botão de desafiar
	gui.Enabled = true

	-- Barra da criatura, no alto
	alvoQuadro = frame("Alvo", gui, Theme.Colors.Panel)
	alvoQuadro.AnchorPoint = Vector2.new(0.5, 0)
	alvoQuadro.Position = UDim2.new(0.5, 0, 0, 124)
	alvoQuadro.Size = UDim2.fromOffset(420, 66)
	alvoQuadro.BackgroundTransparency = 0.1
	arredondar(alvoQuadro, 12)

	alvoNome = rotulo("Nome", alvoQuadro, "", 19, Theme.Colors.Text, Theme.Font)
	alvoNome.Size = UDim2.new(1, -24, 0, 24)
	alvoNome.Position = UDim2.fromOffset(14, 6)
	alvoNome.TextXAlignment = Enum.TextXAlignment.Left

	local alvoTrilho = frame("Trilho", alvoQuadro, Theme.Colors.Background)
	alvoTrilho.Size = UDim2.new(1, -28, 0, 16)
	alvoTrilho.Position = UDim2.fromOffset(14, 36)
	arredondar(alvoTrilho, 8)
	alvoBarra = frame("Barra", alvoTrilho, Color3.fromRGB(96, 200, 120))
	alvoBarra.Size = UDim2.fromScale(1, 1)
	arredondar(alvoBarra, 8)
	alvoVida = rotulo("Vida", alvoQuadro, "", 14, Theme.Colors.Text, Theme.Font)
	alvoVida.AnchorPoint = Vector2.new(1, 0)
	alvoVida.Size = UDim2.fromOffset(110, 24)
	alvoVida.Position = UDim2.new(1, -16, 0, 6)
	alvoVida.TextXAlignment = Enum.TextXAlignment.Right

	-- Equipe, à esquerda
	equipeQuadro = frame("Equipe", gui)
	equipeQuadro.AnchorPoint = Vector2.new(0, 1)
	equipeQuadro.Position = UDim2.new(0, 20, 1, -150)
	equipeQuadro.Size = UDim2.fromOffset(240, 150)

	-- O botão de atacar era transparente e sem texto: quem jogava não
	-- tinha como saber onde tocar. Agora é um botão grande embaixo, no
	-- alcance do polegar, longe do joystick e do botão de pulo.
	botaoAtacar = Instance.new("TextButton")
	botaoAtacar.Name = "Atacar"
	botaoAtacar.AnchorPoint = Vector2.new(0.5, 1)
	botaoAtacar.Position = UDim2.new(0.5, 0, 1, -40)
	botaoAtacar.Size = UDim2.fromOffset(300, 78)
	botaoAtacar.BackgroundColor3 = Theme.Colors.Danger
	botaoAtacar.BorderSizePixel = 0
	botaoAtacar.Font = Theme.Font
	botaoAtacar.TextSize = 28
	botaoAtacar.TextColor3 = Color3.fromRGB(255, 255, 255)
	botaoAtacar.Text = ""
	botaoAtacar.AutoButtonColor = true
	botaoAtacar.Parent = gui
	arredondar(botaoAtacar, 16)
	local brilho = Instance.new("UIStroke")
	brilho.Color = Color3.fromRGB(255, 190, 190)
	brilho.Thickness = 2
	brilho.Parent = botaoAtacar

	-- Botão de desafiar: aparece quando há criatura perto e nenhuma luta
	-- em curso. O prompt no mundo continua valendo, mas no celular acertar
	-- uma plaquinha pequena no 3D é pior do que um botão fixo.
	botaoDesafiar = Instance.new("TextButton")
	botaoDesafiar.Name = "Desafiar"
	botaoDesafiar.AnchorPoint = Vector2.new(0.5, 1)
	botaoDesafiar.Position = UDim2.new(0.5, 0, 1, -40)
	botaoDesafiar.Size = UDim2.fromOffset(300, 72)
	botaoDesafiar.BackgroundColor3 = Theme.Colors.Accent
	botaoDesafiar.BorderSizePixel = 0
	botaoDesafiar.Font = Theme.Font
	botaoDesafiar.TextSize = 24
	botaoDesafiar.TextColor3 = Theme.Colors.Background
	botaoDesafiar.Text = ""
	botaoDesafiar.Visible = false
	botaoDesafiar.Parent = gui
	arredondar(botaoDesafiar, 14)

	dica = rotulo("Dica", gui, "", 17, Theme.Colors.TextMuted)
	dica.AnchorPoint = Vector2.new(0.5, 1)
	dica.Position = UDim2.new(0.5, 0, 1, -126)
	dica.Size = UDim2.fromOffset(460, 24)

	-- Painel de resultado
	resultado = frame("Resultado", gui, Theme.Colors.Panel)
	resultado.AnchorPoint = Vector2.new(0.5, 0.5)
	resultado.Position = UDim2.fromScale(0.5, 0.5)
	resultado.Size = UDim2.fromOffset(420, 360)
	resultado.BackgroundTransparency = 0.05
	resultado.Visible = false
	arredondar(resultado, 16)
	local borda = Instance.new("UIStroke")
	borda.Color = Theme.Colors.Accent
	borda.Thickness = 2
	borda.Parent = resultado

	resultadoTitulo = rotulo("Titulo", resultado, "", 26, Theme.Colors.Text, Theme.Font)
	resultadoTitulo.Size = UDim2.new(1, -32, 0, 36)
	resultadoTitulo.Position = UDim2.fromOffset(16, 18)

	espolioLista = frame("Espolio", resultado)
	espolioLista.Size = UDim2.new(1, -40, 0, 0)
	espolioLista.Position = UDim2.fromOffset(20, 64)
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = espolioLista

	local function botao(nome, y, cor)
		local b = Instance.new("TextButton")
		b.Name = nome
		b.AnchorPoint = Vector2.new(0.5, 1)
		b.Position = UDim2.new(0.5, 0, 1, y)
		b.Size = UDim2.fromOffset(360, Theme.MinTouchSize)
		b.BackgroundColor3 = cor
		b.BorderSizePixel = 0
		b.Font = Theme.Font
		b.TextSize = 20
		b.TextColor3 = Theme.Colors.Background
		b.Text = ""
		b.Parent = resultado
		arredondar(b, 12)
		return b
	end
	botaoEspolio = botao("Espolios", -144, Theme.Colors.Accent)
	botaoCapturar = botao("Capturar", -80, Theme.Colors.Primary)
	botaoSair = botao("Sair", -16, Theme.Colors.Background)
	botaoSair.TextColor3 = Theme.Colors.Text

	-- fora da batalha só o botão de desafiar pode aparecer
	alvoQuadro.Visible = false
	equipeQuadro.Visible = false
	botaoAtacar.Visible = false
	dica.Visible = false

	gui.Parent = player:WaitForChild("PlayerGui")
end

function BattleController:Start()
	local atacar = Remotes.Get("BattleAttack") :: RemoteEvent
	local escolher = Remotes.Get("BattleChoice") :: RemoteEvent
	local sair = Remotes.Get("BattleLeave") :: RemoteEvent

	botaoDesafiar.Activated:Connect(function()
		if alvoProximo then
			(Remotes.Get("BattleChallenge") :: RemoteEvent):FireServer(alvoProximo)
		end
	end)

	local acumulado = 0
	RunService.Heartbeat:Connect(function(dt)
		acumulado += dt
		if acumulado >= 0.3 then
			acumulado = 0
			procurarAlvo()
		end
	end)

	botaoAtacar.Activated:Connect(function()
		if emBatalha then
			atacar:FireServer()
		end
	end)

	botaoEspolio.Activated:Connect(function()
		escolher:FireServer("espolios")
	end)
	botaoCapturar.Activated:Connect(function()
		escolher:FireServer("capturar")
	end)
	botaoSair.Activated:Connect(function()
		sair:FireServer()
		fechar()
	end)

	;(Remotes.Get("BattleStart") :: RemoteEvent).OnClientEvent:Connect(abrir)

	;(Remotes.Get("BattleUpdate") :: RemoteEvent).OnClientEvent:Connect(function(pacote)
		if pacote.Estado then
			atualizarEstado(pacote.Estado)
		end
		if pacote.Golpe then
			local g = pacote.Golpe
			if g.De == "pet" then
				mostrarDano(g.Dano, 0.5, 0.26, Color3.fromRGB(255, 226, 150))
			else
				mostrarDano(g.Dano, 0.17, 0.74, Color3.fromRGB(255, 150, 150))
			end
		end
		if pacote.EspolioPego then
			botaoEspolio.Text = Localization.Get(player, "Battle.SpoilsTaken")
			botaoEspolio.AutoButtonColor = false
			botaoEspolio.BackgroundColor3 = Theme.Colors.TextMuted
		end
		if pacote.CapturaFeita then
			botaoCapturar.Text = Localization.Get(player, "Battle.Captured", {
				nome = nomeDaEspecie(estadoAtual and estadoAtual.Selvagem.SpeciesId or ""),
			})
			botaoCapturar.AutoButtonColor = false
			botaoCapturar.BackgroundColor3 = Theme.Colors.TextMuted
			alvoQuadro.Visible = false
		end
		if pacote.CapturaFalhou == "cheia" then
			botaoCapturar.Text = Localization.Get(player, "Battle.CollectionFull")
			botaoCapturar.AutoButtonColor = false
			botaoCapturar.BackgroundColor3 = Theme.Colors.Danger
		end
	end)

	;(Remotes.Get("BattleEnd") :: RemoteEvent).OnClientEvent:Connect(function(dados)
		botaoSair.Text = Localization.Get(player, "Battle.Leave")
		mostrarResultado(dados)
	end)
end

return BattleController
