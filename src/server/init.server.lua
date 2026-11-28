-- Ponto de entrada do servidor.
-- Cada serviço pode ter :Init() (preparar) e :Start() (começar a rodar).
-- Todos os Init rodam antes de qualquer Start.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared").Remotes)
Remotes.Setup()

local ServicesFolder = script:WaitForChild("Services")

-- Ordem de carregamento (adicione novos serviços aqui)
local ORDER = {
	"PlayerDataService",
	"CreatureService",
	"TeamService",
	"BaseService",
	"PetService",
	"BattleService",
	"WildService",
	"TutorialService",
}

local services = {}
for _, name in ORDER do
	services[name] = require(ServicesFolder:WaitForChild(name))
end

for _, name in ORDER do
	local service = services[name]
	if service.Init then
		service:Init()
	end
end

for _, name in ORDER do
	local service = services[name]
	if service.Start then
		task.spawn(service.Start, service)
	end
end

print("[ATLAS] Servidor iniciado")
