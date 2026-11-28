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
	HubRadius = 40, -- praça de pedra em anéis, com a fonte no centro
	LotRadius = 128, -- distância do centro da vila até o centro de cada lote
	LotSize = 70, -- diâmetro da clareira de cada lote (é circular, não quadrada)

	-- Pasta das regiões exploráveis, no fim das quatro estradas
	RegionsFolder = "Regions",
	RegionCenterRadius = 255, -- distância do centro da vila até o meio da região
	RegionReach = 92, -- a partir de quantos studs do meio o jogador já está dentro
}

-- Zonas: quem está onde, e com que cara o mundo fica em cada uma.
--
-- `Fog` fecha o horizonte. Na vila o jogador deve adivinhar os biomas ao
-- longe; dentro de um bioma ele não deve ver a vila nem os vizinhos. Zoom
-- limitado pelo mesmo motivo: de longe o mapa inteiro aparecia de uma vez.
WorldConfig.Zones = {
	Hub = {
		Id = "Hub",
		NomeChave = "Zone.Hub.Title",
		SubChave = "Zone.Hub.Sub",
		Fog = { Densidade = 0.34, Bruma = 0.6, Cor = Color3.fromRGB(206, 220, 232), Decay = Color3.fromRGB(128, 150, 174), Zoom = 34 },
	},
	Base = {
		Id = "Base",
		NomeChave = "Zone.Base.Title",
		SubChave = "Zone.Base.Sub",
		Fog = { Densidade = 0.32, Bruma = 0.5, Cor = Color3.fromRGB(208, 220, 228), Decay = Color3.fromRGB(130, 150, 170), Zoom = 30 },
	},
	Dunas = {
		Id = "Dunas",
		NomeChave = "Zone.Dunas.Title",
		SubChave = "Zone.Dunas.Sub",
		Desvio = 0, -- graus a partir da diagonal +X+Z
		Fog = { Densidade = 0.48, Bruma = 1.1, Cor = Color3.fromRGB(246, 224, 178), Decay = Color3.fromRGB(196, 150, 96), Zoom = 24 },
	},
	Jardins = {
		Id = "Jardins",
		NomeChave = "Zone.Jardins.Title",
		SubChave = "Zone.Jardins.Sub",
		Desvio = 90,
		Fog = { Densidade = 0.42, Bruma = 0.8, Cor = Color3.fromRGB(222, 236, 212), Decay = Color3.fromRGB(140, 180, 130), Zoom = 26 },
	},
	Lajedo = {
		Id = "Lajedo",
		NomeChave = "Zone.Lajedo.Title",
		SubChave = "Zone.Lajedo.Sub",
		Desvio = 180,
		Fog = { Densidade = 0.56, Bruma = 1.3, Cor = Color3.fromRGB(230, 242, 252), Decay = Color3.fromRGB(150, 186, 214), Zoom = 22 },
	},
	MataRubra = {
		Id = "MataRubra",
		NomeChave = "Zone.MataRubra.Title",
		SubChave = "Zone.MataRubra.Sub",
		Desvio = 270,
		Fog = { Densidade = 0.52, Bruma = 1.2, Cor = Color3.fromRGB(226, 206, 172), Decay = Color3.fromRGB(150, 120, 80), Zoom = 22 },
	},
}

-- Centro de uma região, em coordenadas do mundo
function WorldConfig.RegionCenter(desvioGraus: number): Vector3
	local a = math.rad(45 + desvioGraus)
	return Vector3.new(math.sin(a) * WorldConfig.RegionCenterRadius, 0, math.cos(a) * WorldConfig.RegionCenterRadius)
end

-- Em que zona está este ponto. A base só conta se for o lote do jogador,
-- então quem chama passa o centro do próprio lote (ou nil).
function WorldConfig.ZoneAt(posicao: Vector3, centroDaBase: Vector3?): any
	local plano = Vector3.new(posicao.X, 0, posicao.Z)

	for _, zona in WorldConfig.Zones do
		if zona.Desvio then
			local centro = WorldConfig.RegionCenter(zona.Desvio)
			if (plano - centro).Magnitude <= WorldConfig.RegionReach then
				return zona
			end
		end
	end

	if centroDaBase then
		local c = Vector3.new(centroDaBase.X, 0, centroDaBase.Z)
		if (plano - c).Magnitude <= WorldConfig.LotSize / 2 + 6 then
			return WorldConfig.Zones.Base
		end
	end

	return WorldConfig.Zones.Hub
end

function WorldConfig.LotName(index: number): string
	return WorldConfig.LotPrefix .. tostring(index)
end

return table.freeze(WorldConfig)
