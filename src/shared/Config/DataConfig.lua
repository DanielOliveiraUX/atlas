-- Persistência dos dados do jogador.
local DataConfig = {
	StoreName = "PlayerData",
	KeyPrefix = "Player_",
	SchemaVersion = 1, -- subir ao mudar o formato; criar migração em server/Data/Migrations

	AutosaveInterval = 60, -- segundos
	LockTimeout = 30 * 60, -- trava de sessão expira após 30 min sem renovação
	LoadRetries = 5,
	RetryDelay = 3, -- segundos entre tentativas
}

return table.freeze(DataConfig)
