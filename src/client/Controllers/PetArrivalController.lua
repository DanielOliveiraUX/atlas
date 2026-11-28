-- O pet aparece numa explosão de magia, ao lado do jogador.
--
-- Cena puramente visual do tutorial. Não é o pet de verdade — o pet do mundo
-- só nasce quando o jogador equipa (PetService). Por isso este clone se apaga
-- sozinho assim que o PetService põe o verdadeiro em cena, para não existirem
-- dois iguais lado a lado.
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CreatureConfig = require(Shared.Config.CreatureConfig)
local Remotes = require(Shared.Remotes)

local player = Players.LocalPlayer

local PetArrivalController = {}

local arrivedEvent = Instance.new("BindableEvent")
-- Dispara quando a magia termina e o pet está de pé ao lado do jogador
PetArrivalController.Arrived = arrivedEvent.Event

local cinematicPet: Model? = nil
local revealConnection: RBXScriptConnection? = nil
local watchConnection: RBXScriptConnection? = nil

-- Tempos da cena
local CHARGE_TIME = 0.75 -- a energia se junta no chão
local BURST_TIME = 0.35 -- o estouro
local REVEAL_TIME = 0.55 -- o pet cresce de dentro da luz

local MAGIC_COLOR = Color3.fromRGB(255, 214, 120)
local MAGIC_GLOW = Color3.fromRGB(255, 240, 200)

-- Peças da magia ---------------------------------------------------------------

local function anchoredPart(name: string, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = MAGIC_COLOR
	part.Parent = parent
	return part
end

-- Anel que se abre no chão, como onda de choque
local function shockwave(position: Vector3, parent: Instance)
	local ring = anchoredPart("Onda", parent)
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.4, 1, 1)
	-- cilindro deitado: o eixo X vira a altura, então giramos para o chão
	ring.CFrame = CFrame.new(position + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	ring.Transparency = 0.15

	TweenService:Create(ring, TweenInfo.new(0.55, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.4, 22, 22),
		Transparency = 1,
	}):Play()
	Debris:AddItem(ring, 0.7)
end

-- Fagulhas que saem do centro
local function sparks(position: Vector3, parent: Instance)
	for index = 1, 20 do
		local spark = anchoredPart("Fagulha", parent)
		spark.Shape = Enum.PartType.Ball
		spark.Size = Vector3.new(0.5, 0.5, 0.5)
		spark.CFrame = CFrame.new(position)
		spark.Color = if index % 3 == 0 then MAGIC_GLOW else MAGIC_COLOR

		local angle = (index / 20) * math.pi * 2 + math.random() * 0.3
		local reach = 4.5 + math.random() * 3.5
		local destino = position
			+ Vector3.new(math.cos(angle) * reach, 1.5 + math.random() * 3, math.sin(angle) * reach)

		local tempo = 0.45 + math.random() * 0.25
		TweenService:Create(spark, TweenInfo.new(tempo, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
			CFrame = CFrame.new(destino),
			Size = Vector3.new(0.05, 0.05, 0.05),
			Transparency = 1,
		}):Play()
		Debris:AddItem(spark, tempo + 0.1)
	end
end

-- Coluna de luz que sobe no estouro. É o que dá leitura de magia; só o clarão
-- vira um borrão branco e não se entende o que aconteceu.
local function pillar(position: Vector3, parent: Instance)
	local coluna = anchoredPart("Coluna", parent)
	coluna.Shape = Enum.PartType.Cylinder
	coluna.Size = Vector3.new(14, 3.2, 3.2)
	coluna.CFrame = CFrame.new(position + Vector3.new(0, 7, 0)) * CFrame.Angles(0, 0, math.rad(90))
	coluna.Transparency = 0.25
	coluna.Color = MAGIC_GLOW

	TweenService:Create(coluna, TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
		Size = Vector3.new(20, 0.2, 0.2),
		Transparency = 1,
	}):Play()
	Debris:AddItem(coluna, 0.7)
end

-- Luz que carrega, estoura e apaga
local function flash(position: Vector3, parent: Instance)
	local core = anchoredPart("Nucleo", parent)
	core.Shape = Enum.PartType.Ball
	core.Size = Vector3.new(0.5, 0.5, 0.5)
	core.CFrame = CFrame.new(position + Vector3.new(0, 1.2, 0))
	core.Color = MAGIC_GLOW

	local light = Instance.new("PointLight")
	light.Color = MAGIC_COLOR
	light.Range = 8
	light.Brightness = 1
	light.Parent = core

	-- carrega
	TweenService:Create(core, TweenInfo.new(CHARGE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Size = Vector3.new(2.2, 2.2, 2.2),
	}):Play()
	TweenService:Create(light, TweenInfo.new(CHARGE_TIME), { Brightness = 2.4, Range = 13 }):Play()

	task.delay(CHARGE_TIME, function()
		if not core.Parent then
			return
		end
		-- estoura
		TweenService:Create(core, TweenInfo.new(BURST_TIME, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
			Size = Vector3.new(4.5, 4.5, 4.5),
			Transparency = 1,
		}):Play()
		TweenService:Create(light, TweenInfo.new(BURST_TIME + 0.4), { Brightness = 0, Range = 17 }):Play()
	end)

	Debris:AddItem(core, CHARGE_TIME + BURST_TIME + 0.6)
end

-- Cena ---------------------------------------------------------------------------

local function cleanup()
	if revealConnection then
		revealConnection:Disconnect()
		revealConnection = nil
	end
	if cinematicPet then
		cinematicPet:Destroy()
		cinematicPet = nil
	end
end

function PetArrivalController:Clear()
	if watchConnection then
		watchConnection:Disconnect()
		watchConnection = nil
	end
	cleanup()
end

-- Apaga o clone quando o pet de verdade aparecer
local function watchForRealPet()
	if watchConnection then
		watchConnection:Disconnect()
	end
	watchConnection = workspace.ChildAdded:Connect(function(child)
		if child:IsA("Model") and child.Name == "Pet_" .. player.Name then
			PetArrivalController:Clear()
		end
	end)
end

-- Escala o modelo inteiro em torno do próprio pivô, para ele brotar da luz.
local function scaleModel(model: Model, base: CFrame, offsets: { [BasePart]: CFrame }, sizes: { [BasePart]: Vector3 }, factor: number)
	for part, offset in offsets do
		part.Size = sizes[part] * factor
		part.CFrame = base * CFrame.new(offset.Position * factor) * (offset - offset.Position)
	end
end

function PetArrivalController:Play(speciesId: string)
	cleanup()

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		arrivedEvent:Fire()
		return
	end

	local species = CreatureConfig.Get(speciesId)
	local modelName = (species and species.ModelName) or speciesId
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local pets = assets and assets:FindFirstChild("Pets")
	local source = pets and pets:FindFirstChild(modelName)
	if not (source and source:IsA("Model")) then
		warn("[PetArrival] modelo não encontrado:", modelName)
		arrivedEvent:Fire()
		return
	end

	-- aparece ao lado do jogador, um pouco à frente, no campo de visão
	local groundY = root.Position.Y - 1.4
	local spot = root.Position + root.CFrame.RightVector * 4.2 + root.CFrame.LookVector * 2.6
	spot = Vector3.new(spot.X, groundY, spot.Z)

	local efeitos = Instance.new("Folder")
	efeitos.Name = "PetArrivalMagia"
	efeitos.Parent = workspace

	flash(spot, efeitos)

	local model = source:Clone()
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		end
	end
	if not model.PrimaryPart then
		model.PrimaryPart = model:FindFirstChildWhichIsA("BasePart", true)
	end
	model.Name = "PetArrivalCinematic"

	-- a frente do modelo é o LookVector, então miramos direto o jogador
	local flat = Vector3.new(root.Position.X - spot.X, 0, root.Position.Z - spot.Z)
	if flat.Magnitude < 0.05 then
		flat = Vector3.new(0, 0, 1)
	end
	local base = CFrame.lookAt(spot, spot + flat.Unit)

	-- guarda o tamanho e a posição originais de cada peça para poder escalar
	local offsets: { [BasePart]: CFrame } = {}
	local sizes: { [BasePart]: Vector3 } = {}
	local pivot = model:GetPivot()
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			offsets[d] = pivot:ToObjectSpace(d.CFrame)
			sizes[d] = d.Size
		end
	end

	scaleModel(model, base, offsets, sizes, 0.01)
	model.Parent = workspace
	cinematicPet = model

	-- o pet só brota depois do estouro
	task.delay(CHARGE_TIME, function()
		if not (cinematicPet and cinematicPet.Parent) then
			return
		end
		shockwave(spot, efeitos)
		pillar(spot, efeitos)
		sparks(spot, efeitos)

		local inicio = os.clock()
		revealConnection = RunService.RenderStepped:Connect(function()
			if not (cinematicPet and cinematicPet.Parent) then
				return
			end
			local alpha = math.clamp((os.clock() - inicio) / REVEAL_TIME, 0, 1)
			-- passa um pouco do tamanho final e volta: dá o "pop" de mágica
			local overshoot = 1 + math.sin(alpha * math.pi) * 0.18
			local factor = alpha * overshoot
			scaleModel(cinematicPet, base, offsets, sizes, math.max(factor, 0.01))

			if alpha >= 1 then
				scaleModel(cinematicPet, base, offsets, sizes, 1)
				if revealConnection then
					revealConnection:Disconnect()
					revealConnection = nil
				end
				arrivedEvent:Fire()
			end
		end)
	end)

	Debris:AddItem(efeitos, CHARGE_TIME + BURST_TIME + REVEAL_TIME + 2)
end

function PetArrivalController:Start()
	watchForRealPet()
	local arrival = Remotes.Get("PetArrival") :: RemoteEvent
	arrival.OnClientEvent:Connect(function(speciesId)
		if type(speciesId) == "string" then
			self:Play(speciesId)
		end
	end)
end

return PetArrivalController
