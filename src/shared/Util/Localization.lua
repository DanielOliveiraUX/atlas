-- Tradução por chave (tabela em src/localization/UI.csv). Idiomas: PT, EN, ES.
-- Uso: Localization.Get(player, "UI.Loading") ou Localization.Get(player, "Fatigue.Remaining", { seconds = 8 })
local LocalizationService = game:GetService("LocalizationService")

local Localization = {}

local translators = setmetatable({}, { __mode = "k" })

local function getTranslator(player: Player)
	local cached = translators[player]
	if cached then
		return cached
	end
	local ok, translator = pcall(function()
		return LocalizationService:GetTranslatorForPlayerAsync(player)
	end)
	if ok and translator then
		translators[player] = translator
		return translator
	end
	return nil
end

function Localization.Get(player: Player, key: string, args: { [string]: any }?): string
	local translator = getTranslator(player)
	if translator then
		local ok, text = pcall(function()
			return translator:FormatByKey(key, args)
		end)
		if ok and text then
			return text
		end
	end
	return key -- fallback visível para achar chaves faltando
end

return Localization
