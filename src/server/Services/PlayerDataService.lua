-- Carrega e salva os dados individuais do jogador.
-- • Trava de sessão: um perfil só pode estar aberto em um servidor por vez
--   (evita duplicar pets ou perder progresso ao trocar de servidor).
-- • Versão de esquema + migrações + preenchimento de campos novos.
-- • Autosave periódico, salvamento ao sair e ao desligar o servidor.
-- • No Studio, sem acesso a DataStore, usa memória (dados não persistem).
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DataConfig = require(Shared.Config.DataConfig)
local Localization = require(Shared.Util.Localization)
local Remotes = require(Shared.Remotes)

local Data = script.Parent.Parent:WaitForChild("Data")
local DefaultProfile = require(Data.DefaultProfile)
local Migrations = require(Data.Migrations)

local PlayerDataService = {}

local store: DataStore? = nil
local useMemory = false
local profiles: { [Player]: { Data: any } } = {}

local loadedEvent = Instance.new("BindableEvent")
-- Dispara (player, data) quando o perfil termina de carregar
PlayerDataService.ProfileLoaded = loadedEvent.Event

-- Utilidades ---------------------------------------------------------------

local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in value do
		copy[k] = deepCopy(v)
	end
	return copy
end

-- Preenche campos que existem no modelo e faltam no perfil salvo
local function reconcile(data, template)
	for key, templateValue in template do
		if data[key] == nil then
			data[key] = deepCopy(templateValue)
		elseif type(templateValue) == "table" and type(data[key]) == "table" and next(templateValue) ~= nil then
			reconcile(data[key], templateValue)
		end
	end
end

local function keyFor(userId: number): string
	return DataConfig.KeyPrefix .. tostring(userId)
end

-- DataStore ----------------------------------------------------------------

-- Tenta abrir o perfil e pegar a trava. Retorna (ok, dados, travadoPorOutro)
local function tryAcquire(userId: number)
	local loaded = nil
	local lockedElsewhere = false

	local ok, err = pcall(function()
		(store :: DataStore):UpdateAsync(keyFor(userId), function(record)
			record = record or {}
			local lock = record.Lock
			local now = os.time()

			if lock and lock.JobId ~= game.JobId and now - lock.Time < DataConfig.LockTimeout then
				lockedElsewhere = true
				loaded = nil
				return nil -- cancela a escrita
			end

			lockedElsewhere = false
			loaded = record.Data
			record.Lock = { JobId = game.JobId, Time = now }
			return record
		end)
	end)

	if not ok then
		warn("[PlayerDataService] Falha ao carregar", userId, err)
	end
	return ok, loaded, lockedElsewhere
end

local function writeProfile(userId: number, data, release: boolean): boolean
	if useMemory then
		return true
	end

	local ok, err = pcall(function()
		(store :: DataStore):UpdateAsync(keyFor(userId), function(record)
			record = record or {}
			local lock = record.Lock
			if lock and lock.JobId ~= game.JobId then
				-- Outro servidor assumiu o perfil; não sobrescrever
				return nil
			end
			record.Data = data
			record.Lock = if release then nil else { JobId = game.JobId, Time = os.time() }
			return record
		end)
	end)

	if not ok then
		warn("[PlayerDataService] Falha ao salvar", userId, err)
	end
	return ok
end

-- Ciclo do perfil ------------------------------------------------------------

local function loadProfile(player: Player)
	local data = nil

	if not useMemory then
		local acquired = false
		for _ = 1, DataConfig.LoadRetries do
			local ok, stored, lockedElsewhere = tryAcquire(player.UserId)
			if ok and not lockedElsewhere then
				data = stored
				acquired = true
				break
			end
			task.wait(DataConfig.RetryDelay)
			if not player.Parent then
				return
			end
		end

		if not acquired then
			player:Kick(Localization.Get(player, "Error.DataLoad"))
			return
		end
	end

	data = data or deepCopy(DefaultProfile)
	data = Migrations.Run(data)
	reconcile(data, DefaultProfile)
	data.UserId = player.UserId

	-- Jogador saiu durante o carregamento: libera a trava e encerra
	if not player.Parent then
		writeProfile(player.UserId, data, true)
		return
	end

	profiles[player] = { Data = data }
	player:SetAttribute("ProfileLoaded", true)
	loadedEvent:Fire(player, data)
end

local function releaseProfile(player: Player)
	local profile = profiles[player]
	if not profile then
		return
	end
	profiles[player] = nil
	writeProfile(player.UserId, profile.Data, true)
end

-- API pública ----------------------------------------------------------------

-- Dados do jogador (somente servidor altera). nil se ainda não carregou.
function PlayerDataService:GetData(player: Player)
	local profile = profiles[player]
	return profile and profile.Data
end

-- Espera o perfil carregar (ou timeout em segundos). Retorna os dados ou nil.
function PlayerDataService:WaitForData(player: Player, timeout: number?)
	local deadline = os.clock() + (timeout or 30)
	while player.Parent and not profiles[player] and os.clock() < deadline do
		task.wait(0.1)
	end
	return self:GetData(player)
end

function PlayerDataService:IsUsingMemory(): boolean
	return useMemory
end

-- Inicialização --------------------------------------------------------------

function PlayerDataService:Init()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(DataConfig.StoreName)
	end)

	if ok then
		store = result
		if RunService:IsStudio() then
			-- Testa o acesso; sem "Enable Studio Access to API Services" cai para memória
			local probeOk = pcall(function()
				(store :: DataStore):GetAsync("__probe")
			end)
			useMemory = not probeOk
		end
	else
		useMemory = true
	end

	if useMemory then
		warn("[PlayerDataService] DataStore indisponível — usando memória (dados NÃO serão salvos).")
	end
end

function PlayerDataService:Start()
	Players.PlayerAdded:Connect(loadProfile)
	for _, player in Players:GetPlayers() do
		task.spawn(loadProfile, player)
	end

	Players.PlayerRemoving:Connect(releaseProfile)

	-- Cliente pede uma cópia de leitura do perfil (para a UI)
	local snapshot = Remotes.Get("GetProfileSnapshot") :: RemoteFunction
	snapshot.OnServerInvoke = function(player: Player)
		local data = self:WaitForData(player, 15)
		return data and deepCopy(data)
	end

	-- Autosave
	task.spawn(function()
		while true do
			task.wait(DataConfig.AutosaveInterval)
			for player, profile in profiles do
				task.spawn(writeProfile, player.UserId, profile.Data, false)
			end
		end
	end)

	-- Desligamento do servidor: salva todos e libera as travas
	game:BindToClose(function()
		if useMemory then
			return
		end
		local pending = 0
		for player in profiles do
			pending += 1
			task.spawn(function()
				releaseProfile(player)
				pending -= 1
			end)
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

return PlayerDataService
