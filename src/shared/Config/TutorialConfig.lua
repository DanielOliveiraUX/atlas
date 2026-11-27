-- Passos do tutorial. O servidor é dono do passo atual; o cliente só exibe.
--
-- Advance diz o que faz o passo avançar:
--   "Prompt"    — o jogador usou o ProximityPrompt do mentor
--   "Dialogue"  — o jogador leu todas as falas do passo
--   "Card"      — o jogador fechou o card de revelação do pet
--   "Client"    — o cliente avisou uma ação (abrir a coleção, por exemplo)
--   "Equip"     — o jogador equipou qualquer pet
--   "ReachBase" — o jogador chegou na própria base
--
-- Target aponta a seta de objetivo: "Mentor" ou "Base". Sem Target, sem seta.
-- Lines são as falas do mentor, em ordem.
-- GrantStarter entrega o pet inicial ao ENTRAR no passo.
-- PetArrival dispara a chegada do pet correndo.
local TutorialConfig = {}

TutorialConfig.SpeakerKey = "Mentor.PromptObject"

TutorialConfig.Steps = table.freeze({
	-- O jogador nasce solto. Nada de espera: a seta já aponta o mentor.
	table.freeze({
		Id = "GoToMentor",
		TitleKey = "Tutorial.GoToMentor.Title",
		BodyKey = "Tutorial.GoToMentor.Body",
		Advance = "Prompt",
		Target = "Mentor",
	}),
	table.freeze({
		Id = "Welcome",
		TitleKey = "Tutorial.Welcome.Title",
		BodyKey = "Tutorial.Welcome.Body",
		Advance = "Dialogue",
		Lines = table.freeze({ "Dialogue.Welcome.1", "Dialogue.Welcome.2" }),
	}),
	table.freeze({
		Id = "MeetPet",
		TitleKey = "Tutorial.MeetPet.Title",
		BodyKey = "Tutorial.MeetPet.Body",
		Advance = "Dialogue",
		Lines = table.freeze({ "Dialogue.MeetPet.1", "Dialogue.MeetPet.2" }),
		PetArrival = true,
	}),
	table.freeze({
		Id = "ReceivePet",
		TitleKey = "Tutorial.ReceivePet.Title",
		BodyKey = "Tutorial.ReceivePet.Body",
		Advance = "Card",
		GrantStarter = true,
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
	-- Fim a pé, não por teleporte: é a primeira caminhada pela vila.
	table.freeze({
		Id = "GoHome",
		TitleKey = "Tutorial.GoHome.Title",
		BodyKey = "Tutorial.GoHome.Body",
		Advance = "ReachBase",
		Target = "Base",
		Lines = table.freeze({ "Dialogue.GoHome.1" }),
	}),
})

-- Distância (studs) que conta como "chegou na base"
TutorialConfig.ReachBaseDistance = 20
-- De quanto em quanto tempo o servidor confere a chegada
TutorialConfig.ReachBaseInterval = 0.5

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
