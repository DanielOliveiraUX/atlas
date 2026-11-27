-- Perfil inicial de todo jogador novo. Campos novos adicionados aqui
-- são preenchidos automaticamente em perfis antigos (reconcile).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local DataConfig = require(Shared.Config.DataConfig)
local GameConfig = require(Shared.Config.GameConfig)

return {
	UserId = 0,
	SchemaVersion = DataConfig.SchemaVersion,
	TutorialCompleted = false,
	Coins = 0,
	CollectionLimit = GameConfig.CollectionLimit,
	Creatures = {},
	ActiveTeam = {
		Slot1 = false,
		Slot2 = false,
		Slot3 = false,
	},
	Inventory = {},
	Materials = {},
	Achievements = {},
	Cosmetics = {},
	Statistics = {},
	BaseData = {
		BaseLevel = 1,
		Decorations = {},
		Unlocks = {},
	},
}
