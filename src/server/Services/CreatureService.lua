-- Dono da coleção do jogador: cria instâncias de criatura e as registra no perfil.
-- Nada aqui confia no cliente; quem chama é sempre outro serviço do servidor.
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CreatureConfig = require(Shared.Config.CreatureConfig)
local Remotes = require(Shared.Remotes)

local Services = script.Parent
local PlayerDataService = require(Services.PlayerDataService)

local CreatureService = {}

-- Criação -------------------------------------------------------------------

-- Monta uma CreatureInstance nova a partir da espécie. Não toca no perfil.
function CreatureService:Build(speciesId: string, origin: string?, level: number?)
	local species = CreatureConfig.Get(speciesId)
	assert(species, "Espécie desconhecida: " .. tostring(speciesId))

	local creatureLevel = level or 1
	return {
		CreatureId = HttpService:GenerateGUID(false),
		SpeciesId = speciesId,
		Nickname = nil,
		Level = creatureLevel,
		Experience = 0,
		Stats = CreatureConfig.GetStatsForLevel(speciesId, creatureLevel),
		Skills = CreatureConfig.GetSkillsForLevel(speciesId, creatureLevel),
		EvolutionStage = 1,
		FatigueUntil = nil,
		CaptureDate = os.time(),
		DiscoveryOrigin = origin or "Unknown",
	}
end

-- Consultas -----------------------------------------------------------------

function CreatureService:Count(player: Player): number
	local data = PlayerDataService:GetData(player)
	if not data then
		return 0
	end
	local total = 0
	for _ in data.Creatures do
		total += 1
	end
	return total
end

function CreatureService:IsFull(player: Player): boolean
	local data = PlayerDataService:GetData(player)
	if not data then
		return true
	end
	return self:Count(player) >= data.CollectionLimit
end

function CreatureService:Get(player: Player, creatureId: string)
	local data = PlayerDataService:GetData(player)
	if not data then
		return nil
	end
	return data.Creatures[creatureId]
end

-- Alterações ----------------------------------------------------------------

-- Avisa o cliente que a coleção mudou (cópia de leitura).
function CreatureService:Replicate(player: Player)
	local data = PlayerDataService:GetData(player)
	if not data then
		return
	end
	local event = Remotes.Get("CreatureUpdate") :: RemoteEvent
	event:FireClient(player, data.Creatures, data.CollectionLimit)
end

-- Entrega uma criatura nova. Retorna (criatura, erroKey).
-- erroKey é uma chave de localização quando falha.
function CreatureService:Grant(player: Player, speciesId: string, origin: string?, level: number?)
	local data = PlayerDataService:GetData(player)
	if not data then
		return nil, "Error.DataLoad"
	end
	if self:IsFull(player) then
		return nil, "Collection.Full"
	end

	local creature = self:Build(speciesId, origin, level)
	data.Creatures[creature.CreatureId] = creature
	self:Replicate(player)

	-- Todo pet recebido mostra o card de revelação no cliente,
	-- venha do tutorial, de uma captura ou de um prêmio de batalha.
	local granted = Remotes.Get("CreatureGranted") :: RemoteEvent
	granted:FireClient(player, creature)

	return creature, nil
end

return CreatureService
