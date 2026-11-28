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
-- O pet anda pelo chão, não pela altura do jogador: a posição vertical sai
-- de um raio lançado para baixo. Antes ele copiava o Y do jogador, então
-- flutuava em qualquer ladeira e subia junto nos pulos.
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
local FOLLOW_BACK = 4.5 -- studs atrás do jogador
local FOLLOW_SIDE = 2.0 -- studs ao lado
local STOP_DISTANCE = 2.2 -- perto o bastante: para de andar
local CATCHUP_DISTANCE = 14 -- longe assim: dispara a correr
local TELEPORT_DISTANCE = 70 -- perdeu o dono de vez: reaparece do lado

-- Velocidades (studs/s). Ele é mais lento que o jogador andando e mais
-- rápido correndo, então fica atrás na caminhada e alcança na corrida.
local WALK_SPEED = 13
local RUN_SPEED = 32
local TURN_SPEED = 9 -- quão rápido o corpo gira para a direção nova

-- Chão
local GROUND_SNAP = 14 -- suavidade ao descer uma ladeira
local PROBE_UP = 12 -- de quanto acima do pé o raio começa
local PROBE_DOWN = 60

-- Pulo
local STEP_UP_TRIGGER = 1.8 -- degrau acima disto vira pulo
local JUMP_SPEED = 17
local GRAVITY = 62
local JUMP_COOLDOWN = 0.35

-- Passo. O modelo é uma malha só, sem esqueleto: o passo é feito no corpo
-- inteiro — quica, balança e mergulha o focinho no ritmo da corrida.
local GAIT_BASE = 4.5
local GAIT_PER_SPEED = 0.62
local BOB_HEIGHT = 0.26
local PITCH_AMOUNT = 0.08
local ROLL_AMOUNT = 0.10
local BREATH_HEIGHT = 0.05
local BLEND_SPEED = 7.0

type Gait = {
	phase: number,
	blend: number,
	footOffset: number,
	y: number,
	groundY: number,
	velocityY: number,
	jumping: boolean,
	jumpCooldown: number,
	facing: Vector3,
}

local activePets: { [Player]: Model } = {}
local gaits: { [Player]: Gait } = {}

-- Modelos --------------------------------------------------------------------

local function petsFolder(): Instance?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	return assets and assets:FindFirstChild("Pets")
end

-- Marcador simples para não quebrar quando o modelo ainda não existe no place.
local function buildPlaceholder(name: string): Model
	local model = Instance.new("Model")
	model.Name = name
	local part = Instance.new("Part")
	part.Name = "Body"
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

	-- O pet é decorativo: não colide e não empurra o jogador
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
		end
	end

	-- O pivô tem que ficar no corpo. No Lumi a primeira peça é o brilho da
	-- cauda, e usar ela deixava o pet deslocado em relação ao jogador.
	local maior: BasePart? = nil
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			local volume = descendant.Size.X * descendant.Size.Y * descendant.Size.Z
			if not maior or volume > (maior.Size.X * maior.Size.Y * maior.Size.Z) then
				maior = descendant
			end
		end
	end
	if maior then
		model.PrimaryPart = maior
	end
	return model
end

-- Distância do pivô até a sola, para o bicho pousar no chão em vez de afundar
-- ou pairar. Depende do modelo, então é medida uma vez por pet.
local function footOffsetOf(model: Model): number
	local cf, size = model:GetBoundingBox()
	local bottom = cf.Position.Y - size.Y / 2
	return model:GetPivot().Position.Y - bottom
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
	local equipped = TeamUtil.GetEquippedIds(data.ActiveTeam)
	local firstId = equipped[1]
	if not firstId then
		return -- equipe vazia é válida: simplesmente não há pet no mundo
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

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local footOffset = footOffsetOf(model)
	local startPos = Vector3.new(0, footOffset, 0)
	local facing = Vector3.new(0, 0, 1)

	if root and root:IsA("BasePart") then
		local alvo = root.CFrame * CFrame.new(FOLLOW_SIDE, 0, FOLLOW_BACK)
		local chao = groundAt(alvo.Position.X, alvo.Position.Z, root.Position.Y, { character })
			or (root.Position.Y - 3)
		startPos = Vector3.new(alvo.Position.X, chao + footOffset, alvo.Position.Z)
		facing = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
		if facing.Magnitude < 0.01 then
			facing = Vector3.new(0, 0, 1)
		end
		facing = facing.Unit
		model:PivotTo(CFrame.lookAt(startPos, startPos - facing))
	end

	model.Parent = workspace
	activePets[player] = model
	gaits[player] = {
		phase = 0,
		blend = 0,
		footOffset = footOffset,
		y = startPos.Y,
		groundY = startPos.Y - footOffset,
		velocityY = 0,
		jumping = false,
		jumpCooldown = 0,
		facing = facing,
	}
end

-- Acompanhamento -------------------------------------------------------------

local function updateFollow(deltaTime: number)
	local dt = math.min(deltaTime, 1 / 20) -- um engasgue não pode teleportar o bicho

	for player, model in activePets do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local primary = model.PrimaryPart
		local gait = gaits[player]

		if not (root and root:IsA("BasePart") and primary and gait) then
			continue
		end

		local ignore = { character, model }
		local alvo = root.CFrame * CFrame.new(FOLLOW_SIDE, 0, FOLLOW_BACK)
		local atual = primary.Position

		-- Longe demais (caiu do mapa, nasceu de novo): reaparece do lado.
		if (Vector3.new(alvo.Position.X, 0, alvo.Position.Z) - Vector3.new(atual.X, 0, atual.Z)).Magnitude > TELEPORT_DISTANCE then
			local chao = groundAt(alvo.Position.X, alvo.Position.Z, root.Position.Y, ignore) or (root.Position.Y - 3)
			gait.groundY = chao
			gait.y = chao + gait.footOffset
			gait.velocityY = 0
			gait.jumping = false
			model:PivotTo(CFrame.new(alvo.Position.X, gait.y, alvo.Position.Z))
			continue
		end

		-- 1. Andar no plano, com velocidade própria. Perto, anda; longe, corre.
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

		-- 2. Onde está o chão embaixo dele agora
		local chao = groundAt(x, z, gait.y, ignore)
		if chao then
			gait.groundY = chao
		end
		local apoio = gait.groundY + gait.footOffset

		-- 3. Pular: degrau alto pela frente, ou o dono pulou e ele acompanha.
		gait.jumpCooldown = math.max(gait.jumpCooldown - dt, 0)
		local humanoid = character and character:FindFirstChildWhichIsA("Humanoid")
		local donoNoAr = humanoid ~= nil
			and (humanoid:GetState() == Enum.HumanoidStateType.Jumping or humanoid:GetState() == Enum.HumanoidStateType.Freefall)

		if not gait.jumping and gait.jumpCooldown <= 0 then
			local degrau = apoio - gait.y
			if degrau > STEP_UP_TRIGGER or (donoNoAr and velocidade > 0) then
				gait.jumping = true
				gait.velocityY = JUMP_SPEED
				gait.jumpCooldown = JUMP_COOLDOWN
			end
		end

		local y
		if gait.jumping then
			gait.velocityY -= GRAVITY * dt
			y = gait.y + gait.velocityY * dt
			if gait.velocityY < 0 and y <= apoio then
				y = apoio
				gait.velocityY = 0
				gait.jumping = false
			end
		else
			-- cola no chão, mas sem tranco: ladeira vira descida suave
			y = gait.y + (apoio - gait.y) * math.clamp(dt * GROUND_SNAP, 0, 1)
		end
		gait.y = y

		-- 4. Passo
		local noChao = not gait.jumping
		local querAndar = if velocidade > 0.5 and noChao then 1 else 0
		gait.blend += (querAndar - gait.blend) * math.clamp(dt * BLEND_SPEED, 0, 1)
		gait.phase += dt * (GAIT_BASE + velocidade * GAIT_PER_SPEED)

		local bob = math.abs(math.sin(gait.phase)) * BOB_HEIGHT * gait.blend
		local breath = math.sin(gait.phase * 0.4) * BREATH_HEIGHT * (1 - gait.blend)
		local pitch = math.sin(gait.phase * 2) * PITCH_AMOUNT * gait.blend
		local roll = math.sin(gait.phase) * ROLL_AMOUNT * gait.blend

		if gait.jumping then
			-- no ar o corpo aponta para onde vai: sobe de nariz em pé, desce de nariz baixo
			pitch = math.clamp(-gait.velocityY / JUMP_SPEED, -1, 1) * 0.22
			roll = 0
		end

		-- 5. Para onde olha: a direção do movimento; parado, encara o dono.
		local desejada = gait.facing
		if velocidade > 0.5 and direcao.Magnitude > 0.01 then
			desejada = direcao
		else
			local paraDono = Vector3.new(root.Position.X - x, 0, root.Position.Z - z)
			if paraDono.Magnitude > 0.5 then
				desejada = paraDono.Unit
			end
		end
		local giro = math.clamp(dt * TURN_SPEED, 0, 1)
		local novaFrente = gait.facing:Lerp(desejada, giro)
		if novaFrente.Magnitude < 0.01 then
			novaFrente = desejada
		end
		gait.facing = novaFrente.Unit

		-- O modelo é desenhado olhando para +Z, o oposto do LookVector de um
		-- CFrame. Sem o sinal trocado o pet anda de costas.
		local pos = Vector3.new(x, y + bob + breath, z)
		model:PivotTo(CFrame.lookAt(pos, pos - gait.facing) * CFrame.Angles(pitch, 0, roll))
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
