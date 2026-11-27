-- Nomes e medidas do cenário do MVP (um único Place: hub + lotes de base).
--
-- O cenário em si é construído no Studio (Workspace), fora do Rojo — ver CLAUDE.md.
-- Este arquivo guarda só os NOMES que o código procura e as medidas que o
-- construtor do cenário usa, para os dois lados não saírem do lugar.
local WorldConfig = {
	-- Pastas esperadas em Workspace
	HubFolder = "Hub",
	BasesFolder = "Bases",
	RegionFolder = "Region",

	-- Dentro de Hub
	HubSpawnPart = "HubSpawn", -- onde o jogador novo aparece
	MentorPart = "Mentor", -- NPC do tutorial (modelo com ProximityPrompt)
	GatePart = "RegionGate", -- passagem para a região de expedição (Fase 6)

	-- Lotes de base pessoal
	LotCount = 8, -- lotes ao redor do hub no MVP
	LotPrefix = "Lot", -- Lot1, Lot2, ...
	LotSpawnPart = "BaseSpawn", -- dentro de cada lote
	LotPetRestPart = "PetRest", -- área de descanso (recuperação 1,5x)

	-- Medidas usadas pelo construtor do cenário
	HubRadius = 46,
	LotRadius = 118, -- distância do centro do hub até o centro de cada lote
	LotSize = 52,
}

function WorldConfig.LotName(index: number): string
	return WorldConfig.LotPrefix .. tostring(index)
end

return table.freeze(WorldConfig)
