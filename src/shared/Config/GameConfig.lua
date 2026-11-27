-- Regras gerais do jogo. Valores de balanceamento ficam aqui, nunca na lógica.
local GameConfig = {
	-- Coleção
	CollectionLimit = 10, -- limite inicial de pets (futuro: 20 ou expansão)
	CollectionExpansionSize = 10,

	-- Equipe
	MaxTeamSlots = 3,
	MinTeamForBattle = 1,

	-- Pet inicial (entregue pelo tutorial, igual para todos)
	StarterSpeciesId = "starter_placeholder",
}

return table.freeze(GameConfig)
