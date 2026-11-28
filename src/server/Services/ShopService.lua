-- Loja: compra e equipagem de itens de personalização do pet.
--
-- O servidor é dono do dinheiro e do inventário. O cliente só pede; aqui a
-- gente confere se o item existe, se dá o dinheiro e se já não foi comprado.
--
-- O que o jogador compra fica em profile.Cosmetics.Comprados; o que ele
-- está usando fica em profile.Cosmetics.Equipados, uma entrada por
-- categoria (uma pelagem, um acessório, um brilho por vez).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local ShopConfig = require(Shared.Config.ShopConfig)

local Services = script.Parent
local PlayerDataService = require(Services.PlayerDataService)
local PetService = require(Services.PetService)

local ShopService = {}

local function cosmeticos(data)
	data.Cosmetics = data.Cosmetics or {}
	data.Cosmetics.Comprados = data.Cosmetics.Comprados or {}
	data.Cosmetics.Equipados = data.Cosmetics.Equipados or {}
	return data.Cosmetics
end

function ShopService:Replicar(player: Player)
	local data = PlayerDataService:GetData(player)
	if not data then
		return
	end
	local c = cosmeticos(data)
	local remote = Remotes.Get("ShopUpdate") :: RemoteEvent
	remote:FireClient(player, {
		Coins = data.Coins or 0,
		Comprados = c.Comprados,
		Equipados = c.Equipados,
	})
end

local function comprar(player: Player, itemId: string)
	local data = PlayerDataService:GetData(player)
	if not data then
		return
	end
	local item = ShopConfig.Get(itemId)
	if not item then
		return
	end
	local c = cosmeticos(data)
	if c.Comprados[itemId] then
		return -- já é dele
	end
	if (data.Coins or 0) < item.Preco then
		local remote = Remotes.Get("ShopResult") :: RemoteEvent
		remote:FireClient(player, { Erro = "semMoedas", ItemId = itemId })
		return
	end

	data.Coins -= item.Preco
	c.Comprados[itemId] = true
	-- comprou, já veste: ninguém compra uma coleira para deixar na gaveta
	c.Equipados[item.Categoria] = itemId

	ShopService:Replicar(player)
	PetService:AtualizarVisual(player)

	local remote = Remotes.Get("ShopResult") :: RemoteEvent
	remote:FireClient(player, { Comprado = itemId })
end

local function equipar(player: Player, itemId: string?)
	local data = PlayerDataService:GetData(player)
	if not data then
		return
	end
	local c = cosmeticos(data)

	if itemId == nil then
		return
	end
	local item = ShopConfig.Get(itemId)
	if not item or not c.Comprados[itemId] then
		return
	end
	-- tocar no que já está vestido tira
	if c.Equipados[item.Categoria] == itemId then
		c.Equipados[item.Categoria] = nil
	else
		c.Equipados[item.Categoria] = itemId
	end
	ShopService:Replicar(player)
	PetService:AtualizarVisual(player)
end

function ShopService:Start()
	(Remotes.Get("ShopBuy") :: RemoteEvent).OnServerEvent:Connect(function(player, itemId)
		if type(itemId) == "string" then
			comprar(player, itemId)
		end
	end)
	;(Remotes.Get("ShopEquip") :: RemoteEvent).OnServerEvent:Connect(function(player, itemId)
		if type(itemId) == "string" then
			equipar(player, itemId)
		end
	end)

	PlayerDataService.ProfileLoaded:Connect(function(player)
		task.defer(function()
			ShopService:Replicar(player)
		end)
	end)
	for _, player in Players:GetPlayers() do
		ShopService:Replicar(player)
	end
end

return ShopService
