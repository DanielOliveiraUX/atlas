-- Catálogo da loja. Por enquanto só personalização de pet: é o que faz o
-- jogador se apegar ao bicho dele, e é barato de ampliar — cada item novo é
-- uma linha aqui, não um sistema novo.
--
-- Como um item é aplicado no pet está em `Efeito`:
--   Cor      = pinta um grupo de peças (Grupo: corpo, cabeca, cauda, patas)
--   Acessorio = prende uma peça no grupo, no deslocamento dado
--   Brilho   = troca a cor e o alcance da luz do bicho
--
-- O servidor valida a compra e guarda em profile.Cosmetics; quem desenha é
-- o PetService, ao montar o modelo.
local ShopConfig = {}

ShopConfig.Categorias = table.freeze({
	{ Id = "cor", NomeChave = "Shop.Cat.Cor" },
	{ Id = "acessorio", NomeChave = "Shop.Cat.Acessorio" },
	{ Id = "brilho", NomeChave = "Shop.Cat.Brilho" },
})

local function cor(id, nomeChave, preco, grupo, rgb, categoria)
	return {
		Id = id,
		NomeChave = nomeChave,
		Preco = preco,
		Categoria = categoria or "cor",
		Efeito = { Tipo = "Cor", Grupo = grupo, Cor = rgb },
	}
end

ShopConfig.Itens = table.freeze({
	-- Pelagens
	cor(
		"pelo_carvao", "Shop.pelo_carvao", 45, "corpo", Color3.fromRGB(78, 78, 88)
	),
	cor(
		"pelo_neve", "Shop.pelo_neve", 45, "corpo", Color3.fromRGB(240, 240, 236)
	),
	cor(
		"pelo_musgo", "Shop.pelo_musgo", 60, "corpo", Color3.fromRGB(110, 142, 92)
	),
	cor(
		"pelo_ameixa", "Shop.pelo_ameixa", 75, "corpo", Color3.fromRGB(142, 96, 158)
	),

	-- Detalhes
	cor(
		"meia_creme", "Shop.meia_creme", 35, "patas", Color3.fromRGB(246, 236, 212)
	),
	cor(
		"meia_tinta", "Shop.meia_tinta", 35, "patas", Color3.fromRGB(62, 70, 96)
	),
	cor(
		"ponta_cobre", "Shop.ponta_cobre", 40, "cauda", Color3.fromRGB(214, 132, 68)
	),

	-- Acessórios
	{
		Id = "lenco",
		NomeChave = "Shop.lenco",
		Preco = 70,
		Categoria = "acessorio",
		Efeito = {
			Tipo = "Acessorio",
			Grupo = "cabeca",
			Peca = { Tamanho = Vector3.new(0.9, 0.32, 0.9), Cor = Color3.fromRGB(214, 86, 86), Forma = "Bloco" },
			Deslocamento = Vector3.new(0, -0.18, 0.26),
		},
	},
	{
		Id = "chapeu_palha",
		NomeChave = "Shop.chapeu_palha",
		Preco = 110,
		Categoria = "acessorio",
		Efeito = {
			Tipo = "Acessorio",
			Grupo = "cabeca",
			Peca = { Tamanho = Vector3.new(1.5, 0.18, 1.5), Cor = Color3.fromRGB(226, 196, 126), Forma = "Cilindro" },
			Deslocamento = Vector3.new(0, 0.46, 0),
		},
	},
	{
		Id = "coleira",
		NomeChave = "Shop.coleira",
		Preco = 55,
		Categoria = "acessorio",
		Efeito = {
			Tipo = "Acessorio",
			Grupo = "cabeca",
			Peca = { Tamanho = Vector3.new(0.78, 0.2, 0.78), Cor = Color3.fromRGB(92, 128, 196), Forma = "Bloco" },
			Deslocamento = Vector3.new(0, -0.3, 0.34),
		},
	},

	-- Brilhos
	{
		Id = "brilho_gelo",
		NomeChave = "Shop.brilho_gelo",
		Preco = 90,
		Categoria = "brilho",
		Efeito = { Tipo = "Brilho", Cor = Color3.fromRGB(150, 220, 255), Alcance = 12 },
	},
	{
		Id = "brilho_brasa",
		NomeChave = "Shop.brilho_brasa",
		Preco = 90,
		Categoria = "brilho",
		Efeito = { Tipo = "Brilho", Cor = Color3.fromRGB(255, 142, 86), Alcance = 12 },
	},
	{
		Id = "brilho_verde",
		NomeChave = "Shop.brilho_verde",
		Preco = 120,
		Categoria = "brilho",
		Efeito = { Tipo = "Brilho", Cor = Color3.fromRGB(144, 255, 170), Alcance = 15 },
	},
})

function ShopConfig.Get(id: string)
	for _, item in ShopConfig.Itens do
		if item.Id == id then
			return item
		end
	end
	return nil
end

-- Grupos de peça que uma cor pode pintar, traduzidos para os nomes que a
-- armação usa (ver Util/CreatureRig).
ShopConfig.GruposDePeca = table.freeze({
	corpo = table.freeze({ "Corpo" }),
	cabeca = table.freeze({ "Cabeca" }),
	cauda = table.freeze({ "Cauda", "TailGlow" }),
	patas = table.freeze({ "PatasFrente", "PatasTras" }),
})

return ShopConfig
