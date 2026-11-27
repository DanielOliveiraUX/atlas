-- Ponto único para RemoteEvents/RemoteFunctions.
-- O servidor cria; o cliente espera. Todo pedido do cliente deve ser validado no servidor.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "Remotes"

local EVENTS = {
	"CaptureRequest",
	"BattleRequest",
	"TeamUpdate", -- servidor -> cliente: ActiveTeam mudou
	"InventoryUpdate",
	"CreatureUpdate", -- servidor -> cliente: coleção mudou
	"ExpeditionUpdate",

	-- Tutorial
	"TutorialUpdate", -- servidor -> cliente: passo atual
	"TutorialAction", -- cliente -> servidor: "terminei este passo"

	-- Equipe (pedidos do cliente; o servidor valida tudo)
	"TeamEquipRequest",
	"TeamUnequipRequest",
}

local FUNCTIONS = {
	"GetProfileSnapshot",
}

local Remotes = {}

function Remotes.Setup()
	assert(RunService:IsServer(), "Remotes.Setup só pode rodar no servidor")
	local folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = FOLDER_NAME
		folder.Parent = ReplicatedStorage
	end
	for _, name in EVENTS do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
	end
	for _, name in FUNCTIONS do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new("RemoteFunction")
			remote.Name = name
			remote.Parent = folder
		end
	end
end

function Remotes.Get(name: string): Instance
	local folder = ReplicatedStorage:WaitForChild(FOLDER_NAME)
	local remote = folder:WaitForChild(name, 10)
	assert(remote, "Remote não encontrado: " .. name)
	return remote
end

return Remotes
