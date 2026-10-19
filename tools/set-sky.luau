--!strict
-- set-sky.luau
-- The purple dusk sky: just after sunset, so the sky turns dark violet, stars come out and the
-- neon decorations glow. Run in Edit mode; one undo step. Safe to run again.
-- Before this (from build-decor.luau): ClockTime 16.8, Brightness 3, Ambient (70,60,100),
-- OutdoorAmbient (120,110,160), Atmosphere Color (200,170,255) Decay (110,80,170) Density 0.3
-- Offset 0.25 Haze 1.2 Glare 0.2, Sky StarCount 3000 MoonAngularSize 11, no ScienceTint.

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local Lighting = game:GetService("Lighting")

local recording = ChangeHistoryService:TryBeginRecording("Purple dusk sky")

Lighting.ClockTime = 19.2
Lighting.Brightness = 2
Lighting.Ambient = Color3.fromRGB(110, 90, 160)
Lighting.OutdoorAmbient = Color3.fromRGB(150, 130, 200)

local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
if atmosphere then
	atmosphere.Color = Color3.fromRGB(170, 110, 255)
	atmosphere.Decay = Color3.fromRGB(90, 40, 160)
	atmosphere.Density = 0.38
	atmosphere.Offset = 0.2
	atmosphere.Haze = 2.2
	atmosphere.Glare = 0.6
end

local sky = Lighting:FindFirstChildOfClass("Sky")
if sky then
	sky.StarCount = 5000
	sky.MoonAngularSize = 20
end

local tint = Lighting:FindFirstChild("ScienceTint") or Instance.new("ColorCorrectionEffect")
tint.Name = "ScienceTint"
;(tint :: ColorCorrectionEffect).TintColor = Color3.fromRGB(235, 225, 255)
;(tint :: ColorCorrectionEffect).Saturation = 0.15
;(tint :: ColorCorrectionEffect).Contrast = 0.05
tint.Parent = Lighting

if recording then
	ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
end
print("[set-sky] Done")
