-- Mostra no mundo os pets equipados e faz o primeiro deles seguir o jogador.
--
-- Fatia inicial da Fase 3 (AT-4): sem isso o tutorial entrega um pet que
-- ninguém vê. Segue só o pet do Slot 1 por enquanto.
--
-- Pet fatigado continua seguindo normalmente — a fadiga só bloqueia batalha.
--
-- Os modelos ficam no place, em ReplicatedStorage.Assets.Pets.<ModelName>,
-- fora do Rojo (ver CLAUDE.md).
--
-- Duas coisas que custaram caro para acertar, anotadas para não se perderem:
--
-- 1. O pet anda pelo CHÃO, não pela altura do dono. A posição vertical sai
--    de um raio lançado para baixo. Copiar o Y do jogador fazia o bicho
--    flutuar em ladeira e subir junto nos pulos.
--
-- 2. A FRENTE do modelo é o LookVector (o -Z local). Isso foi conferido
--    olhando o bicho renderizado, não deduzido: um marcador chamado
--    "TailGlow" fica perto da cabeça, e a segmentação automática trocou os
--    rótulos de cabeça e cauda. Com o sinal errado ele anda de costas.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CreatureConfig = require(Shared.Config.CreatureConfig)
local TeamUtil = require(Shared.Util.TeamUtil)

local Services = script.Parent
local PlayerDataService = require(Services.PlayerDataService)
local TeamService = require(Services.TeamService)

local PetService = {}

-- Onde ele tenta ficar
local FOLLOW_BACK = 4.5
local FOLLOW_SIDE = 2.0
local STOP_DISTANCE = 2.2
local CATCHUP_DISTANCE = 14
local TELEPORT_DISTANCE = 70

-- Velocidades (studs/s). Mais lento que o jogador andando e mais rápido
-- correndo: fica atrás na caminhada e alcança na corrida.
local WALK_SPEED = 13
local RUN_SPEED = 32
local TURN_SPEED = 9

-- Chão
local GROUND_SNAP = 14
local PROBE_UP = 12
local PROBE_DOWN = 60

-- Pulo
local STEP_UP_TRIGGER = 1.8
local JUMP_SPEED = 17
local GRAVITY = 62
local JUMP_COOLDOWN = 0.35

-- Passada. O modelo é dividido em corpo, cabeça, cauda e dois pares de
-- patas, então a caminhada é feita girando as peças — não quicando o bicho
-- inteiro, que era o que dava aquele saltitar estranho.
local PASSO_BASE = 2.2 -- cadência parada
local PASSO_POR_VELOCIDADE = 0.40 -- cadência ganha com a velocidade
local PASSADA_MIN = 0.22 -- rad de abertura da pata, andando devagar
local PASSADA_MAX = 0.62 -- rad, em disparada
local BOB_CORPO = 0.07 -- subida do tronco por passada (bem menor que antes)
local INCLINA_CORRIDA = 0.10 -- tronco mergulha para a frente correndo
local BALANCO_CAUDA = 0.42 -- rad de vaivém da cauda
local CABECA_CONTRA = 0.5 -- quanto a cabeça compensa o balanço do tronco
local RESPIRO = 0.035
local MISTURA = 7.0

type Peca = { parte: BasePart, repouso: CFrame, pivo: Vector3, grupo: string }

type Gait = {
	fase: number,
	mistura: number,
	solaOffset: number,
	y: number,
	chaoY: number,
	velocidadeY: number,
	pulando: boolean,
	esperaPulo: number,
	frente: Vector3,
	corpo: BasePart,
	pecas: { Peca },
	olhada: number, -- tempo até a próxima olhada de lado, parado
	desvioCabeca: number,
}

local activePets: { [Player]: Model } = {}
local gaits: { [Player]: Gait } = {}

-- Modelos --------------------------------------------------------------------

local function petsFolder(): Instance?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	return assets and assets:FindFirstChild("Pets")
end

local function buildPlaceholder(name: string): Model
	local model = Instance.new("Model")
	model.Name = name
	local part = Instance.new("Part")
	part.Name = "Corpo"
	part.Size = Vector3.new(1.2, 1.2, 1.8)
	part.Color = Color3.fromRGB(242, 140, 48)
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.Parent = model
	model.PrimaryPart = part
	return model
end

local function buildPetModel(speciesId: string): Model?
	local species = CreatureConfig.Get(speciesId)
	if not species then
		return nil
	end
	local modelName = species.ModelName or speciesId

	local folder = petsFolder()
	local source = folder and folder:FindFirstChild(modelName)
	local model: Model
	if source and source:IsA("Model") then
		model = source:Clone()
	else
		warn("[PetService] Modelo não encontrado em ReplicatedStorage.Assets.Pets:", modelName)
		model = buildPlaceholder(modelName)
	end

	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
		end
	end

	if not model.PrimaryPart then
		local corpo = model:FindFirstChild("Corpo")
		if corpo and corpo:IsA("BasePart") then
			model.PrimaryPart = corpo
		else
			-- a maior peça é o tronco; nunca a primeira que aparecer, que no
			-- Lumi antigo era o brilho da cauda
			local maior: BasePart? = nil
			for _, d in model:GetDescendants() do
				if d:IsA("BasePart") then
					local v = d.Size.X * d.Size.Y * d.Size.Z
					if not maior or v > (maior.Size.X * maior.Size.Y * maior.Size.Z) then
						maior = d
					end
				end
			end
			model.PrimaryPart = maior
		end
	end
	return model
end

-- Monta a lista de peças móveis com o pivô de cada uma, em espaço do tronco.
local GRUPOS = {
	Cabeca = "cabeca",
	Cauda = "cauda",
	TailGlow = "cauda",
	PatasFrente = "frente",
	PatasTras = "tras",
}

local function montarRig(model: Model, corpo: BasePart): { Peca }
	local pecas: { Peca } = {}
	local pivoDoGrupo: { [string]: Vector3 } = {}

	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d ~= corpo then
			local grupo = GRUPOS[d.Name]
			if grupo then
				local pivo: Vector3
				local px, py, pz = d:GetAttribute("PivoX"), d:GetAttribute("PivoY"), d:GetAttribute("PivoZ")
				if px and py and pz then
					pivo = Vector3.new(px, py, pz)
				elseif pivoDoGrupo[grupo] then
					pivo = pivoDoGrupo[grupo]
				else
					-- sem atributo: patas giram pelo topo, resto pela base
					local sinal = if grupo == "frente" or grupo == "tras" then 1 else -1
					local ponto = d.Position + Vector3.new(0, (d.Size.Y / 2) * sinal, 0)
					pivo = corpo.CFrame:PointToObjectSpace(ponto)
				end
				pivoDoGrupo[grupo] = pivo
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

-- Distância do tronco até a sola, para o bicho pousar no chão.
local function solaOffsetOf(model: Model, corpo: BasePart): number
	local cf, size = model:GetBoundingBox()
	return corpo.Position.Y - (cf.Position.Y - size.Y / 2)
end

-- Chão -----------------------------------------------------------------------

local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Exclude
groundParams.RespectCanCollide = true

local function groundAt(x: number, z: number, fromY: number, ignore: { Instance }): number?
	groundParams.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(Vector3.new(x, fromY + PROBE_UP, z), Vector3.new(0, -PROBE_DOWN, 0), groundParams)
	return hit and hit.Position.Y or nil
end

-- Ciclo do pet ---------------------------------------------------------------

local function despawn(player: Player)
	local model = activePets[player]
	if model then
		model:Destroy()
		activePets[player] = nil
	end
	gaits[player] = nil
end

local function spawnFor(player: Player)
	despawn(player)

	local data = PlayerDataService:GetData(player)
	if not data then
		return
	end
	local firstId = TeamUtil.GetEquippedIds(data.ActiveTeam)[1]
	if not firstId then
		return
	end
	local creature = data.Creatures[firstId]
	if not creature then
		return
	end

	local model = buildPetModel(creature.SpeciesId)
	if not model then
		return
	end
	model.Name = "Pet_" .. player.Name
	model:SetAttribute("OwnerUserId", player.UserId)
	model:SetAttribute("CreatureId", creature.CreatureId)
	model:SetAttribute("SpeciesId", creature.SpeciesId)

	local corpo = model.PrimaryPart
	if not corpo then
		model:Destroy()
		return
	end
	local pecas = montarRig(model, corpo)
	local solaOffset = solaOffsetOf(model, corpo)

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local frente = Vector3.new(0, 0, 1)
	local pos = Vector3.new(0, solaOffset, 0)

	if root and root:IsA("BasePart") then
		local alvo = root.CFrame * CFrame.new(FOLLOW_SIDE, 0, FOLLOW_BACK)
		local chao = groundAt(alvo.Position.X, alvo.Position.Z, root.Position.Y, { character })
			or (root.Position.Y - 3)
		pos = Vector3.new(alvo.Position.X, chao + solaOffset, alvo.Position.Z)
		local olhar = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
		frente = if olhar.Magnitude > 0.01 then olhar.Unit else frente
	end

	model.Parent = workspace
	activePets[player] = model
	gaits[player] = {
		fase = 0,
		mistura = 0,
		solaOffset = solaOffset,
		y = pos.Y,
		chaoY = pos.Y - solaOffset,
		velocidadeY = 0,
		pulando = false,
		esperaPulo = 0,
		frente = frente,
		corpo = corpo,
		pecas = pecas,
		olhada = 3,
		desvioCabeca = 0,
	}
end

-- Pose ------------------------------------------------------------------------

-- Aplica o tronco e, a partir dele, cada peça girada no próprio pivô.
local function aplicarPose(gait: Gait, corpoCF: CFrame, rotacoes: { [string]: CFrame })
	gait.corpo.CFrame = corpoCF
	for _, peca in gait.pecas do
		local rot = rotacoes[peca.grupo]
		if rot then
			local pivo = CFrame.new(peca.pivo)
			peca.parte.CFrame = corpoCF * pivo * rot * pivo:Inverse() * peca.repouso
		else
			peca.parte.CFrame = corpoCF * peca.repouso
		end
	end
end

-- Acompanhamento ---------------------------------------------------------------

local function updateFollow(deltaTime: number)
	local dt = math.min(deltaTime, 1 / 20)

	for player, model in activePets do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local gait = gaits[player]

		if not (root and root:IsA("BasePart") and gait and gait.corpo.Parent) then
			continue
		end

		local ignore = { character, model }
		local alvo = root.CFrame * CFrame.new(FOLLOW_SIDE, 0, FOLLOW_BACK)
		local atual = gait.corpo.Position

		if (Vector3.new(alvo.Position.X - atual.X, 0, alvo.Position.Z - atual.Z)).Magnitude > TELEPORT_DISTANCE then
			local chao = groundAt(alvo.Position.X, alvo.Position.Z, root.Position.Y, ignore) or (root.Position.Y - 3)
			gait.chaoY = chao
			gait.y = chao + gait.solaOffset
			gait.velocidadeY = 0
			gait.pulando = false
			aplicarPose(gait, CFrame.lookAt(
				Vector3.new(alvo.Position.X, gait.y, alvo.Position.Z),
				Vector3.new(alvo.Position.X, gait.y, alvo.Position.Z) + gait.frente), {})
			continue
		end

		-- 1. Andar no plano
		local paraAlvo = Vector3.new(alvo.Position.X - atual.X, 0, alvo.Position.Z - atual.Z)
		local distancia = paraAlvo.Magnitude
		local velocidade = 0
		if distancia > STOP_DISTANCE then
			local urgencia = math.clamp((distancia - STOP_DISTANCE) / (CATCHUP_DISTANCE - STOP_DISTANCE), 0, 1)
			velocidade = WALK_SPEED + (RUN_SPEED - WALK_SPEED) * urgencia
		end
		local passo = math.min(velocidade * dt, math.max(distancia - STOP_DISTANCE * 0.5, 0))
		local direcao = if distancia > 0.01 then paraAlvo.Unit else Vector3.zero
		local x = atual.X + direcao.X * passo
		local z = atual.Z + direcao.Z * passo

		-- 2. Chão
		local chao = groundAt(x, z, gait.y, ignore)
		if chao then
			gait.chaoY = chao
		end
		local apoio = gait.chaoY + gait.solaOffset

		-- 3. Pulo
		gait.esperaPulo = math.max(gait.esperaPulo - dt, 0)
		local humanoid = character and character:FindFirstChildWhichIsA("Humanoid")
		local donoNoAr = humanoid ~= nil
			and (humanoid:GetState() == Enum.HumanoidStateType.Jumping
				or humanoid:GetState() == Enum.HumanoidStateType.Freefall)

		if not gait.pulando and gait.esperaPulo <= 0 then
			if (apoio - gait.y) > STEP_UP_TRIGGER or (donoNoAr and velocidade > 0) then
				gait.pulando = true
				gait.velocidadeY = JUMP_SPEED
				gait.esperaPulo = JUMP_COOLDOWN
			end
		end

		local y
		if gait.pulando then
			gait.velocidadeY -= GRAVITY * dt
			y = gait.y + gait.velocidadeY * dt
			if gait.velocidadeY < 0 and y <= apoio then
				y = apoio
				gait.velocidadeY = 0
				gait.pulando = false
			end
		else
			y = gait.y + (apoio - gait.y) * math.clamp(dt * GROUND_SNAP, 0, 1)
		end
		gait.y = y

		-- 4. Cadência
		local noChao = not gait.pulando
		local andando = if velocidade > 0.5 and noChao then 1 else 0
		gait.mistura += (andando - gait.mistura) * math.clamp(dt * MISTURA, 0, 1)
		gait.fase += dt * (PASSO_BASE + velocidade * PASSO_POR_VELOCIDADE) * math.pi

		local corrida = math.clamp((velocidade - WALK_SPEED) / (RUN_SPEED - WALK_SPEED), 0, 1)
		local passada = (PASSADA_MIN + (PASSADA_MAX - PASSADA_MIN) * corrida) * gait.mistura

		-- 5. Para onde olha
		local desejada = gait.frente
		if velocidade > 0.5 and direcao.Magnitude > 0.01 then
			desejada = direcao
		else
			local paraDono = Vector3.new(root.Position.X - x, 0, root.Position.Z - z)
			if paraDono.Magnitude > 0.5 then
				desejada = paraDono.Unit
			end
		end
		local nova = gait.frente:Lerp(desejada, math.clamp(dt * TURN_SPEED, 0, 1))
		gait.frente = if nova.Magnitude > 0.01 then nova.Unit else desejada

		-- 6. Tronco: sobe e desce duas vezes por passada e mergulha na corrida
		local bob = math.sin(gait.fase * 2) * BOB_CORPO * gait.mistura
		local respiro = math.sin(gait.fase * 0.5) * RESPIRO * (1 - gait.mistura)
		local inclina = -INCLINA_CORRIDA * corrida * gait.mistura
			+ math.sin(gait.fase * 2) * 0.03 * gait.mistura
		local rola = math.sin(gait.fase) * 0.05 * gait.mistura

		if gait.pulando then
			inclina = math.clamp(-gait.velocidadeY / JUMP_SPEED, -1, 1) * 0.25
			rola = 0
		end

		local posCorpo = Vector3.new(x, y + bob + respiro, z)
		local corpoCF = CFrame.lookAt(posCorpo, posCorpo + gait.frente) * CFrame.Angles(inclina, 0, rola)

		-- 7. Peças
		local rotacoes: { [string]: CFrame } = {}
		if gait.pulando then
			-- no ar as patas recolhem e a cauda sobe
			rotacoes.frente = CFrame.Angles(-0.7, 0, 0)
			rotacoes.tras = CFrame.Angles(0.5, 0, 0)
			rotacoes.cauda = CFrame.Angles(-0.35, 0, 0)
			rotacoes.cabeca = CFrame.Angles(0.15, 0, 0)
		else
			-- par da frente e par de trás em oposição: a tesoura do trote
			rotacoes.frente = CFrame.Angles(math.sin(gait.fase) * passada, 0, 0)
			rotacoes.tras = CFrame.Angles(-math.sin(gait.fase) * passada, 0, 0)

			-- parado, ele dá uma olhada de lado de vez em quando
			gait.olhada -= dt
			if gait.olhada <= 0 then
				gait.olhada = 2.5 + math.random() * 4
				gait.desvioCabeca = (math.random() - 0.5) * 1.1
			end
			local alvoCabeca = if gait.mistura > 0.4 then 0 else gait.desvioCabeca
			gait.desvioCabeca += (alvoCabeca - gait.desvioCabeca) * math.clamp(dt * 2.5, 0, 1)

			-- a cabeça compensa o solavanco do tronco, como num animal de verdade
			rotacoes.cabeca = CFrame.Angles(-inclina * CABECA_CONTRA, gait.desvioCabeca, 0)
			-- a cauda vai e vem; devagar parado, rápido correndo
			local balanco = BALANCO_CAUDA * (0.3 + 0.7 * gait.mistura)
			rotacoes.cauda = CFrame.Angles(
				-0.1 * gait.mistura,
				math.sin(gait.fase * (if gait.mistura > 0.4 then 1 else 0.35)) * balanco,
				0)
		end

		aplicarPose(gait, corpoCF, rotacoes)
	end
end

-- Início ---------------------------------------------------------------------

function PetService:Start()
	TeamService.TeamChanged:Connect(function(player)
		task.defer(spawnFor, player)
	end)

	PlayerDataService.ProfileLoaded:Connect(function(player)
		task.defer(spawnFor, player)
	end)

	local function watchCharacter(player: Player)
		player.CharacterAdded:Connect(function()
			task.wait(0.5)
			spawnFor(player)
		end)
	end
	Players.PlayerAdded:Connect(watchCharacter)
	for _, player in Players:GetPlayers() do
		watchCharacter(player)
	end

	Players.PlayerRemoving:Connect(despawn)
	RunService.Heartbeat:Connect(updateFollow)
end

return PetService
