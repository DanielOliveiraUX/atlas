-- Conduz o tutorial e entrega o pet inicial UMA ÚNICA VEZ.
--
-- O servidor é dono do passo atual; o cliente só exibe o que recebe e avisa
-- quando terminou a parte dele. Um cliente que mande TutorialAction fora de
-- hora não avança nada.
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

-- Avanço ---------------------------------------------------------------------

local function finish(player: Player)
	local data = PlayerDataService:GetData(player)
	if data then
		data.TutorialCompleted = true
	end
	stepByPlayer[player] = nil
	sendStep(player, nil)
	-- Fim do tutorial: o jogador vai para a própria base e explora a partir dali
	BaseService:TeleportToBase(player)
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
	sendStep(player, index)

	if step.Advance == "Auto" then
		local delay = step.DelaySeconds or 3
		task.delay(delay, function()
			-- Só avança se o jogador ainda está neste passo
			if stepByPlayer[player] == index then
				self:Advance(player, step.Id)
			end
		end)
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

-- Liga o ProximityPrompt do mentor no hub. O cenário é construído no Studio,
-- então o prompt pode ainda não existir quando o servidor sobe.
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
			if not step or step.Id ~= "GoToMentor" then
				return
			end
			-- Entrega o pet ao sair deste passo; o próximo passo o apresenta.
			self:GrantStarter(player)
			self:Advance(player, "GoToMentor")
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

	-- Quem já estava com o perfil carregado antes deste serviço subir
	for _, player in Players:GetPlayers() do
		if PlayerDataService:GetData(player) then
			task.spawn(function()
				self:Begin(player)
			end)
		end
	end

	-- Passos que o cliente conclui (fechou o cartão, abriu a coleção...)
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
		if not step or step.Advance ~= "Client" then
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
