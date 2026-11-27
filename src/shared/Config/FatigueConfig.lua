-- Fadiga: recuperação = base_do_tipo × fator_nível × fator_local
-- Quanto mais baixo o nível do pet, mais rápido ele recupera.
-- Fadiga bloqueia só batalhas; o pet continua seguindo e explorando.
local FatigueConfig = {}

-- Tempo base em segundos por tipo de batalha
FatigueConfig.BaseSeconds = table.freeze({
	NPC = 60,
	Wild = 30, -- criatura selvagem gera metade da fadiga
})

-- Fator por faixa de nível (ordem crescente de MaxLevel)
FatigueConfig.LevelBrackets = table.freeze({
	table.freeze({ MaxLevel = 5, Factor = 0.25 }),
	table.freeze({ MaxLevel = 10, Factor = 0.5 }),
	table.freeze({ MaxLevel = 20, Factor = 1.0 }),
	table.freeze({ MaxLevel = math.huge, Factor = 1.5 }),
})

-- Na base pessoal o pet recupera 1,5x mais rápido
FatigueConfig.BaseRecoveryMultiplier = 1.5

function FatigueConfig.GetLevelFactor(level: number): number
	for _, bracket in FatigueConfig.LevelBrackets do
		if level <= bracket.MaxLevel then
			return bracket.Factor
		end
	end
	return 1
end

-- Duração da fadiga (segundos) fora da base, logo após a batalha.
function FatigueConfig.GetDuration(level: number, battleType: string): number
	local base = FatigueConfig.BaseSeconds[battleType] or FatigueConfig.BaseSeconds.NPC
	return base * FatigueConfig.GetLevelFactor(level)
end

return table.freeze(FatigueConfig)
