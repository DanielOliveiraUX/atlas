-- Batalha automática por turnos, no local, com UI simples.
local BattleConfig = {
	MinTeamSize = 1,
	MaxTeamSize = 3,
	TurnDelaySeconds = 1.0, -- ritmo visual entre ações
	MaxTurns = 50, -- evita batalhas infinitas

	Types = table.freeze({
		NPC = "NPC",
		Wild = "Wild",
	}),

	-- Recompensas base (multiplicadas pela dificuldade da expedição)
	BaseRewards = table.freeze({
		NPC = table.freeze({ Coins = 20, XP = 30, PetChance = 0.05 }),
		Wild = table.freeze({ Coins = 5, XP = 15, PetChance = 0 }),
	}),
}

return table.freeze(BattleConfig)
