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

-- Último recurso: ler a tabela direto.
--
-- Em place não publicado, nenhum tradutor responde e a interface inteira
-- aparecia com a chave crua ("Tutorial.GoToMentor.Title"). A coluna Source do
-- CSV já é o texto em PT-BR, então basta lê-la da própria LocalizationTable.
-- Não depende de publicação, de idioma de origem configurado nem de nada em
-- tempo de execução.
local sourceByKey: { [string]: string }? = nil

local function sourceTable(): { [string]: string }
	if sourceByKey then
		return sourceByKey
	end
	local map = {}
	local table_ = LocalizationService:FindFirstChildWhichIsA("LocalizationTable", true)
	if table_ then
		local ok, entries = pcall(function()
			return table_:GetEntries()
		end)
		if ok and entries then
			for _, entry in entries do
				if entry.Key and entry.Source then
					map[entry.Key] = entry.Source
				end
			end
		end
	end
	sourceByKey = map
	return map
end

-- Mesma substituição que o FormatByKey faz: {nome} vira o argumento
local function interpolate(text: string, args: { [string]: any }?): string
	if not args then
		return text
	end
	return (string.gsub(text, "{(%w+)}", function(name)
		local value = args[name]
		return if value ~= nil then tostring(value) else "{" .. name .. "}"
	end))
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

	local source = sourceTable()[key]
	if source then
		return interpolate(source, args)
	end

	return key -- fallback visível para achar chaves faltando
end

return Localization
