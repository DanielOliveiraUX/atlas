-- Base pessoal: dá a cada jogador um lote ao redor do hub e o coloca no
-- lugar certo ao entrar.
--
-- O lote é só um ENDEREÇO dentro deste servidor (quem entra primeiro pega o
-- primeiro livre). O que é permanente fica no perfil, em BaseData — por isso
-- terminar uma expedição não reinicia a base.
--
-- O cenário (hub, lotes, casas) é construído no Studio, fora do Rojo.
-- Aqui só procuramos pelos nomes definidos em Config/WorldConfig.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local WorldConfig = require(Shared.Config.WorldConfig)

local Services = script.Parent
local PlayerDataService = require(Services.PlayerDataService)

local BaseService = {}

local lotByPlayer: { [Player]: number } = {}
local playerByLot: { [number]: Player } = {}

-- Cenário --------------------------------------------------------------------

local function hubFolder(): Instance?
	return workspace:FindFirstChild(WorldConfig.HubFolder)
end

local function basesFolder(): Instance?
	return workspace:FindFirstChild(WorldConfig.BasesFolder)
end

-- Procura uma BasePart por nome dentro de um container (inclusive em modelos).
local function findPart(container: Instance?, name: string): BasePart?
	if not container then
		return nil
	end
	local found = container:FindFirstChild(name, true)
	if found and found:IsA("BasePart") then
		return found
	end
	return nil
end

function BaseService:GetHubSpawn(): CFrame?
	local part = findPart(hubFolder(), WorldConfig.HubSpawnPart)
	return part and (part.CFrame + Vector3.new(0, part.Size.Y / 2 + 3, 0))
end

function BaseService:GetLotSpawn(index: number): CFrame?
	local bases = basesFolder()
	if not bases then
		return nil
	end
	local lot = bases:FindFirstChild(WorldConfig.LotName(index))
	local part = findPart(lot, WorldConfig.LotSpawnPart)
	return part and (part.CFrame + Vector3.new(0, part.Size.Y / 2 + 3, 0))
end

-- Lotes ----------------------------------------------------------------------

function BaseService:GetLot(player: Player): number?
	return lotByPlayer[player]
end

local function assignLot(player: Player): number?
	if lotByPlayer[player] then
		return lotByPlayer[player]
	end
	for index = 1, WorldConfig.LotCount do
		if not playerByLot[index] then
			lotByPlayer[player] = index
			playerByLot[index] = player
			player:SetAttribute("BaseLot", index)
			return index
		end
	end
	-- Servidor com mais jogadores que lotes: sem lote, o jogador fica no hub.
	warn("[BaseService] Sem lote livre para", player.Name)
	return nil
end

local function releaseLot(player: Player)
	local index = lotByPlayer[player]
	if index then
		playerByLot[index] = nil
		lotByPlayer[player] = nil
	end
end

-- Posicionamento -------------------------------------------------------------

-- Onde este jogador deve aparecer: hub se ainda não fez o tutorial,
-- a própria base se já fez.
function BaseService:GetSpawnFor(player: Player): CFrame?
	local data = PlayerDataService:GetData(player)
	local lot = lotByPlayer[player]

	if data and data.TutorialCompleted and lot then
		local atBase = self:GetLotSpawn(lot)
		if atBase then
			return atBase
		end
	end
	return self:GetHubSpawn() or (lot and self:GetLotSpawn(lot))
end

function BaseService:TeleportToSpawn(player: Player)
	local character = player.Character
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end
	local target = self:GetSpawnFor(player)
	if target then
		character:PivotTo(target)
	end
end

function BaseService:TeleportToBase(player: Player)
	local lot = lotByPlayer[player]
	if not lot then
		return false
	end
	local target = self:GetLotSpawn(lot)
	local character = player.Character
	if target and character then
		character:PivotTo(target)
		return true
	end
	return false
end

-- Ciclo ----------------------------------------------------------------------

function BaseService:Start()
	local function setup(player: Player)
		assignLot(player)
		if player.Character then
			task.defer(function()
				self:TeleportToSpawn(player)
			end)
		end
		player.CharacterAdded:Connect(function()
			-- Espera o personagem montar antes de mover
			task.wait(0.2)
			self:TeleportToSpawn(player)
		end)
	end

	Players.PlayerAdded:Connect(setup)
	for _, player in Players:GetPlayers() do
		task.spawn(setup, player)
	end

	Players.PlayerRemoving:Connect(releaseLot)
end

return BaseService
