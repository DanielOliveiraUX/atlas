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
}

return table.freeze(GameConfig)
