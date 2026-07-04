local UILibrary = require(path.to.UILibrary)

local Window = UILibrary.new({
	Title = "My Script Hub",
	PrimaryColor = Color3.fromRGB(24, 24, 28),
	SecondaryColor = Color3.fromRGB(32, 32, 38),
	AccentColor = Color3.fromRGB(88, 101, 242),
	TextColor = Color3.fromRGB(235, 235, 240),
	Font = Enum.Font.GothamMedium,
})

local MainTab = Window:CreateTab("Main")
local Section = MainTab:CreateSection("General")

Section:CreateButton("Say Hi", function()
    print("Hi!")
end)
