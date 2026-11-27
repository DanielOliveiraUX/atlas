-- Regras gerais do jogo. Valores de balanceamento ficam aqui, nunca na lógica.
local GameConfig = {
	-- Coleção
	CollectionLimit = 10, -- limite inicial de pets (futuro: 20 ou expansão)
	CollectionExpansionSize = 10,

	-- Equipe
	MaxTeamSlots = 3,
	MinTeamForBattle = 1,

	-- Pet inicial (entregue pelo tutorial, igual para todos)
	StarterSpeciesId = "lumi",

	-- Captura assistida: teto do bônus somado de TODOS os pets equipados.
	-- Sem teto, três pets com bônus empurrariam o limiar de Lendária (5%)
	-- para perto de 35%. Ver decisoes-atlas.md.
	MaxAssistThresholdBonus = 0.10,

	-- Ferramenta obrigatória para concluir uma captura (ver AT-7)
	CaptureToolId = "capture_net",

	-- Teto de cada barra de atributo no card. Só afeta a leitura visual:
	-- a barra mostra valor/teto, nunca o cálculo de combate.
	StatBarMax = table.freeze({
		Health = 200,
		Attack = 60,
		Defense = 60,
		Speed = 40,
	}),
}

-- Curva de XP PROVISÓRIA, só para a barra de nível do card ter o que mostrar.
-- A curva definitiva entra com o EvolutionService (Fase 3 / AT-4).
function GameConfig.XpForNextLevel(level: number): number
	return 50 + math.max(0, (level or 1) - 1) * 25
end

return table.freeze(GameConfig)
