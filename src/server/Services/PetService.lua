-- Mostra no mundo os pets equipados e faz o primeiro deles seguir o jogador.
--
-- Fatia inicial da Fase 3 (AT-4): sem isso o tutorial entrega um pet que
-- ninguém vê. Segue só o pet do Slot 1 por enquanto.
--
-- Pet fatigado continua seguindo normalmente — a fadiga só bloqueia batalha.
--
-- Os modelos ficam no place, em ReplicatedStorage.Assets.Pets.<ModelName>,
-- fora do Rojo (ver CLAUDE.md).
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

-- Ajuste fino do acompanhamento
local FOLLOW_BACK = 4.5 -- studs atrás do jogador
local FOLLOW_SIDE = 2.0 -- studs ao lado
local FOLLOW_SPEED = 6.0 -- quanto maior, mais rápido ele alcança
local TELEPORT_DISTANCE = 60 -- acima disso, aparece do lado em vez de correr
local HOVER = 0.1

local activePets: { [Player]: Model } = {}

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
	if not model.PrimaryPart then
		model.PrimaryPart = model:FindFirstChildWhichIsA("BasePart", true)
	end
	return model
end

-- Ciclo do pet ---------------------------------------------------------------

local function despawn(player: Player)
	local model = activePets[player]
	if model then
		model:Destroy()
		activePets[player] = nil
	end
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
	if root and root:IsA("BasePart") then
		model:PivotTo(root.CFrame * CFrame.new(FOLLOW_SIDE, 0, FOLLOW_BACK))
	end

	model.Parent = workspace
	activePets[player] = model
end

-- Acompanhamento -------------------------------------------------------------

local function updateFollow(deltaTime: number)
	for player, model in activePets do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local primary = model.PrimaryPart

		if not (root and root:IsA("BasePart") and primary) then
			continue
		end

		local target = root.CFrame * CFrame.new(FOLLOW_SIDE, 0, FOLLOW_BACK)
		local targetPos = Vector3.new(target.Position.X, root.Position.Y - 1.4 + HOVER, target.Position.Z)
		local current = primary.Position

		if (targetPos - current).Magnitude > TELEPORT_DISTANCE then
			model:PivotTo(CFrame.new(targetPos, targetPos + root.CFrame.LookVector))
			continue
		end

		local alpha = math.clamp(deltaTime * FOLLOW_SPEED, 0, 1)
		local nextPos = current:Lerp(targetPos, alpha)

		-- Só vira para onde está indo se realmente se moveu
		local delta = nextPos - current
		local look = if delta.Magnitude > 0.01
			then Vector3.new(delta.X, 0, delta.Z)
			else Vector3.new(primary.CFrame.LookVector.X, 0, primary.CFrame.LookVector.Z)
		if look.Magnitude < 0.01 then
			look = Vector3.new(0, 0, 1)
		end

		model:PivotTo(CFrame.lookAt(nextPos, nextPos + look.Unit))
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
