-- Register network strings for client-server UI synchronization and Navmesh status checks
util.AddNetworkString("FFABot_ToggleWeapon")
util.AddNetworkString("FFABot_ToggleModel")
util.AddNetworkString("FFABot_ClearSelections")
util.AddNetworkString("FFABot_NavmeshStatus")
util.AddNetworkString("FFABot_RequestNavStatus")

-- Persistent server-side ConVars controlling bot spawning, health, accuracy, reaction time, freeze, and player targeting
CreateConVar("ffabot_enabled", "0", FCVAR_ARCHIVE, "Enable automatic spawning of FFA NextBots")
CreateConVar("ffabot_quota", "8", FCVAR_ARCHIVE, "Number of active FFA NextBots")
CreateConVar("ffabot_only_custom_pm", "1", FCVAR_ARCHIVE, "Use Workshop playermodels only when none are selected")
CreateConVar("ffabot_health", "100", FCVAR_ARCHIVE, "Health points of FFA NextBots")
CreateConVar("ffabot_accuracy", "1.0", FCVAR_ARCHIVE, "Bot accuracy multiplier (0.2 to 2.5)")
CreateConVar("ffa_bot_reaction_time", "0.35", { FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_NOTIFY }, "Reaction delay in seconds before a bot fires upon spotting an enemy", 0.0, 2.0)
CreateConVar("ffabot_freeze", "0", { FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_NOTIFY }, "Freeze all FFA NextBots (disable movement and firing)")
CreateConVar("ffabot_ignore_players", "0", { FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_NOTIFY }, "Make FFA NextBots ignore players")

-- Global lookup tables storing allowed weapon classes and playermodel paths
FFABot_AllowedWeapons = FFABot_AllowedWeapons or {}
FFABot_AllowedModels = FFABot_AllowedModels or {}

local DATA_FILE = "ffa_nextbots_config.json"

-- Persist allowed weapon and playermodel selections to garrysmod/data/
local function SaveFFABotConfig()
    file.Write(DATA_FILE, util.TableToJSON({
        weapons = FFABot_AllowedWeapons,
        models = FFABot_AllowedModels
    }, true))
end

-- Load saved weapon and playermodel selections on server startup
local function LoadFFABotConfig()
    if file.Exists(DATA_FILE, "DATA") then
        local data = util.JSONToTable(file.Read(DATA_FILE, "DATA") or "")
        if istable(data) then
            FFABot_AllowedWeapons = data.weapons or {}
            FFABot_AllowedModels = data.models or {}
        end
    end
end
LoadFFABotConfig()

-- Check whether the current map has a valid loaded Navmesh (.nav)
local function MapHasNavmesh()
    return navmesh.IsLoaded() and #(navmesh.GetAllNavAreas() or {}) > 0
end

-- Send Navmesh availability status to a specific player or all connected clients
local function BroadcastNavStatus(targetPly)
    net.Start("FFABot_NavmeshStatus")
    net.WriteBool(MapHasNavmesh())
    if IsValid(targetPly) then
        net.Send(targetPly)
    else
        net.Broadcast()
    end
end

-- Respond to client UI requests checking if the map has a Navmesh
net.Receive("FFABot_RequestNavStatus", function(_, ply)
    BroadcastNavStatus(ply)
end)

-- Notify players upon joining if the current map is missing a .nav file
hook.Add("PlayerInitialSpawn", "FFABot_SendNavStatus", function(ply)
    timer.Simple(2, function()
        if IsValid(ply) then
            BroadcastNavStatus(ply)
            if not MapHasNavmesh() then
                ply:ChatPrint("[FFA NextBots] WARNING: This map has no Navmesh (.nav). Open Q > Utilities > FFA NextBots > General & Spawns and click 'Generate Navmesh'.")
            end
        end
    end)
end)

-- ==========================================
-- Admin Menu Network Handlers
-- ==========================================

net.Receive("FFABot_ToggleWeapon", function(_, ply)
    if IsValid(ply) and not ply:IsAdmin() then return end
    local cls = net.ReadString()
    local state = net.ReadBool()
    if state then FFABot_AllowedWeapons[cls] = true else FFABot_AllowedWeapons[cls] = nil end
    SaveFFABotConfig()
end)

net.Receive("FFABot_ToggleModel", function(_, ply)
    if IsValid(ply) and not ply:IsAdmin() then return end
    local mdl = net.ReadString()
    local state = net.ReadBool()
    if state then FFABot_AllowedModels[mdl] = true else FFABot_AllowedModels[mdl] = nil end
    SaveFFABotConfig()
end)

net.Receive("FFABot_ClearSelections", function(_, ply)
    if IsValid(ply) and not ply:IsAdmin() then return end
    local target = net.ReadString()
    if target == "weapons" then FFABot_AllowedWeapons = {} end
    if target == "models" then FFABot_AllowedModels = {} end
    SaveFFABotConfig()
end)

-- ==========================================
-- Spawning & Navmesh Management
-- ==========================================

local CachedNavAreas = nil

local function GetCachedNavAreas()
    if not CachedNavAreas then
        CachedNavAreas = navmesh.GetAllNavAreas()
    end
    return CachedNavAreas
end

-- Validate that a candidate spawn position is inside the world and clear for a bot hull
local function IsValidBotSpawn(pos)
    if not util.IsInWorld(pos + Vector(0, 0, 10)) then
        return false
    end

    local tr = util.TraceHull({
        start = pos + Vector(0, 0, 4),
        endpos = pos + Vector(0, 0, 4),
        mins = Vector(-16, -16, 0),
        maxs = Vector(16, 16, 72),
        mask = MASK_NPCSOLID
    })

    return not tr.StartSolid and not tr.AllSolid
end

-- Find a valid spawn position across the map's Navmesh,
-- falling back to standard map spawn entities if no Navmesh is present
local function GetValidSpawnPoint()
    if MapHasNavmesh() then
        local areas = GetCachedNavAreas()
        if #areas > 0 then
            for _ = 1, 35 do
                local area = areas[math.random(#areas)]
                if IsValid(area) and not area:IsUnderwater() and area:GetSizeX() > 28 and area:GetSizeY() > 28 then
                    if #area:GetAdjacentAreas() == 0 then continue end

                    local pt = area:GetRandomPoint() + Vector(0, 0, 10)
                    if IsValidBotSpawn(pt) then
                        return pt
                    end
                end
            end
        end
    end

    local spawns = {}
    for _, cls in ipairs({ "info_player_deathmatch", "info_player_start", "info_player_terrorist", "info_player_counterterrorist" }) do
        table.Add(spawns, ents.FindByClass(cls))
    end

    if #spawns > 0 then
        local sp = spawns[math.random(#spawns)]
        if IsValid(sp) then
            local fallbackPos = sp:GetPos() + Vector(0, 0, 10)
            if IsValidBotSpawn(fallbackPos) then
                return fallbackPos
            end
        end
    end

    return nil
end

-- Instantiate and spawn a single FFA NextBot at a valid spawn point
local function SpawnOneFFABot()
    local pos = GetValidSpawnPoint()
    if not pos then return false end

    local bot = ents.Create("npc_ffa_nextbot")
    if not IsValid(bot) then return false end

    bot:SetPos(pos)
    bot:SetAngles(Angle(0, math.random(0, 360), 0))
    bot:Spawn()
    bot:Activate()
    return true
end

-- ==========================================
-- Stuck Bot Recovery (Teleport / Respawn)
-- ==========================================

timer.Create("FFABot_StuckMonitor", 1.5, 0, function()
    local now = CurTime()
    local frozenCvar = GetConVar("ffabot_freeze")
    local isFrozen = frozenCvar and frozenCvar:GetBool()

    for _, ent in ipairs(ents.FindByClass("npc_ffa_nextbot")) do
        if IsValid(ent) then
            local pos = ent:GetPos()

            if isFrozen then
                ent.FFABot_LastPos = pos
                ent.FFABot_LastMoveTime = now
                continue
            end

            if not ent.FFABot_LastPos then
                ent.FFABot_LastPos = pos
                ent.FFABot_LastMoveTime = now
                continue
            end

            if pos:DistToSqr(ent.FFABot_LastPos) > (45 ^ 2) then
                ent.FFABot_LastPos = pos
                ent.FFABot_LastMoveTime = now
                continue
            end

            if (now - ent.FFABot_LastMoveTime) >= 5 then
                local newPos = GetValidSpawnPoint()
                if newPos then
                    ent:SetPos(newPos)
                    ent.FFABot_LastPos = newPos
                    ent.FFABot_LastMoveTime = now
                else
                    ent:Remove()
                    SpawnOneFFABot()
                end
                break
            end
        end
    end
end)

-- Admin console command: remove all active FFA NextBots
concommand.Add("ffabot_clear", function(ply)
    if IsValid(ply) and not ply:IsAdmin() then return end
    for _, bot in ipairs(ents.FindByClass("npc_ffa_nextbot")) do
        bot:Remove()
    end
end)

-- Admin console command: manually spawn one FFA NextBot immediately
concommand.Add("ffabot_spawn_now", function(ply)
    if IsValid(ply) and not ply:IsAdmin() then return end
    if not MapHasNavmesh() and IsValid(ply) then
        ply:ChatPrint("[FFA NextBots] ERROR: No Navmesh found on this map! Click 'Generate Navmesh' first.")
    end
    SpawnOneFFABot()
end)

-- Admin console command: enable cheats and generate a Navmesh for the current map
concommand.Add("ffabot_generate_nav", function(ply)
    if IsValid(ply) and not ply:IsAdmin() then return end
    PrintMessage(HUD_PRINTTALK, "[FFA NextBots] Generating Navmesh... The game will freeze briefly and reload the map automatically.")
    RunConsoleCommand("sv_cheats", "1")
    timer.Simple(0.2, function()
        RunConsoleCommand("nav_generate")
    end)
end)

-- Periodic manager maintaining the active bot population according to ffabot_quota
local WarnedNoNav = false
timer.Create("FFANextBot_AutoSpawner", 1.5, 0, function()
    if not GetConVar("ffabot_enabled"):GetBool() then
        WarnedNoNav = false
        return
    end

    if not MapHasNavmesh() and not WarnedNoNav then
        WarnedNoNav = true
        PrintMessage(HUD_PRINTTALK, "[FFA NextBots] ERROR: No Navmesh (.nav) detected on this map! Use 'Generate Navmesh' in Utilities > FFA NextBots > General & Spawns.")
    end

    local quota = math.Clamp(GetConVar("ffabot_quota"):GetInt(), 0, 40)
    local currentBots = ents.FindByClass("npc_ffa_nextbot")

    if #currentBots < quota then
        SpawnOneFFABot()
    elseif #currentBots > quota then
        local extra = currentBots[#currentBots]
        if IsValid(extra) then extra:Remove() end
    end
end)

-- ==========================================
-- Custom Killfeed Overrides
-- ==========================================

-- Suppress default gamemode death notices for FFA NextBots so custom bot names
-- and weapon icons can be dispatched without duplicate killfeed entries
hook.Add("InitPostEntity", "FFABot_OverrideDeathNotice", function()
    if not GAMEMODE then return end

    local oldOnNPCKilled = GAMEMODE.OnNPCKilled
    function GAMEMODE:OnNPCKilled(npc, attacker, inflictor)
        if IsValid(npc) and npc:GetClass() == "npc_ffa_nextbot" then
            return
        end
        return oldOnNPCKilled(self, npc, attacker, inflictor)
    end

    local oldPlayerDeath = GAMEMODE.PlayerDeath
    function GAMEMODE:PlayerDeath(victim, inflictor, attacker)
        if IsValid(attacker) and attacker:GetClass() == "npc_ffa_nextbot" then
            return
        end
        return oldPlayerDeath(self, victim, inflictor, attacker)
    end
end)

-- Broadcast a custom killfeed entry when an FFA NextBot eliminates a player
hook.Add("PlayerDeath", "FFABot_PlayerKilledByBotNotice", function(victim, inflictor, attacker)
    if IsValid(victim) and IsValid(attacker) and attacker:GetClass() == "npc_ffa_nextbot" then
        local botName = (attacker.GetBotName and attacker:GetBotName() ~= "" and attacker:GetBotName()) or "FFA Bot"
        local wepClass = (attacker.WeaponData and attacker.WeaponData.class) or "npc_ffa_nextbot"

        net.Start("NPCKilledNPC")
            net.WriteString(victim:Nick())
            net.WriteString(wepClass)
            net.WriteString(botName)
        net.Broadcast()
    end
end)