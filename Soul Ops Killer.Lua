local UILibrary = loadstring(game:HttpGet(('https://raw.githubusercontent.com/lputzer123-commits/4o4-UI-Library/refs/heads/main/UILibrary.lua')))()
local bosses = workspace:FindFirstChild("Boss")

local Window = UILibrary.new({
	Title = "Soul Ops Killer",
	PrimaryColor = Color3.fromRGB(24, 24, 28),
	SecondaryColor = Color3.fromRGB(32, 32, 38),
	AccentColor = Color3.fromRGB(88, 101, 242),
	TextColor = Color3.fromRGB(235, 235, 240),
	Font = Enum.Font.Arcade,
})

local MainTab = Window:CreateTab("Main")

local autoKillBosses = false

local function killBoss()


    local boss = bosses:FindFirstChildOfClass("Model")
    if not boss then return end

    local _hum = boss:FindFirstChildOfClass("Humanoid")
    if not _hum then return end

    _hum.Health = 0

end
    

_general:CreateButton("Kill Boss", function()
    killBoss()
end)
