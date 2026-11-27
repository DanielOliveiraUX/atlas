-- O pet chega correndo. Cena puramente visual do tutorial: um clone do
-- modelo corre da trilha até o jogador e fica ao lado dele.
--
-- Não é o pet de verdade — o pet do mundo só nasce quando o jogador equipa
-- (PetService). Por isso este clone se apaga sozinho assim que o PetService
-- põe o verdadeiro em cena, para não existirem dois.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CreatureConfig = require(Shared.Config.CreatureConfig)
local Remotes = require(Shared.Remotes)

local player = Players.LocalPlayer

local PetArrivalController = {}

local arrivedEvent = Instance.new("BindableEvent")
-- Dispara quando o pet termina a corrida e para ao lado do jogador
PetArrivalController.Arrived = arrivedEvent.Event

local cinematicPet: Model? = nil
local runConnection: RBXScriptConnection? = nil
local watchConnection: RBXScriptConnection? = nil

local RUN_DISTANCE = 42 -- de quão longe ele vem
local RUN_TIME = 2.3
local HOP_HEIGHT = 1.1
local HOPS = 5

-- Cena ------------------------------------------------------------------------

local function cleanup()
	if runConnection then
		runConnection:Disconnect()
		runConnection = nil
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
	model.Parent = workspace
	cinematicPet = model

	-- vem de trás do jogador, pela trilha, e para ao lado dele
	local behind = root.CFrame.LookVector * -1
	local side = root.CFrame.RightVector
	local groundY = root.Position.Y - 1.4
	local startPos = root.Position + behind * RUN_DISTANCE + side * 6
	startPos = Vector3.new(startPos.X, groundY, startPos.Z)
	local endPos = root.Position + side * 3.2 + root.CFrame.LookVector * 1.5
	endPos = Vector3.new(endPos.X, groundY, endPos.Z)

	local elapsed = 0
	runConnection = RunService.RenderStepped:Connect(function(delta)
		if not cinematicPet or not cinematicPet.Parent then
			return
		end
		elapsed += delta
		local alpha = math.clamp(elapsed / RUN_TIME, 0, 1)
		-- desacelera na chegada
		local eased = 1 - (1 - alpha) * (1 - alpha)
		local position = startPos:Lerp(endPos, eased)
		-- pulinhos: dá vida sem precisar de animação de esqueleto
		local hop = if alpha < 1 then math.abs(math.sin(alpha * math.pi * HOPS)) * HOP_HEIGHT * (1 - alpha) else 0
		position = Vector3.new(position.X, position.Y + hop, position.Z)

		local lookTarget = if alpha < 1 then endPos else root.Position
		local flat = Vector3.new(lookTarget.X - position.X, 0, lookTarget.Z - position.Z)
		if flat.Magnitude < 0.05 then
			flat = Vector3.new(root.Position.X - position.X, 0, root.Position.Z - position.Z)
		end
		if flat.Magnitude < 0.05 then
			flat = Vector3.new(0, 0, 1)
		end
		-- o modelo olha para -Z, então miramos o oposto do alvo
		cinematicPet:PivotTo(CFrame.lookAt(position, position - flat.Unit))

		if alpha >= 1 then
			if runConnection then
				runConnection:Disconnect()
				runConnection = nil
			end
			arrivedEvent:Fire()
		end
	end)
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
