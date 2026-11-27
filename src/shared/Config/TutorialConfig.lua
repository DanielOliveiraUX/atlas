-- Passos do tutorial. O servidor é dono do passo atual; o cliente só exibe.
--
-- Advance diz o que faz o passo avançar:
--   "Auto"      — depois de DelaySeconds
--   "Prompt"    — o jogador usou o ProximityPrompt do mentor
--   "Client"    — o cliente avisou uma ação (TutorialAction com o nome do passo)
--   "Equip"     — o jogador equipou qualquer pet
local TutorialConfig = {}

TutorialConfig.Steps = table.freeze({
	table.freeze({
		Id = "Welcome",
		TitleKey = "Tutorial.Welcome.Title",
		BodyKey = "Tutorial.Welcome.Body",
		Advance = "Auto",
		DelaySeconds = 5,
	}),
	table.freeze({
		Id = "GoToMentor",
		TitleKey = "Tutorial.GoToMentor.Title",
		BodyKey = "Tutorial.GoToMentor.Body",
		Advance = "Prompt",
	}),
	table.freeze({
		Id = "ReceivePet",
		TitleKey = "Tutorial.ReceivePet.Title",
		BodyKey = "Tutorial.ReceivePet.Body",
		Advance = "Client", -- o jogador fecha o cartão de apresentação do pet
	}),
	table.freeze({
		Id = "OpenCollection",
		TitleKey = "Tutorial.OpenCollection.Title",
		BodyKey = "Tutorial.OpenCollection.Body",
		Advance = "Client",
	}),
	table.freeze({
		Id = "EquipPet",
		TitleKey = "Tutorial.EquipPet.Title",
		BodyKey = "Tutorial.EquipPet.Body",
		Advance = "Equip",
	}),
	table.freeze({
		Id = "Done",
		TitleKey = "Tutorial.Done.Title",
		BodyKey = "Tutorial.Done.Body",
		Advance = "Auto",
		DelaySeconds = 8,
	}),
})

-- Índice do passo pelo Id
TutorialConfig.IndexById = (function()
	local map = {}
	for index, step in TutorialConfig.Steps do
		map[step.Id] = index
	end
	return table.freeze(map)
end)()

function TutorialConfig.GetStep(index: number)
	return TutorialConfig.Steps[index]
end

function TutorialConfig.StepCount(): number
	return #TutorialConfig.Steps
end

return table.freeze(TutorialConfig)
