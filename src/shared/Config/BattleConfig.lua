-- Regras da batalha contra criaturas selvagens.
--
-- A batalha é por toque: o jogador encosta o dedo na criatura selvagem e o
-- pet da vez ataca. Nada acontece sozinho do lado do jogador — sem toque,
-- sem ataque. A criatura revida por conta própria, num intervalo fixo.
--
-- Os números daqui são o balanceamento inteiro da luta. Nenhum deles deve
-- aparecer solto no meio do código dos serviços.
local BattleConfig = {}

-- Alcance
BattleConfig.EngageDistance = 26 -- a que distância a selvagem percebe e desafia
BattleConfig.LeashDistance = 70 -- longe assim, a batalha se desfaz

-- Ritmo
BattleConfig.PlayerCooldown = 0.7 -- intervalo mínimo entre dois toques
BattleConfig.EnemyInterval = 3.2 -- de quanto em quanto tempo a selvagem ataca
BattleConfig.FirstEnemyDelay = 3.0 -- folga antes do primeiro golpe dela
BattleConfig.FaintDuration = 1.9 -- tempo da animação de desmaio
BattleConfig.CaptureDuration = 2.2 -- tempo do envolvimento em energia

-- Dano. Fórmula simples e legível: o ataque de quem bate contra a defesa de
-- quem apanha, com um piso para nenhum golpe ser inútil e uma variação
-- pequena para dois golpes iguais não darem sempre o mesmo número.
BattleConfig.DamageFloor = 2
BattleConfig.DamageSpread = 0.15 -- ±15%
BattleConfig.DefenseWeight = 0.55 -- quanto a defesa corta do ataque

function BattleConfig.Damage(attack: number, defense: number, multiplier: number?): number
	local bruto = attack - defense * BattleConfig.DefenseWeight
	local base = math.max(bruto, BattleConfig.DamageFloor)
	return base * (multiplier or 1)
end

-- Golpes. Multiplicador sobre o dano base e um peso para a ordem de uso.
BattleConfig.Skills = table.freeze({
	investida = { Multiplicador = 1.0, NomeChave = "Skill.investida" },
	clarao = { Multiplicador = 1.35, NomeChave = "Skill.clarao" },
	aconchego = { Multiplicador = 0.7, NomeChave = "Skill.aconchego" },
	luzguia = { Multiplicador = 1.5, NomeChave = "Skill.luzguia" },
	mordida = { Multiplicador = 1.1, NomeChave = "Skill.mordida" },
	rajada = { Multiplicador = 1.25, NomeChave = "Skill.rajada" },
})

function BattleConfig.SkillMultiplier(skillId: string?): number
	local s = skillId and BattleConfig.Skills[skillId]
	return (s and s.Multiplicador) or 1
end

-- Ordem de ataque da equipe: quem está mais descansado bate primeiro.
-- Com energia igual, vale a ordem dos slots. Assim o jogador não precisa
-- escolher nada no meio da luta — ele só toca na criatura.
BattleConfig.OrderBy = "VidaRestantePercentual"

-- Captura. A criatura só pode ser capturada abaixo do limiar da espécie
-- (CreatureConfig.GetCaptureThreshold), e derrotá-la zera a energia dela,
-- então depois da vitória a captura está sempre liberada.
BattleConfig.CaptureAlwaysAfterFaint = true

-- Espólios por raridade da criatura derrotada. Quantidade sorteada no
-- intervalo. "Materiais" entram em profile.Materials; "Moedas" em Coins.
BattleConfig.Loot = table.freeze({
	Common = table.freeze({
		Moedas = { 12, 26 },
		Materiais = table.freeze({
			{ Id = "fibra", Chance = 0.8, Min = 1, Max = 3 },
			{ Id = "areia_fina", Chance = 0.5, Min = 1, Max = 2 },
		}),
	}),
	Uncommon = table.freeze({
		Moedas = { 24, 48 },
		Materiais = table.freeze({
			{ Id = "fibra", Chance = 0.9, Min = 2, Max = 4 },
			{ Id = "areia_fina", Chance = 0.6, Min = 1, Max = 3 },
			{ Id = "cristal_morno", Chance = 0.25, Min = 1, Max = 1 },
		}),
	}),
	Rare = table.freeze({
		Moedas = { 50, 90 },
		Materiais = table.freeze({
			{ Id = "cristal_morno", Chance = 0.7, Min = 1, Max = 2 },
			{ Id = "essencia", Chance = 0.3, Min = 1, Max = 1 },
		}),
	}),
	Legendary = table.freeze({
		Moedas = { 120, 200 },
		Materiais = table.freeze({
			{ Id = "essencia", Chance = 0.9, Min = 1, Max = 3 },
		}),
	}),
})

function BattleConfig.LootFor(rarity: string?)
	return BattleConfig.Loot[rarity or "Common"] or BattleConfig.Loot.Common
end

-- Criaturas selvagens que nascem em cada região.
BattleConfig.WildSpawns = table.freeze({
	Dunas = table.freeze({
		{ SpeciesId = "mirra", Nivel = { 1, 3 } },
	}),
})

BattleConfig.RespawnDelay = 25 -- segundos até outra selvagem nascer no lugar

return BattleConfig
