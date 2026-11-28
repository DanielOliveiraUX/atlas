-- Espécies. Cada criatura capturada aponta para uma espécie via SpeciesId.
-- CaptureThreshold: energia máxima (0–1) para a captura ser possível.
-- Nomes usam chaves de localização (ver src/localization/UI.csv).
--
-- Growth: quanto cada atributo sobe por nível.
-- Skills: { [nívelQueDesbloqueia] = skillId }
-- Assist: bônus de captura assistida enquanto o pet está equipado.
--   Type "Calm" = aumenta o limiar de captura (ThresholdBonus, somado e limitado
--   por GameConfig.MaxAssistThresholdBonus).
-- Evolution: { Level = n, Into = speciesId }
local CreatureConfig = {}

CreatureConfig.Rarity = table.freeze({
	Common = "Common",
	Uncommon = "Uncommon",
	Rare = "Rare",
	Legendary = "Legendary",
})

-- Limiar padrão por raridade: 50% / 15% / 10% / 5%
CreatureConfig.DefaultThresholdByRarity = table.freeze({
	Common = 0.50,
	Uncommon = 0.15,
	Rare = 0.10,
	Legendary = 0.05,
})

CreatureConfig.Species = table.freeze({
	-- Pet inicial. Raposa laranja com a ponta da cauda luminosa.
	-- Propositalmente resistente e fraca de dano: não pode fazer o
	-- jogador perder a primeira batalha.
	lumi = table.freeze({
		NameKey = "Species.Lumi.Name",
		TitleKey = "Species.Lumi.Title",
		ModelName = "Lumi",
		Rarity = "Common",
		Habitat = "Forest",
		CaptureThreshold = 0.50,
		BaseStats = table.freeze({ Health = 60, Attack = 12, Defense = 10, Speed = 11 }),
		Growth = table.freeze({ Health = 6, Attack = 2, Defense = 2, Speed = 1 }),
		Skills = table.freeze({ [1] = "investida", [4] = "clarao", [8] = "aconchego" }),
		Assist = table.freeze({ Type = "Calm", ThresholdBonus = 0.10 }),
		Evolution = table.freeze({ Level = 10, Into = "lumen" }),
	}),

	-- Evolução do Lumi. Maior, pelagem mais clara e fria, luz mais forte.
	lumen = table.freeze({
		NameKey = "Species.Lumen.Name",
		TitleKey = "Species.Lumen.Title",
		ModelName = "Lumen",
		Rarity = "Uncommon",
		Habitat = "Forest",
		CaptureThreshold = 0.15,
		BaseStats = table.freeze({ Health = 96, Attack = 24, Defense = 22, Speed = 16 }),
		Growth = table.freeze({ Health = 7, Attack = 2, Defense = 2, Speed = 1 }),
		Skills = table.freeze({ [1] = "investida", [4] = "clarao", [8] = "aconchego", [12] = "luzguia" }),
		Assist = table.freeze({ Type = "Calm", ThresholdBonus = 0.10 }),
		Evolution = nil,
	}),

	-- Raposa-miragem das Dunas de Âmbar. Orelhas enormes, pelagem de areia.
	-- É a primeira criatura selvagem que o jogador enfrenta: bate pouco e
	-- tem pouca vida, para a primeira batalha ensinar sem punir.
	mirra = table.freeze({
		NameKey = "Species.Mirra.Name",
		TitleKey = "Species.Mirra.Title",
		ModelName = "Mirra",
		Rarity = "Uncommon",
		Habitat = "Desert",
		CaptureThreshold = 0.20,
		-- Aguenta pancada e bate pouco: a luta dura, mas o jogador ganha.
		-- Medido em jogo: contra um Lumi nível 1 a batalha leva ~9 segundos
		-- e custa cerca de um quinto da energia dele.
		BaseStats = table.freeze({ Health = 78, Attack = 9, Defense = 8, Speed = 18 }),
		Growth = table.freeze({ Health = 6, Attack = 1, Defense = 1, Speed = 2 }),
		Skills = table.freeze({ [1] = "mordida", [5] = "rajada" }),
		Assist = table.freeze({ Type = "Calm", ThresholdBonus = 0.05 }),
		Evolution = nil,
	}),

	-- Raposa azul de pontas ciano. Rápida, especialista em rastrear.
	cirro = table.freeze({
		NameKey = "Species.Cirro.Name",
		TitleKey = "Species.Cirro.Title",
		ModelName = "Cirro",
		Rarity = "Uncommon",
		Habitat = "Highland",
		CaptureThreshold = 0.15,
		BaseStats = table.freeze({ Health = 48, Attack = 16, Defense = 8, Speed = 16 }),
		Growth = table.freeze({ Health = 4, Attack = 3, Defense = 1, Speed = 2 }),
		Skills = table.freeze({ [1] = "investida", [5] = "rajada" }),
		Assist = table.freeze({ Type = "Track" }),
		Evolution = nil,
	}),

	-- Criatura verde de orelhas em folha. Resistente, especialista em atrair.
	fronde = table.freeze({
		NameKey = "Species.Fronde.Name",
		TitleKey = "Species.Fronde.Title",
		ModelName = "Fronde",
		Rarity = "Common",
		Habitat = "Forest",
		CaptureThreshold = 0.50,
		BaseStats = table.freeze({ Health = 74, Attack = 9, Defense = 14, Speed = 7 }),
		Growth = table.freeze({ Health = 8, Attack = 1, Defense = 3, Speed = 1 }),
		Skills = table.freeze({ [1] = "investida", [6] = "raizes" }),
		Assist = table.freeze({ Type = "Lure" }),
		Evolution = nil,
	}),
})

function CreatureConfig.Get(speciesId: string)
	return CreatureConfig.Species[speciesId]
end

function CreatureConfig.GetCaptureThreshold(speciesId: string): number
	local species = CreatureConfig.Species[speciesId]
	if not species then
		return 0.15
	end
	return species.CaptureThreshold or CreatureConfig.DefaultThresholdByRarity[species.Rarity] or 0.15
end

-- Atributos de uma espécie no nível pedido (nível 1 = BaseStats).
function CreatureConfig.GetStatsForLevel(speciesId: string, level: number)
	local species = CreatureConfig.Species[speciesId]
	if not species then
		return { Health = 1, Attack = 1, Defense = 1, Speed = 1 }
	end
	local steps = math.max(0, (level or 1) - 1)
	local growth = species.Growth or {}
	local stats = {}
	for key, base in species.BaseStats do
		stats[key] = base + (growth[key] or 0) * steps
	end
	return stats
end

-- Habilidades já desbloqueadas até o nível pedido, em ordem de nível.
function CreatureConfig.GetSkillsForLevel(speciesId: string, level: number): { string }
	local species = CreatureConfig.Species[speciesId]
	if not species or not species.Skills then
		return {}
	end
	local unlocked = {}
	for requiredLevel, skillId in species.Skills do
		if (level or 1) >= requiredLevel then
			table.insert(unlocked, { requiredLevel, skillId })
		end
	end
	table.sort(unlocked, function(a, b)
		return a[1] < b[1]
	end)
	local ids = {}
	for _, entry in unlocked do
		table.insert(ids, entry[2])
	end
	return ids
end

return table.freeze(CreatureConfig)
