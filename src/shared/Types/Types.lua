-- Tipos Luau compartilhados entre servidor e cliente.

export type Stats = {
	Health: number,
	Attack: number,
	Defense: number,
	Speed: number,
}

-- Uma criatura específica do jogador.
-- CreatureId é único; SpeciesId se repete entre criaturas da mesma espécie.
-- StorageState NÃO é salvo: é derivado de ActiveTeam (ver Util/TeamUtil).
export type CreatureInstance = {
	CreatureId: string,
	SpeciesId: string,
	Nickname: string?,
	Level: number,
	Experience: number,
	Stats: Stats,
	Skills: { string },
	EvolutionStage: number,
	FatigueUntil: number?, -- os.time() em que a fadiga termina; nil = descansado
	CaptureDate: number,
	DiscoveryOrigin: string,
}

-- false = slot vazio (DataStore não guarda nil dentro de tabelas)
export type ActiveTeam = {
	Slot1: string | false,
	Slot2: string | false,
	Slot3: string | false,
}

export type BaseData = {
	BaseLevel: number,
	Decorations: { [string]: any },
	Unlocks: { [string]: boolean },
}

export type PlayerProfile = {
	UserId: number,
	SchemaVersion: number,
	TutorialCompleted: boolean,
	Coins: number,
	CollectionLimit: number,
	Creatures: { [string]: CreatureInstance },
	ActiveTeam: ActiveTeam,
	Inventory: { [string]: number }, -- itens e ferramentas
	Materials: { [string]: number }, -- espólios: couro, pele, pelo, tecido...
	Achievements: { [string]: boolean },
	Cosmetics: { [string]: boolean },
	Statistics: { [string]: number },
	BaseData: BaseData,
}

return {}
