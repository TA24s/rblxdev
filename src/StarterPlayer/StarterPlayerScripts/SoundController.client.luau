--!strict
-- SoundController
-- Plays short sounds on this player's screen: a ping when Bolts go up, a click with each message
-- (or a cheer, alarm or switch when the server asks for one), a snap when you swing the Boing
-- Glove and a spring when you get bounced. Uses sounds built into Roblox, so nothing to upload.
-- Also loops the background music. Both follow the Music and SFX switches in Settings
-- (player attributes SettingMusic and SettingSfx, saved by MenuService).
-- The music is "Kinetic Algorithm" from the free Creator Store library; swap MUSIC_ID to change it.
-- Container: StarterPlayer/StarterPlayerScripts

----- Services -----
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

----- Constants -----
local SOUNDS = {
	coins = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.35 },
	click = { id = "rbxasset://sounds/clickfast.wav", volume = 0.5 },
	good = { id = "rbxasset://sounds/victory.wav", volume = 0.45 },
	alarm = { id = "rbxasset://sounds/bass.wav", volume = 0.8 },
	lock = { id = "rbxasset://sounds/switch.wav", volume = 0.7 },
	swing = { id = "rbxasset://sounds/snap.wav", volume = 0.6 },
	boing = { id = "rbxasset://sounds/action_jump.mp3", volume = 0.8 },
}
local MUSIC_ID = "rbxassetid://96355771634096"
local MUSIC_VOLUME = 0.25
local COINS_GAP = 0.15 -- seconds; collecting can raise Bolts many times quickly

----- Variables -----
local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local soundFolder = Instance.new("Folder")
soundFolder.Name = "GameSounds"
soundFolder.Parent = SoundService
local sounds: { [string]: Sound } = {}
local lastCoins = 0
local watchedTools: { [Tool]: boolean } = setmetatable({}, { __mode = "k" }) :: any -- so re-equipping doesn't double the sound

----- Private Functions -----
local function play(name: string)
	local sound = sounds[name]
	if sound and player:GetAttribute("SettingSfx") ~= false then
		SoundService:PlayLocalSound(sound)
	end
end

local function watchBolts()
	while not player:GetAttribute("DataLoaded") do
		player:GetAttributeChangedSignal("DataLoaded"):Wait()
	end
	local bolts = player:WaitForChild("leaderstats"):WaitForChild("Bolts") :: IntValue
	local last = bolts.Value
	bolts.Changed:Connect(function(value: number)
		if value > last and os.clock() - lastCoins >= COINS_GAP then
			lastCoins = os.clock()
			play("coins")
		end
		last = value
	end)
end

local function watchGlove(character: Model)
	character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") and child.Name == "BoingGlove" and not watchedTools[child] then
			watchedTools[child] = true
			child.Activated:Connect(function()
				play("swing")
			end)
		end
	end)
end

----- Initialization -----
for name, info in SOUNDS do
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = info.id
	sound.Volume = info.volume
	sound.Parent = soundFolder
	sounds[name] = sound
end

local music = Instance.new("Sound")
music.Name = "Music"
music.SoundId = MUSIC_ID
music.Volume = MUSIC_VOLUME
music.Looped = true
music.Parent = soundFolder
local function updateMusic()
	local on = player:GetAttribute("DataLoaded") == true and player:GetAttribute("SettingMusic") ~= false
	if on and not music.IsPlaying then
		music:Resume()
	elseif not on and music.IsPlaying then
		music:Pause()
	end
end
player:GetAttributeChangedSignal("SettingMusic"):Connect(updateMusic)
player:GetAttributeChangedSignal("DataLoaded"):Connect(updateMusic)
updateMusic()

local notifyRemote = remotes:WaitForChild("Notify") :: RemoteEvent
notifyRemote.OnClientEvent:Connect(function(_text: string, sound: string?)
	play(if sound and sounds[sound] then sound else "click")
end)
local knockbackRemote = remotes:WaitForChild("Knockback") :: RemoteEvent
knockbackRemote.OnClientEvent:Connect(function()
	play("boing")
end)

player.CharacterAdded:Connect(watchGlove)
if player.Character then
	watchGlove(player.Character)
end
task.spawn(watchBolts)
