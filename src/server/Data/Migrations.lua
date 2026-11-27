-- Migrações de esquema. Ao subir DataConfig.SchemaVersion de N para N+1,
-- adicione Steps[N] = function(data) ... return data end
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataConfig = require(ReplicatedStorage:WaitForChild("Shared").Config.DataConfig)

local Migrations = {}

local Steps: { [number]: (any) -> any } = {
	-- [1] = function(data) -- 1 -> 2
	-- 	data.NovoCampo = 0
	-- 	return data
	-- end,
}

function Migrations.Run(data)
	local target = DataConfig.SchemaVersion
	data.SchemaVersion = data.SchemaVersion or 1

	while data.SchemaVersion < target do
		local step = Steps[data.SchemaVersion]
		if not step then
			error(("Migração ausente: versão %d -> %d"):format(data.SchemaVersion, data.SchemaVersion + 1))
		end
		data = step(data)
		data.SchemaVersion += 1
	end

	return data
end

return Migrations
