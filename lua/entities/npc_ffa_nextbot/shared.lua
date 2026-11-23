AddCSLuaFile()

-- Base NextBot entity metadata for Spawn Menu registration
ENT.Base = "base_nextbot"
ENT.Spawnable = true
ENT.PrintName = "FFA NextBot"
ENT.Category = "FFA NextBots"

-- Pool of randomized bot display names shared between server and client
FFABot_Names = {
    "Jeff", "Alex", "Max", "Lucas", "Nathan",
    "Kévin", "Enzo", "Léo", "Hugo", "Tom",
    "Sacha", "Noah", "Dylan", "Ryan", "Ethan",
    "Ghost", "Viper", "Reaper", "Shadow", "Raptor"
}

-- Register entity class and all bot names in the client localization table
-- to prevent '#' prefixes in the native killfeed
if CLIENT then
    language.Add("npc_ffa_nextbot", "FFA Bot")
    for _, botName in ipairs(FFABot_Names) do
        language.Add(botName, botName)
    end
end

-- Define networked variables synced from server to client for animations, nametags, and weapon rendering
function ENT:SetupDataTables()
    self:NetworkVar("String", 0, "HoldTypeName")
    self:NetworkVar("String", 1, "BotName")
    self:NetworkVar("String", 2, "ActiveWeaponWorldModel")
end