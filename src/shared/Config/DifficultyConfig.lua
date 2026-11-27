-- Dificuldades de expedição. Mais difícil = mais moedas e XP.
local DifficultyConfig = {
	Order = table.freeze({ "Explorer", "Adventurer", "Survivor" }),

	Levels = table.freeze({
		Explorer = table.freeze({
			NameKey = "Difficulty.Explorer",
			ResourceMultiplier = 1.5,
			ThreatMultiplier = 0.6,
			CoinMultiplier = 1.0,
			XPMultiplier = 1.0,
		}),
		Adventurer = table.freeze({
			NameKey = "Difficulty.Adventurer",
			ResourceMultiplier = 1.0,
			ThreatMultiplier = 1.0,
			CoinMultiplier = 1.25,
			XPMultiplier = 1.25,
		}),
		Survivor = table.freeze({
			NameKey = "Difficulty.Survivor",
			ResourceMultiplier = 0.6,
			ThreatMultiplier = 1.5,
			CoinMultiplier = 1.5,
			XPMultiplier = 1.75,
		}),
	}),

	-- Regras da expedição
	MaxNights = 3,
}

return table.freeze(DifficultyConfig)
