-- Criaturas selvagens no mundo: nascimento, ronda, desafio e desfecho.
--
-- Elas nascem nos marcos que o cenário já traz (Regions.<Região>.Marcos,
-- atributo Tipo = "Spawn"). Enquanto ninguém chega perto, a criatura anda
-- em volta do próprio marco. Quando um jogador com equipe se aproxima, ela
-- encara e a batalha começa.
--
-- Quem desmaia a criatura e a captura faz ela sumir; quem só recolhe os
-- espólios deixa ela no lugar, e ela se recompõe depois de um tempo.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BattleConfig = require(Shared.Config.BattleConfig)
local CreatureConfig = require(Shared.Config.CreatureConfig)
local WorldConfig = require(Shared.Config.WorldConfig)

local Services = script.Parent
local BattleService = require(Services.BattleService)

local WildService = {}

local PASSEIO_RAIO = 9 -- de quanto ela se afasta do marco passeando
local PASSEIO_VELOCIDADE = 3.5
local GIRO = 2.5
local PROBE_UP, PROBE_DOWN = 10, 60

type Selvagem = {
	modelo: Model,
	marco: Vector3,
	speciesId: string,
	nivel: number,
	alvo: Vector3,
	frente: Vector3,
	fase: number,
	solaOffset: number,
	corpo: BasePart,
	pecas: { { parte: BasePart, repouso: CFrame, pivo: Vector3, grupo: string } },
	ocupada: Player?,
	renascerEm: number?,
}

local selvagens: { Selvagem } = {}

local raioParams = RaycastParams.new()
raioParams.FilterType = Enum.RaycastFilterType.Exclude
raioParams.RespectCanCollide = true

local function chaoEm(x: number, z: number, deY: number, ignorar: { Instance }): number?
	raioParams.FilterDescendantsInstances = ignorar
	local hit = workspace:Raycast(Vector3.new(x, deY + PROBE_UP, z), Vector3.new(0, -PROBE_DOWN, 0), raioParams)
	return hit and hit.Position.Y or nil
end

-- Modelo -----------------------------------------------------------------------

local GRUPOS = {
	Cabeca = "cabeca",
	Cauda = "cauda",
	TailGlow = "cauda",
	PatasFrente = "frente",
	PatasTras = "tras",
}

local function montarRig(model: Model, corpo: BasePart)
	local pecas = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d ~= corpo then
			local grupo = GRUPOS[d.Name]
			if grupo then
				local px, py, pz = d:GetAttribute("PivoX"), d:GetAttribute("PivoY"), d:GetAttribute("PivoZ")
				local pivo
				if px and py and pz then
					pivo = Vector3.new(px, py, pz)
				else
					local sinal = if grupo == "frente" or grupo == "tras" then 1 else -1
					pivo = corpo.CFrame:PointToObjectSpace(d.Position + Vector3.new(0, (d.Size.Y / 2) * sinal, 0))
				end
				table.insert(pecas, {
					parte = d,
					repouso = corpo.CFrame:ToObjectSpace(d.CFrame),
					pivo = pivo,
					grupo = grupo,
				})
			end
		end
	end
	return pecas
end

local function construir(speciesId: string): Model?
	local species = CreatureConfig.Get(speciesId)
	local nome = (species and species.ModelName) or speciesId
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local pets = assets and assets:FindFirstChild("Pets")
	local fonte = pets and pets:FindFirstChild(nome)
	if not (fonte and fonte:IsA("Model")) then
		warn("[WildService] modelo não encontrado:", nome)
		return nil
	end
	local model = fonte:Clone()
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			-- precisa responder a clique, por isso CanQuery fica ligado
			d.CanQuery = true
			d.CanTouch = false
		end
	end
	if not model.PrimaryPart then
		model.PrimaryPart = model:FindFirstChild("Corpo") or model:FindFirstChildWhichIsA("BasePart", true)
	end
	return model
end

local function aplicarPose(s: Selvagem, corpoCF: CFrame, rotacoes: { [string]: CFrame })
	s.corpo.CFrame = corpoCF
	for _, peca in s.pecas do
		local rot = rotacoes[peca.grupo]
		if rot then
			local pivo = CFrame.new(peca.pivo)
			peca.parte.CFrame = corpoCF * pivo * rot * pivo:Inverse() * peca.repouso
		else
			peca.parte.CFrame = corpoCF * peca.repouso
		end
	end
end

-- Nascimento ----------------------------------------------------------------------

local function nascer(marco: Vector3, speciesId: string, nivel: number): Selvagem?
	local model = construir(speciesId)
	if not model then
		return nil
	end
	local corpo = model.PrimaryPart
	if not corpo then
		model:Destroy()
		return nil
	end

	model.Name = "Selvagem_" .. speciesId
	model:SetAttribute("SpeciesId", speciesId)
	model:SetAttribute("Nivel", nivel)
	model:SetAttribute("Selvagem", true)

	local pecas = montarRig(model, corpo)
	local cf, tam = model:GetBoundingBox()
	local solaOffset = corpo.Position.Y - (cf.Position.Y - tam.Y / 2)

	local chao = chaoEm(marco.X, marco.Z, marco.Y, {}) or marco.Y
	model.Parent = workspace

	local s: Selvagem = {
		modelo = model,
		marco = marco,
		speciesId = speciesId,
		nivel = nivel,
		alvo = marco,
		frente = Vector3.new(0, 0, 1),
		fase = 0,
		solaOffset = solaOffset,
		corpo = corpo,
		pecas = pecas,
		ocupada = nil,
		renascerEm = nil,
	}
	aplicarPose(s, CFrame.new(marco.X, chao + solaOffset, marco.Z), {})
	table.insert(selvagens, s)
	return s
end

-- Cliques: é assim que o jogador ataca. Um ClickDetector por peça seria
-- exagero, então um só, no corpo, com alcance curto.
local function ligarToque(s: Selvagem)
	local detector = Instance.new("ClickDetector")
	detector.MaxActivationDistance = BattleConfig.EngageDistance
	detector.Parent = s.corpo
	detector.MouseClick:Connect(function(player)
		if s.ocupada == player and BattleService:EstaEmBatalha(player) then
			local remote = require(Shared.Remotes).Get("BattleAttack") :: RemoteEvent
			-- o clique no mundo vale como toque: o cliente também manda o seu,
			-- e o servidor limita o ritmo, então não há golpe dobrado
			remote:FireServer()
		end
	end)
end

-- Ronda e desafio ----------------------------------------------------------------------

local function novoDestino(s: Selvagem)
	local angulo = math.random() * math.pi * 2
	local raio = math.random() * PASSEIO_RAIO
	s.alvo = s.marco + Vector3.new(math.cos(angulo) * raio, 0, math.sin(angulo) * raio)
end

local function desmaio(s: Selvagem)
	-- tomba de lado e afunda um pouco
	local atual = s.corpo.CFrame
	local tombada = atual * CFrame.Angles(0, 0, math.rad(78)) - Vector3.new(0, 0.35, 0)
	local info = TweenInfo.new(BattleConfig.FaintDuration * 0.5, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	TweenService:Create(s.corpo, info, { CFrame = tombada }):Play()
	for _, peca in s.pecas do
		TweenService:Create(peca.parte, info, { CFrame = tombada * peca.repouso }):Play()
	end
end

local function envolverEmEnergia(s: Selvagem, aoTerminar: () -> ())
	local centro = s.corpo.Position
	local efeitos = Instance.new("Folder")
	efeitos.Name = "Captura"
	efeitos.Parent = workspace

	local casulo = Instance.new("Part")
	casulo.Name = "Casulo"
	casulo.Anchored = true
	casulo.CanCollide = false
	casulo.CanQuery = false
	casulo.Shape = Enum.PartType.Ball
	casulo.Material = Enum.Material.Neon
	casulo.Color = Color3.fromRGB(150, 220, 255)
	casulo.Transparency = 0.6
	casulo.Size = Vector3.new(0.5, 0.5, 0.5)
	casulo.CFrame = CFrame.new(centro)
	casulo.Parent = efeitos

	local luz = Instance.new("PointLight")
	luz.Color = casulo.Color
	luz.Range = 14
	luz.Brightness = 2
	luz.Parent = casulo

	local metade = BattleConfig.CaptureDuration * 0.45
	TweenService:Create(casulo, TweenInfo.new(metade, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(5.5, 5.5, 5.5),
		Transparency = 0.35,
	}):Play()

	-- anéis subindo, para a energia parecer puxar o bicho para cima
	for i = 1, 4 do
		task.delay(i * 0.12, function()
			if not efeitos.Parent then
				return
			end
			local anel = Instance.new("Part")
			anel.Anchored = true
			anel.CanCollide = false
			anel.CanQuery = false
			anel.Shape = Enum.PartType.Cylinder
			anel.Material = Enum.Material.Neon
			anel.Color = Color3.fromRGB(190, 240, 255)
			anel.Transparency = 0.3
			anel.Size = Vector3.new(0.3, 6, 6)
			anel.CFrame = CFrame.new(centro - Vector3.new(0, 1.5, 0)) * CFrame.Angles(0, 0, math.rad(90))
			anel.Parent = efeitos
			TweenService:Create(anel, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				CFrame = CFrame.new(centro + Vector3.new(0, 5, 0)) * CFrame.Angles(0, 0, math.rad(90)),
				Size = Vector3.new(0.3, 1, 1),
				Transparency = 1,
			}):Play()
		end)
	end

	task.delay(metade, function()
		if not efeitos.Parent then
			return
		end
		-- o casulo encolhe levando o bicho junto
		TweenService:Create(casulo, TweenInfo.new(BattleConfig.CaptureDuration - metade,
			Enum.EasingStyle.Quint, Enum.EasingDirection.In), {
			Size = Vector3.new(0.2, 0.2, 0.2),
			Transparency = 1,
		}):Play()
		for _, d in s.modelo:GetDescendants() do
			if d:IsA("BasePart") then
				TweenService:Create(d, TweenInfo.new(BattleConfig.CaptureDuration - metade), { Transparency = 1 }):Play()
			end
		end
	end)

	task.delay(BattleConfig.CaptureDuration + 0.2, function()
		efeitos:Destroy()
		aoTerminar()
	end)
end

local function sumir(s: Selvagem)
	for indice, outro in selvagens do
		if outro == s then
			table.remove(selvagens, indice)
			break
		end
	end
	local marco, speciesId, nivel = s.marco, s.speciesId, s.nivel
	if s.modelo then
		s.modelo:Destroy()
	end
	task.delay(BattleConfig.RespawnDelay, function()
		local nova = nascer(marco, speciesId, math.random(nivel, nivel + 1))
		if nova then
			ligarToque(nova)
		end
	end)
end

local function atualizar(dt: number)
	for _, s in selvagens do
		local model = s.modelo
		if not (model and model.Parent) then
			continue
		end

		-- resolvida pelo BattleService: capturada some, derrotada se refaz
		if model:GetAttribute("Resolvida") ~= nil then
			local capturada = model:GetAttribute("Resolvida") == true
			model:SetAttribute("Resolvida", nil)
			s.ocupada = nil
			if capturada then
				envolverEmEnergia(s, function()
					sumir(s)
				end)
			else
				-- não foi capturada: levanta e volta a rondar
				model:SetAttribute("EmBatalha", false)
			end
			continue
		end

		if model:GetAttribute("EmBatalha") == true then
			-- parada, encarando quem desafiou
			local jogador = s.ocupada
			local root = jogador and jogador.Character and jogador.Character:FindFirstChild("HumanoidRootPart")
			if root then
				local para = Vector3.new(root.Position.X - s.corpo.Position.X, 0, root.Position.Z - s.corpo.Position.Z)
				if para.Magnitude > 0.5 then
					s.frente = s.frente:Lerp(para.Unit, math.clamp(dt * GIRO, 0, 1)).Unit
				end
			end
			s.fase += dt * 3
			local pos = s.corpo.Position
			local corpoCF = CFrame.lookAt(pos, pos + s.frente)
			aplicarPose(s, corpoCF, {
				cauda = CFrame.Angles(0, math.sin(s.fase * 2) * 0.5, 0),
				cabeca = CFrame.Angles(math.sin(s.fase) * 0.05, 0, 0),
			})
			continue
		end

		-- 1. desafia quem chegar perto com equipe
		for _, player in Players:GetPlayers() do
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if root and not BattleService:EstaEmBatalha(player) then
				if (root.Position - s.corpo.Position).Magnitude <= BattleConfig.EngageDistance then
					if BattleService:Comecar(player, model) then
						s.ocupada = player
						break
					end
				end
			end
		end
		if s.ocupada then
			continue
		end

		-- 2. ronda
		local pos = s.corpo.Position
		local para = Vector3.new(s.alvo.X - pos.X, 0, s.alvo.Z - pos.Z)
		if para.Magnitude < 1.5 then
			novoDestino(s)
			para = Vector3.new(s.alvo.X - pos.X, 0, s.alvo.Z - pos.Z)
		end
		local andou = 0
		local x, z = pos.X, pos.Z
		if para.Magnitude > 0.1 then
			local dir = para.Unit
			andou = math.min(PASSEIO_VELOCIDADE * dt, para.Magnitude)
			x += dir.X * andou
			z += dir.Z * andou
			s.frente = s.frente:Lerp(dir, math.clamp(dt * GIRO, 0, 1)).Unit
		end
		local chao = chaoEm(x, z, pos.Y, { model }) or (pos.Y - s.solaOffset)
		local y = chao + s.solaOffset

		s.fase += dt * (2 + andou / math.max(dt, 0.001) * 0.35)
		local mexendo = if andou > 0.01 then 1 else 0
		local passada = 0.3 * mexendo
		local corpoCF = CFrame.lookAt(Vector3.new(x, y + math.sin(s.fase * 2) * 0.05 * mexendo, z),
			Vector3.new(x, y, z) + s.frente)
		aplicarPose(s, corpoCF, {
			frente = CFrame.Angles(math.sin(s.fase) * passada, 0, 0),
			tras = CFrame.Angles(-math.sin(s.fase) * passada, 0, 0),
			cauda = CFrame.Angles(0, math.sin(s.fase * 0.8) * 0.3, 0),
		})
	end
end

-- Desfecho vindo do BattleService -----------------------------------------------------

local function observarDesmaio()
	-- a criatura tomba assim que a vida zera; o BattleService marca isso
	-- pelo atributo EmBatalha continuar e a vida ter acabado, então o sinal
	-- vem por atributo para não acoplar os dois serviços
	for _, s in selvagens do
		local model = s.modelo
		if model and model.Parent and model:GetAttribute("Desmaiada") == true then
			model:SetAttribute("Desmaiada", nil)
			desmaio(s)
		end
	end
end

function WildService:Start()
	-- nasce uma criatura em cada marco de spawn das regiões que têm tabela
	local regioes = workspace:FindFirstChild(WorldConfig.RegionsFolder)
	if regioes then
		for regiaoId, lista in BattleConfig.WildSpawns do
			local regiao = regioes:FindFirstChild(regiaoId)
			local marcos = regiao and regiao:FindFirstChild("Marcos")
			if marcos then
				for _, marco in marcos:GetChildren() do
					if marco:GetAttribute("Tipo") == "Spawn" then
						local escolha = lista[math.random(1, #lista)]
						local nivel = math.random(escolha.Nivel[1], escolha.Nivel[2])
						local s = nascer(marco.Position, escolha.SpeciesId, nivel)
						if s then
							ligarToque(s)
						end
					end
				end
			end
		end
	end

	RunService.Heartbeat:Connect(function(dt)
		atualizar(math.min(dt, 1 / 20))
		observarDesmaio()
	end)
end

return WildService
