-- Tradução por chave (tabela em src/localization/UI.csv). Idiomas: PT, EN, ES.
-- Uso: Localization.Get(player, "UI.Loading") ou Localization.Get(player, "Fatigue.Remaining", { seconds = 8 })
--
-- Em place NÃO publicado, GetTranslatorForPlayerAsync sempre falha
-- ("Publishing the game is required"). Sem um plano B, toda a interface
-- aparece com a chave crua durante os testes no Studio. Por isso caímos,
-- em ordem, para o tradutor do idioma do jogador e depois para o idioma de
-- origem — só então devolvemos a chave.
local LocalizationService = game:GetService("LocalizationService")
local RunService = game:GetService("RunService")

local Localization = {}

local SOURCE_LOCALE = "pt-br"

local byPlayer = setmetatable({}, { __mode = "k" })
local byLocale: { [string]: any } = {}
local failedLocale: { [string]: boolean } = {}

local function translatorForLocale(locale: string?)
	if not locale or locale == "" or failedLocale[locale] then
		return nil
	end
	local cached = byLocale[locale]
	if cached ~= nil then
		return cached
	end
	local ok, translator = pcall(function()
		return LocalizationService:GetTranslatorForLocaleAsync(locale)
	end)
	if ok and translator then
		byLocale[locale] = translator
		return translator
	end
	failedLocale[locale] = true
	return nil
end

-- Idioma do jogador, sem depender do jogo estar publicado
local function localeFor(player: Player?): string?
	if player then
		local ok, locale = pcall(function()
			return player.LocaleId
		end)
		if ok and locale and locale ~= "" then
			return locale
		end
	end
	if RunService:IsClient() then
		return LocalizationService.RobloxLocaleId
	end
	return nil
end

-- Tradutores candidatos, do mais específico para o mais genérico
local function translatorsFor(player: Player?)
	local list = {}

	local cached = byPlayer[player]
	if cached == nil and player then
		local ok, translator = pcall(function()
			return LocalizationService:GetTranslatorForPlayerAsync(player)
		end)
		cached = if ok and translator then translator else false
		byPlayer[player] = cached
	end
	if cached then
		table.insert(list, cached)
	end

	local locale = localeFor(player)
	local byLocaleTranslator = translatorForLocale(locale)
	if byLocaleTranslator then
		table.insert(list, byLocaleTranslator)
	end

	if locale ~= SOURCE_LOCALE then
		local source = translatorForLocale(SOURCE_LOCALE)
		if source then
			table.insert(list, source)
		end
	end

	return list
end

function Localization.Get(player: Player?, key: string, args: { [string]: any }?): string
	for _, translator in translatorsFor(player) do
		local ok, text = pcall(function()
			return translator:FormatByKey(key, args)
		end)
		if ok and text and text ~= "" then
			return text
		end
	end
	return key -- fallback visível para achar chaves faltando
end

return Localization
