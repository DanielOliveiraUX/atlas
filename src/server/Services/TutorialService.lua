-- Conduz o tutorial e entrega o pet inicial UMA ÚNICA VEZ.
--
-- O servidor é dono do passo atual; o cliente só exibe o que recebe e avisa
-- quando terminou a parte dele. Um cliente que mande TutorialAction fora de
-- hora não avança nada.
--
-- O tutorial termina quando o jogador CHEGA na própria base andando. Não há
-- teleporte no fim: a caminhada é a primeira volta pela vila.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local TutorialConfig = require(Shared.Config.TutorialConfig)
local WorldConfig = require(Shared.Config.WorldConfig)
local Remotes = require(Shared.Remotes)
local TeamUtil = require(Shared.Util.TeamUtil)

local Services = script.Parent
local BaseService = require(Services.BaseService)
local CreatureService = require(Services.CreatureService)
local PlayerDataService = require(Services.PlayerDataService)
local TeamService = require(Services.TeamService)

local TutorialService = {}

-- Passo atual de cada jogador (índice em TutorialConfig.Steps). nil = fora do tutorial.
local stepByPlayer: { [Player]: number } = {}

-- Envio ----------------------------------------------------------------------

local function sendStep(player: Player, index: number?)
	local event = Remotes.Get("TutorialUpdate") :: RemoteEvent
	if not index then
		event:FireClient(player, nil)
		return
	end
	local step = TutorialConfig.GetStep(index)
	if not step then
		event:FireClient(player, nil)
		return
	end
	event:FireClient(player, {
		Index = index,
		Total = TutorialConfig.StepCount(),
		Id = step.Id,
		TitleKey = step.TitleKey,
		BodyKey = step.BodyKey,
		Advance = step.Advance,
		Target = step.Target,
		Lines = step.Lines,
		SpeakerKey = TutorialConfig.SpeakerKey,
		PetArrival = step.PetArrival,
		BaseLot = player:GetAttribute("BaseLot"),
	})
end

-- Pet inicial ----------------------------------------------------------------

-- Entrega o Lumi. Protegido contra entrega dupla por Achievements.StarterGranted.
function TutorialService:GrantStarter(player: Player)
	local data = PlayerDataService:GetData(player)
	if not data then
		return nil
	end
	if data.Achievements.StarterGranted then
		return nil
	end

	local creature, errorKey = CreatureService:Grant(player, GameConfig.StarterSpeciesId, "Tutorial")
	if not creature then
		warn("[TutorialService] Não foi possível entregar o pet inicial:", errorKey)
		return nil
	end

	data.Achievements.StarterGranted = true
	data.Statistics.CreaturesOwned = (data.Statistics.CreaturesOwned or 0) + 1
	return creature
end

-- Chegada na base -------------------------------------------------------------

local function baseSpawnPosition(player: Player): Vector3?
	local lot = BaseService:GetLot(player)
	if not lot then
		return nil
	end
	local target = BaseService:GetLotSpawn(lot)
	return target and target.Position
end

-- Fica conferindo a distância enquanto o jogador estiver neste passo.
local function watchReachBase(self, player: Player, index: number)
	task.spawn(function()
		while stepByPlayer[player] == index and player.Parent do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local target = baseSpawnPosition(player)
			if root and root:IsA("BasePart") and target then
				local flat = Vector3.new(root.Position.X - target.X, 0, root.Position.Z - target.Z)
				if flat.Magnitude <= TutorialConfig.ReachBaseDistance then
					self:Advance(player, TutorialConfig.GetStep(index).Id)
					return
				end
			end
			task.wait(TutorialConfig.ReachBaseInterval)
		end
	end)
end

-- Avanço ---------------------------------------------------------------------

local function finish(player: Player)
	local data = PlayerDataService:GetData(player)
	if data then
		data.TutorialCompleted = true
	end
	stepByPlayer[player] = nil
	sendStep(player, nil)
end

function TutorialService:SetStep(player: Player, index: number)
	if not player.Parent then
		return
	end
	local step = TutorialConfig.GetStep(index)
	if not step then
		finish(player)
		return
	end

	stepByPlayer[player] = index

	-- O pet é entregue ao ENTRAR no passo: assim o card já encontra a criatura
	-- registrada na coleção.
	if step.GrantStarter then
		self:GrantStarter(player)
	end

	sendStep(player, index)

	if step.PetArrival then
		local arrival = Remotes.Get("PetArrival") :: RemoteEvent
		arrival:FireClient(player, GameConfig.StarterSpeciesId)
	end

	if step.Advance == "Auto" then
		local delay = step.DelaySeconds or 3
		task.delay(delay, function()
			if stepByPlayer[player] == index then
				self:Advance(player, step.Id)
			end
		end)
	elseif step.Advance == "ReachBase" then
		watchReachBase(self, player, index)
	end
end

-- Avança se (e só se) o jogador está no passo esperado.
function TutorialService:Advance(player: Player, expectedStepId: string?)
	local index = stepByPlayer[player]
	if not index then
		return false
	end
	local step = TutorialConfig.GetStep(index)
	if not step then
		return false
	end
	if expectedStepId and step.Id ~= expectedStepId then
		return false -- pedido fora de hora: ignora
	end

	if index >= TutorialConfig.StepCount() then
		finish(player)
		return true
	end

	self:SetStep(player, index + 1)
	return true
end

function TutorialService:Begin(player: Player)
	local data = PlayerDataService:WaitForData(player, 30)
	if not data then
		return
	end
	if data.TutorialCompleted then
		sendStep(player, nil)
		return
	end
	self:SetStep(player, 1)
end

-- Mentor ---------------------------------------------------------------------

function TutorialService:BindMentor()
	task.spawn(function()
		local hub = workspace:WaitForChild(WorldConfig.HubFolder, 60)
		if not hub then
			warn("[TutorialService] Pasta " .. WorldConfig.HubFolder .. " não encontrada — o mentor não vai funcionar.")
			return
		end
		local mentor = hub:WaitForChild(WorldConfig.MentorPart, 60)
		if not mentor then
			warn("[TutorialService] Mentor não encontrado no hub.")
			return
		end

		local prompt = mentor:FindFirstChildWhichIsA("ProximityPrompt", true)
		if not prompt then
			warn("[TutorialService] Mentor sem ProximityPrompt.")
			return
		end

		prompt.Triggered:Connect(function(player)
			local index = stepByPlayer[player]
			if not index then
				return
			end
			local step = TutorialConfig.GetStep(index)
			if not step or step.Advance ~= "Prompt" then
				return
			end
			self:Advance(player, step.Id)
		end)
	end)
end

-- Ciclo ----------------------------------------------------------------------

function TutorialService:Start()
	self:BindMentor()

	PlayerDataService.ProfileLoaded:Connect(function(player)
		task.spawn(function()
			self:Begin(player)
		end)
	end)

	for _, player in Players:GetPlayers() do
		if PlayerDataService:GetData(player) then
			task.spawn(function()
				self:Begin(player)
			end)
		end
	end

	-- Passos que o cliente conclui: falas lidas, card fechado, coleção aberta
	local CLIENT_DRIVEN = { Dialogue = true, Card = true, Client = true }
	local action = Remotes.Get("TutorialAction") :: RemoteEvent
	action.OnServerEvent:Connect(function(player, stepId)
		if type(stepId) ~= "string" then
			return
		end
		local index = stepByPlayer[player]
		if not index then
			return
		end
		local step = TutorialConfig.GetStep(index)
		if not step or not CLIENT_DRIVEN[step.Advance] then
			return
		end
		self:Advance(player, stepId)
	end)

	-- Passo de equipar: avança quando a equipe passa a ter pelo menos um pet
	TeamService.TeamChanged:Connect(function(player, activeTeam)
		local index = stepByPlayer[player]
		if not index then
			return
		end
		local step = TutorialConfig.GetStep(index)
		if not step or step.Advance ~= "Equip" then
			return
		end
		if #TeamUtil.GetEquippedIds(activeTeam) > 0 then
			self:Advance(player, step.Id)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		stepByPlayer[player] = nil
	end)
end

return TutorialService
