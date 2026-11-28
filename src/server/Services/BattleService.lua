-- Batalha contra criaturas selvagens, e o que vem depois dela.
--
-- O servidor é dono de tudo: energia, ordem de ataque, dano, espólio e
-- captura. O cliente só avisa "o jogador tocou na criatura" e "o jogador
-- escolheu espólios ou captura". Qualquer um desses pedidos é conferido
-- aqui antes de valer.
--
-- Desenho da luta, para quem for mexer depois:
--   * Nada ataca pelo lado do jogador sem um toque. Sem toque, sem golpe.
--   * A criatura selvagem revida sozinha, num intervalo fixo.
--   * A ordem dos pets é por energia restante: o mais inteiro bate primeiro,
--     e com empate vale a ordem dos slots. O jogador não escolhe nada no
--     meio da luta — ele só toca.
--   * Derrotada a criatura, ela não some: o jogador escolhe entre recolher
--     os espólios e capturá-la. São duas opções, não uma sequência.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BattleConfig = require(Shared.Config.BattleConfig)
local CreatureConfig = require(Shared.Config.CreatureConfig)
local Remotes = require(Shared.Remotes)
local TeamUtil = require(Shared.Util.TeamUtil)

local Services = script.Parent
local PlayerDataService = require(Services.PlayerDataService)
local CreatureService = require(Services.CreatureService)
local PetService = require(Services.PetService)

local BattleService = {}

type Lutador = {
	CreatureId: string,
	SpeciesId: string,
	Nome: string,
	Nivel: number,
	Vida: number,
	VidaMax: number,
	Ataque: number,
	Defesa: number,
	Velocidade: number,
	Skills: { string },
	Slot: number,
}

type Batalha = {
	player: Player,
	selvagem: Lutador,
	modelo: Model,
	equipe: { Lutador },
	proximoGolpeDoJogador: number,
	proximoGolpeDaSelvagem: number,
	encerrada: boolean,
	resultado: string?,
	espolioPego: boolean,
	capturaFeita: boolean,
	espolio: any,
}

local batalhas: { [Player]: Batalha } = {}

-- Montagem ---------------------------------------------------------------------

local function lutadorDoPet(creature, slot: number): Lutador
	local stats = CreatureConfig.GetStatsForLevel(creature.SpeciesId, creature.Level or 1)
	local species = CreatureConfig.Get(creature.SpeciesId)
	local vidaMax = stats.Health
	return {
		CreatureId = creature.CreatureId,
		SpeciesId = creature.SpeciesId,
		Nome = creature.Nickname or (species and species.NameKey) or creature.SpeciesId,
		Nivel = creature.Level or 1,
		-- A vida de combate não é guardada no perfil: cada batalha começa
		-- cheia. Fadiga é outro sistema e não entra aqui.
		Vida = vidaMax,
		VidaMax = vidaMax,
		Ataque = stats.Attack,
		Defesa = stats.Defense,
		Velocidade = stats.Speed,
		Skills = CreatureConfig.GetSkillsForLevel(creature.SpeciesId, creature.Level or 1),
		Slot = slot,
	}
end

local function lutadorSelvagem(speciesId: string, nivel: number): Lutador
	local stats = CreatureConfig.GetStatsForLevel(speciesId, nivel)
	local species = CreatureConfig.Get(speciesId)
	return {
		CreatureId = "selvagem",
		SpeciesId = speciesId,
		Nome = (species and species.NameKey) or speciesId,
		Nivel = nivel,
		Vida = stats.Health,
		VidaMax = stats.Health,
		Ataque = stats.Attack,
		Defesa = stats.Defense,
		Velocidade = stats.Speed,
		Skills = CreatureConfig.GetSkillsForLevel(speciesId, nivel),
		Slot = 0,
	}
end

-- O que o cliente precisa saber para desenhar as barras
local function instantaneo(b: Batalha)
	local equipe = {}
	for _, l in b.equipe do
		table.insert(equipe, {
			CreatureId = l.CreatureId,
			SpeciesId = l.SpeciesId,
			Nivel = l.Nivel,
			Vida = math.max(math.floor(l.Vida + 0.5), 0),
			VidaMax = l.VidaMax,
			Slot = l.Slot,
		})
	end
	return {
		Selvagem = {
			SpeciesId = b.selvagem.SpeciesId,
			Nivel = b.selvagem.Nivel,
			Vida = math.max(math.floor(b.selvagem.Vida + 0.5), 0),
			VidaMax = b.selvagem.VidaMax,
		},
		Equipe = equipe,
		Encerrada = b.encerrada,
		Resultado = b.resultado,
	}
end

local function enviar(nome: string, player: Player, ...)
	local remote = Remotes.Get(nome) :: RemoteEvent
	remote:FireClient(player, ...)
end

-- Quem bate agora: o pet mais inteiro, desempatando pelo slot.
local function proximoAtacante(b: Batalha): Lutador?
	local melhor: Lutador? = nil
	local melhorRazao = -1
	for _, l in b.equipe do
		if l.Vida > 0 then
			local razao = l.Vida / math.max(l.VidaMax, 1)
			if razao > melhorRazao + 0.0001
				or (math.abs(razao - melhorRazao) <= 0.0001 and melhor and l.Slot < melhor.Slot)
			then
				melhor = l
				melhorRazao = razao
			end
		end
	end
	return melhor
end

local function equipeDePe(b: Batalha): boolean
	for _, l in b.equipe do
		if l.Vida > 0 then
			return true
		end
	end
	return false
end

-- Espólio -------------------------------------------------------------------------

local function sortearEspolio(speciesId: string)
	local species = CreatureConfig.Get(speciesId)
	local tabela = BattleConfig.LootFor(species and species.Rarity)
	local moedas = math.random(tabela.Moedas[1], tabela.Moedas[2])
	local materiais = {}
	for _, m in tabela.Materiais do
		if math.random() <= m.Chance then
			materiais[m.Id] = math.random(m.Min, m.Max)
		end
	end
	return { Moedas = moedas, Materiais = materiais }
end

-- Fim da batalha ---------------------------------------------------------------------

local function encerrar(b: Batalha, resultado: string)
	if b.encerrada then
		return
	end
	b.encerrada = true
	b.resultado = resultado

	if resultado == "Vitoria" then
		b.espolio = sortearEspolio(b.selvagem.SpeciesId)
		-- o WildService escuta este atributo e faz a criatura tombar
		if b.modelo and b.modelo.Parent then
			b.modelo:SetAttribute("Desmaiada", true)
		end
	end

	local data = PlayerDataService:GetData(b.player)
	local podeCapturar = resultado == "Vitoria" and data ~= nil and not CreatureService:IsFull(b.player)

	enviar("BattleEnd", b.player, {
		Resultado = resultado,
		Selvagem = {
			SpeciesId = b.selvagem.SpeciesId,
			Nivel = b.selvagem.Nivel,
		},
		Espolio = b.espolio,
		PodeCapturar = podeCapturar,
	})
end

local function limpar(player: Player)
	local b = batalhas[player]
	if not b then
		return
	end
	batalhas[player] = nil
	PetService:SairDeCombate(player)
	if b.modelo and b.modelo.Parent then
		b.modelo:SetAttribute("EmBatalha", false)
	end
end

-- Início -----------------------------------------------------------------------------

function BattleService:Comecar(player: Player, modelo: Model): boolean
	if batalhas[player] then
		return false
	end
	local data = PlayerDataService:GetData(player)
	if not data then
		return false
	end

	local equipe: { Lutador } = {}
	for slot, key in TeamUtil.SlotKeys do
		local id = data.ActiveTeam[key]
		local creature = id and data.Creatures[id]
		if creature then
			table.insert(equipe, lutadorDoPet(creature, slot))
		end
	end
	if #equipe == 0 then
		return false -- sem pet equipado não há com o que lutar
	end

	local speciesId = modelo:GetAttribute("SpeciesId") or "mirra"
	local nivel = modelo:GetAttribute("Nivel") or 2

	local agora = os.clock()
	local b: Batalha = {
		player = player,
		selvagem = lutadorSelvagem(speciesId, nivel),
		modelo = modelo,
		equipe = equipe,
		proximoGolpeDoJogador = agora,
		proximoGolpeDaSelvagem = agora + BattleConfig.FirstEnemyDelay,
		encerrada = false,
		resultado = nil,
		espolioPego = false,
		capturaFeita = false,
		espolio = nil,
	}
	batalhas[player] = b
	modelo:SetAttribute("EmBatalha", true)

	PetService:EntrarEmCombate(player, modelo)
	enviar("BattleStart", player, instantaneo(b))
	return true
end

-- Golpes -------------------------------------------------------------------------------

local function golpeDoJogador(b: Batalha)
	local atacante = proximoAtacante(b)
	if not atacante then
		return
	end
	local skill = atacante.Skills[#atacante.Skills] -- o golpe mais recente que ele aprendeu
	local dano = BattleConfig.Damage(atacante.Ataque, b.selvagem.Defesa, BattleConfig.SkillMultiplier(skill))
	dano *= 1 + (math.random() * 2 - 1) * BattleConfig.DamageSpread
	dano = math.max(math.floor(dano + 0.5), 1)

	b.selvagem.Vida = math.max(b.selvagem.Vida - dano, 0)
	PetService:Investir(b.player)

	enviar("BattleUpdate", b.player, {
		Estado = instantaneo(b),
		Golpe = {
			De = "pet",
			CreatureId = atacante.CreatureId,
			Slot = atacante.Slot,
			Skill = skill,
			Dano = dano,
		},
	})

	if b.selvagem.Vida <= 0 then
		encerrar(b, "Vitoria")
	end
end

local function golpeDaSelvagem(b: Batalha)
	local alvo = proximoAtacante(b) -- bate em quem está na frente
	if not alvo then
		encerrar(b, "Derrota")
		return
	end
	local skill = b.selvagem.Skills[1]
	local dano = BattleConfig.Damage(b.selvagem.Ataque, alvo.Defesa, BattleConfig.SkillMultiplier(skill))
	dano *= 1 + (math.random() * 2 - 1) * BattleConfig.DamageSpread
	dano = math.max(math.floor(dano + 0.5), 1)

	alvo.Vida = math.max(alvo.Vida - dano, 0)

	enviar("BattleUpdate", b.player, {
		Estado = instantaneo(b),
		Golpe = {
			De = "selvagem",
			AlvoCreatureId = alvo.CreatureId,
			Slot = alvo.Slot,
			Skill = skill,
			Dano = dano,
		},
	})

	if not equipeDePe(b) then
		encerrar(b, "Derrota")
	end
end

-- Pedidos do cliente -----------------------------------------------------------------------

local function aoAtacar(player: Player)
	local b = batalhas[player]
	if not b or b.encerrada then
		return
	end
	local agora = os.clock()
	if agora < b.proximoGolpeDoJogador then
		return -- toque rápido demais; o servidor é quem manda no ritmo
	end
	b.proximoGolpeDoJogador = agora + BattleConfig.PlayerCooldown
	golpeDoJogador(b)
end

local function aoEscolher(player: Player, escolha: string)
	local b = batalhas[player]
	if not (b and b.encerrada and b.resultado == "Vitoria") then
		return
	end
	local data = PlayerDataService:GetData(player)
	if not data then
		return
	end

	if escolha == "espolios" then
		if b.espolioPego or not b.espolio then
			return
		end
		b.espolioPego = true
		data.Coins = (data.Coins or 0) + b.espolio.Moedas
		data.Materials = data.Materials or {}
		for id, quantidade in b.espolio.Materiais do
			data.Materials[id] = (data.Materials[id] or 0) + quantidade
		end
		enviar("WalletUpdate", player, { Coins = data.Coins, Materials = data.Materials })
		enviar("BattleUpdate", player, { EspolioPego = true })
		return
	end

	if escolha == "capturar" then
		if b.capturaFeita then
			return
		end
		if CreatureService:IsFull(player) then
			enviar("BattleUpdate", player, { CapturaFalhou = "cheia" })
			return
		end
		b.capturaFeita = true
		CreatureService:Grant(player, b.selvagem.SpeciesId, "captura", b.selvagem.Nivel)
		enviar("BattleUpdate", player, { CapturaFeita = true })
		if b.modelo and b.modelo.Parent then
			b.modelo:SetAttribute("Capturada", true)
		end
		return
	end
end

local function aoSair(player: Player)
	local b = batalhas[player]
	if not b then
		return
	end
	-- quem não capturou deixa a criatura no mundo; quem capturou, ela sumiu
	if b.modelo and b.modelo.Parent then
		b.modelo:SetAttribute("Resolvida", b.capturaFeita)
	end
	limpar(player)
end

-- Relógio ---------------------------------------------------------------------------------

local function tique()
	local agora = os.clock()
	for player, b in batalhas do
		if b.encerrada then
			continue
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not (root and b.modelo and b.modelo.Parent) then
			encerrar(b, "Fuga")
			continue
		end
		-- afastou-se demais: a criatura perde o interesse
		if (root.Position - b.modelo:GetPivot().Position).Magnitude > BattleConfig.LeashDistance then
			encerrar(b, "Fuga")
			continue
		end
		if agora >= b.proximoGolpeDaSelvagem then
			b.proximoGolpeDaSelvagem = agora + BattleConfig.EnemyInterval
			golpeDaSelvagem(b)
		end
	end
end

function BattleService:EstaEmBatalha(player: Player): boolean
	return batalhas[player] ~= nil
end

-- Clicar na criatura no mundo também ataca. O ClickDetector roda NO
-- SERVIDOR, então ele não pode disparar um RemoteEvent para si mesmo:
-- tem que entrar pela mesma porta que o toque na tela usa.
function BattleService:Atacar(player: Player)
	aoAtacar(player)
end

-- Quem está lutando contra este modelo
function BattleService:AlvoDe(player: Player): Model?
	local b = batalhas[player]
	return b and b.modelo or nil
end

function BattleService:Start()
	(Remotes.Get("BattleAttack") :: RemoteEvent).OnServerEvent:Connect(aoAtacar)
	;(Remotes.Get("BattleChoice") :: RemoteEvent).OnServerEvent:Connect(function(player, escolha)
		if type(escolha) == "string" then
			aoEscolher(player, escolha)
		end
	end)
	;(Remotes.Get("BattleLeave") :: RemoteEvent).OnServerEvent:Connect(aoSair)

	Players.PlayerRemoving:Connect(limpar)
	RunService.Heartbeat:Connect(tique)
end

return BattleService
