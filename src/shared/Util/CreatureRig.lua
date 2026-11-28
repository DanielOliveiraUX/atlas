-- Armação de caminhada das criaturas, usada pelo pet do jogador
-- (PetService) e pelas selvagens (WildService).
--
-- Os modelos não têm esqueleto: a caminhada é feita girando grupos de peças
-- em volta de um pivô. Um grupo é qualquer peça cujo nome, ou o nome de
-- algum pai dela dentro do modelo, seja um dos nomes conhecidos.
--
-- Isso permite as duas formas de montar uma criatura:
--   * Lumi: peças soltas chamadas Cabeca, Cauda, PatasFrente, PatasTras.
--   * Cauim: modelos com esses nomes, cheios de pecinhas dentro.
local CreatureRig = {}

CreatureRig.Grupos = table.freeze({
	Cabeca = "cabeca",
	Cauda = "cauda",
	TailGlow = "cauda",
	PatasFrente = "frente",
	PatasTras = "tras",
})

export type Peca = { parte: BasePart, repouso: CFrame, pivo: Vector3, grupo: string }

-- Sobe pela árvore até achar um nome de grupo conhecido.
local function grupoDe(parte: Instance, raiz: Instance): string?
	local atual: Instance? = parte
	while atual and atual ~= raiz do
		local grupo = CreatureRig.Grupos[atual.Name]
		if grupo then
			return grupo
		end
		atual = atual.Parent
	end
	return nil
end

-- Monta a lista de peças móveis. O pivô vem do atributo PivoX/Y/Z quando
-- existe (gravado junto com o modelo) e, quando não existe, é deduzido:
-- pata gira pelo topo, cabeça e cauda giram pela base.
function CreatureRig.Montar(modelo: Model, corpo: BasePart): { Peca }
	local pecas: { Peca } = {}
	local pivoDoGrupo: { [string]: Vector3 } = {}

	for _, d in modelo:GetDescendants() do
		if d:IsA("BasePart") and d ~= corpo then
			local grupo = grupoDe(d, modelo)
			if grupo then
				local pivo: Vector3
				local px, py, pz = d:GetAttribute("PivoX"), d:GetAttribute("PivoY"), d:GetAttribute("PivoZ")
				if px and py and pz then
					pivo = Vector3.new(px, py, pz)
				elseif pivoDoGrupo[grupo] then
					pivo = pivoDoGrupo[grupo]
				else
					local sinal = if grupo == "frente" or grupo == "tras" then 1 else -1
					pivo = corpo.CFrame:PointToObjectSpace(d.Position + Vector3.new(0, (d.Size.Y / 2) * sinal, 0))
				end
				pivoDoGrupo[grupo] = pivo
				table.insert(pecas, {
					parte = d,
					repouso = corpo.CFrame:ToObjectSpace(d.CFrame),
					pivo = pivo,
					grupo = grupo,
				})
			end
		end
	end
	return pecas
end

-- Põe o tronco no lugar e, a partir dele, cada peça girada no próprio pivô.
function CreatureRig.Aplicar(corpo: BasePart, pecas: { Peca }, corpoCF: CFrame, rotacoes: { [string]: CFrame })
	corpo.CFrame = corpoCF
	for _, peca in pecas do
		local rot = rotacoes[peca.grupo]
		if rot then
			local pivo = CFrame.new(peca.pivo)
			peca.parte.CFrame = corpoCF * pivo * rot * pivo:Inverse() * peca.repouso
		else
			peca.parte.CFrame = corpoCF * peca.repouso
		end
	end
end

-- Distância do tronco até a sola, para o bicho pousar no chão em vez de
-- afundar ou pairar.
function CreatureRig.SolaOffset(modelo: Model, corpo: BasePart): number
	local cf, size = modelo:GetBoundingBox()
	return corpo.Position.Y - (cf.Position.Y - size.Y / 2)
end

-- A maior peça é o tronco. Nunca a primeira que aparecer: no Lumi antigo
-- isso pegava o brilho da cauda e jogava o pivô para fora do corpo.
function CreatureRig.AcharCorpo(modelo: Model): BasePart?
	local direto = modelo:FindFirstChild("Corpo")
	if direto and direto:IsA("BasePart") then
		return direto
	end
	local maior: BasePart? = nil
	for _, d in modelo:GetDescendants() do
		if d:IsA("BasePart") then
			local v = d.Size.X * d.Size.Y * d.Size.Z
			if not maior or v > (maior.Size.X * maior.Size.Y * maior.Size.Z) then
				maior = d
			end
		end
	end
	return maior
end

return CreatureRig
