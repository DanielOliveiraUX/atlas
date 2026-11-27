-- Espécies. Cada criatura capturada aponta para uma espécie via SpeciesId.
-- CaptureThreshold: energia máxima (0–1) para a captura ser possível.
-- Nomes usam chaves de localização (ver src/localization/UI.csv).
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
	-- Placeholder até definirmos o pet inicial e as primeiras espécies (Fase 5)
	starter_placeholder = table.freeze({
		NameKey = "Species.Starter.Name",
		Rarity = "Common",
		Habitat = "Forest",
		CaptureThreshold = 0.50,
		BaseStats = table.freeze({ Health = 40, Attack = 8, Defense = 6, Speed = 10 }),
		Skills = table.freeze({}),
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

return table.freeze(CreatureConfig)
