-- Fonte de verdade da equipe: ActiveTeam. StorageState é derivado daqui.
local TeamUtil = {}

TeamUtil.SlotKeys = table.freeze({ "Slot1", "Slot2", "Slot3" })

function TeamUtil.IsEquipped(team, creatureId: string): boolean
	for _, key in TeamUtil.SlotKeys do
		if team[key] == creatureId then
			return true
		end
	end
	return false
end

-- "Equipped" ou "Stored"
function TeamUtil.GetStorageState(team, creatureId: string): string
	return if TeamUtil.IsEquipped(team, creatureId) then "Equipped" else "Stored"
end

function TeamUtil.GetEquippedIds(team): { string }
	local ids = {}
	for _, key in TeamUtil.SlotKeys do
		local id = team[key]
		if id then
			table.insert(ids, id)
		end
	end
	return ids
end

function TeamUtil.IsFatigued(creature, now: number?): boolean
	local untilTime = creature.FatigueUntil
	return untilTime ~= nil and (now or os.time()) < untilTime
end

return TeamUtil
