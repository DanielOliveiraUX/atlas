-- Equipe ativa: três slots OPCIONAIS. ActiveTeam é a fonte de verdade;
-- StorageState é derivado (Util/TeamUtil), nunca salvo.
--
-- O servidor valida tudo: propriedade, existência da instância, duplicidade
-- e limite de slots. Jogar com zero, um, dois ou três pets é válido.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Remotes = require(Shared.Remotes)
local TeamUtil = require(Shared.Util.TeamUtil)

local Services = script.Parent
local PlayerDataService = require(Services.PlayerDataService)

local TeamService = {}

local changedEvent = Instance.new("BindableEvent")
-- Dispara (player, activeTeam) sempre que a equipe muda
TeamService.TeamChanged = changedEvent.Event

local function slotKey(index: number): string?
	local key = TeamUtil.SlotKeys[index]
	return key
end

function TeamService:Replicate(player: Player)
	local data = PlayerDataService:GetData(player)
	if not data then
		return
	end
	local event = Remotes.Get("TeamUpdate") :: RemoteEvent
	event:FireClient(player, data.ActiveTeam)
end

-- Primeiro slot livre, ou nil se a equipe estiver cheia.
function TeamService:FirstFreeSlot(player: Player): number?
	local data = PlayerDataService:GetData(player)
	if not data then
		return nil
	end
	for index, key in TeamUtil.SlotKeys do
		if not data.ActiveTeam[key] then
			return index
		end
	end
	return nil
end

-- Equipa uma criatura num slot. Retorna (ok, erroKey).
function TeamService:Equip(player: Player, creatureId: string, slotIndex: number?)
	local data = PlayerDataService:GetData(player)
	if not data then
		return false, "Error.DataLoad"
	end

	-- Propriedade e existência
	local creature = data.Creatures[creatureId]
	if not creature then
		return false, "Team.Error.NotOwned"
	end

	-- Slot válido
	local index = slotIndex or self:FirstFreeSlot(player)
	if not index then
		return false, "Team.Error.NoFreeSlot"
	end
	if index < 1 or index > GameConfig.MaxTeamSlots then
		return false, "Team.Error.BadSlot"
	end
	local key = slotKey(index)
	if not key then
		return false, "Team.Error.BadSlot"
	end

	-- Duplicidade: a mesma criatura não pode ocupar dois slots.
	-- Se já estava equipada noutro slot, libera o antigo (é uma troca).
	for _, otherKey in TeamUtil.SlotKeys do
		if otherKey ~= key and data.ActiveTeam[otherKey] == creatureId then
			data.ActiveTeam[otherKey] = false
		end
	end

	data.ActiveTeam[key] = creatureId
	self:Replicate(player)
	changedEvent:Fire(player, data.ActiveTeam)
	return true, nil
end

-- Retira o pet de um slot. Retorna (ok, erroKey).
function TeamService:Unequip(player: Player, slotIndex: number)
	local data = PlayerDataService:GetData(player)
	if not data then
		return false, "Error.DataLoad"
	end
	local key = slotKey(slotIndex)
	if not key then
		return false, "Team.Error.BadSlot"
	end
	if not data.ActiveTeam[key] then
		return true, nil -- já estava vazio
	end

	data.ActiveTeam[key] = false
	self:Replicate(player)
	changedEvent:Fire(player, data.ActiveTeam)
	return true, nil
end

-- Criaturas equipadas e disponíveis (não fatigadas). Usado pela batalha.
function TeamService:GetAvailable(player: Player)
	local data = PlayerDataService:GetData(player)
	if not data then
		return {}
	end
	local now = os.time()
	local available = {}
	for _, creatureId in TeamUtil.GetEquippedIds(data.ActiveTeam) do
		local creature = data.Creatures[creatureId]
		if creature and not TeamUtil.IsFatigued(creature, now) then
			table.insert(available, creature)
		end
	end
	return available
end

function TeamService:Start()
	local equipRequest = Remotes.Get("TeamEquipRequest") :: RemoteEvent
	equipRequest.OnServerEvent:Connect(function(player, creatureId, slotIndex)
		-- Nunca confiar no cliente: checa tipo antes de usar
		if type(creatureId) ~= "string" then
			return
		end
		if slotIndex ~= nil and type(slotIndex) ~= "number" then
			return
		end
		self:Equip(player, creatureId, slotIndex)
	end)

	local unequipRequest = Remotes.Get("TeamUnequipRequest") :: RemoteEvent
	unequipRequest.OnServerEvent:Connect(function(player, slotIndex)
		if type(slotIndex) ~= "number" then
			return
		end
		self:Unequip(player, slotIndex)
	end)

	-- Manda o estado inicial assim que o perfil carrega
	PlayerDataService.ProfileLoaded:Connect(function(player)
		self:Replicate(player)
	end)

	-- Quem já estava carregado antes deste serviço subir
	for _, player in Players:GetPlayers() do
		if PlayerDataService:GetData(player) then
			self:Replicate(player)
		end
	end
end

return TeamService
