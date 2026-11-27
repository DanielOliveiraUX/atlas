-- Ponto de entrada do cliente. Mesmo padrão do servidor: Init e depois Start.
local ControllersFolder = script:WaitForChild("Controllers")

local ORDER = {
	"LoadingController",
}

local controllers = {}
for _, name in ORDER do
	controllers[name] = require(ControllersFolder:WaitForChild(name))
end

for _, name in ORDER do
	local controller = controllers[name]
	if controller.Init then
		controller:Init()
	end
end

for _, name in ORDER do
	local controller = controllers[name]
	if controller.Start then
		task.spawn(controller.Start, controller)
	end
end
