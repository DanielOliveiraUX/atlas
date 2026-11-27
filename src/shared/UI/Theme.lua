-- Base visual mobile-first: toque grande, texto legível, escala pela tela.
local Theme = {}

Theme.Colors = table.freeze({
	Background = Color3.fromRGB(18, 24, 32),
	Panel = Color3.fromRGB(30, 40, 52),
	Primary = Color3.fromRGB(86, 196, 140),
	Accent = Color3.fromRGB(255, 196, 82),
	Danger = Color3.fromRGB(232, 92, 92),
	Text = Color3.fromRGB(240, 244, 248),
	TextMuted = Color3.fromRGB(160, 172, 186),
})

Theme.Font = Enum.Font.GothamBold
Theme.FontBody = Enum.Font.Gotham

Theme.MinTouchSize = 56 -- px, alvo mínimo de toque
Theme.CornerRadius = UDim.new(0, 12)
Theme.Padding = 12

-- Resolução de referência; a UI escala a partir dela
Theme.ReferenceSize = Vector2.new(1280, 720)
Theme.MinScale = 0.6
Theme.MaxScale = 1.5

-- Adiciona um UIScale que acompanha o tamanho da tela.
function Theme.ApplyScale(gui: Instance)
	local camera = workspace.CurrentCamera
	local scale = Instance.new("UIScale")
	scale.Parent = gui

	local function update()
		local size = camera.ViewportSize
		local factor = math.min(size.X / Theme.ReferenceSize.X, size.Y / Theme.ReferenceSize.Y)
		scale.Scale = math.clamp(factor, Theme.MinScale, Theme.MaxScale)
	end

	update()
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
	return scale
end

function Theme.Round(gui: Instance)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = Theme.CornerRadius
	corner.Parent = gui
	return corner
end

return Theme
