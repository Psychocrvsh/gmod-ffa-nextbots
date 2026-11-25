-- convars
local cvarTagScale = CreateClientConVar("ffa_nb_nametag_scale", "1.0", true, false, "Scale of bot overhead nametags", 0.5, 3.0)
local cvarTagColor = CreateClientConVar("ffa_nb_nametag_color", "255 255 255", true, false, "RGB color of bot overhead nametags")
local cvarTagDist  = CreateClientConVar("ffa_nb_nametag_dist", "900", true, false, "Max display distance for bot overhead nametags", 200, 2500)

-- Periodically register connected player nicknames in the localization table
-- so the native killfeed displays player names without a leading '#' prefix
timer.Create("FFABot_RegisterPlayerNames", 3, 0, function()
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) then
            local nick = ply:Nick()
            language.Add(nick, nick)
        end
    end
end)

-- Register fallback HL2 SMG killicon for the FFA NextBot entity class
killicon.AddFont("npc_ffa_nextbot", "HL2MPTypeDeath", "2", Color(255, 80, 0, 255))

-- Client-side cache of selected weapons, playermodels, and current map Navmesh state
local SelectedWeapons = {}
local SelectedModels = {}
local HasNavmesh = true

-- Receive Navmesh availability status from the server
net.Receive("FFABot_NavmeshStatus", function()
    HasNavmesh = net.ReadBool()
end)

-- Load saved weapon and playermodel selections from local DATA storage
local function LoadClientCache()
    if file.Exists("ffa_nextbots_config.json", "DATA") then
        local data = util.JSONToTable(file.Read("ffa_nextbots_config.json", "DATA") or "")
        if istable(data) then
            SelectedWeapons = data.weapons or {}
            SelectedModels = data.models or {}
        end
    end
end

-- Request fresh navmesh status and clear panel before populating a sub-tab
local function PrepareSubPanel(panel)
    LoadClientCache()
    panel:ClearControls()

    net.Start("FFABot_RequestNavStatus")
    net.SendToServer()

    panel:Help("Lightweight C++ Navmesh NextBots with custom playermodels and weapons.")

    if not HasNavmesh then
        local warn = panel:Help("WARNING: This map has NO Navmesh (.nav)! Bots will not navigate properly until you generate one.")
        warn:SetTextColor(Color(220, 50, 50))
    end
end

-- Build the FFA NextBots configuration tabs inside Spawn Menu > Utilities > FFA NextBots
hook.Add("PopulateToolMenu", "FFANextBots_Menu", function()
    -- ==========================================
    -- Tab 1: General & Spawns
    -- ==========================================
    spawnmenu.AddToolMenuOption("Utilities", "FFA NextBots", "FFANextBots_General", "General & Spawns", "", "", function(panel)
        PrepareSubPanel(panel)

        panel:Help("--- Spawning & Match ---")
        panel:CheckBox("Enable Automatic FFA Spawning", "ffabot_enabled")
        panel:NumSlider("Bot Quota (Max Active Bots)", "ffabot_quota", 0, 30, 0)

        panel:Help("--- Bot Control ---")
        panel:CheckBox("Freeze Bots (No Movement / No Shooting)", "ffabot_freeze")
        panel:CheckBox("Ignore Players", "ffabot_ignore_players")

        panel:Help("--- Actions ---")
        panel:Button("Spawn 1 Bot Now", "ffabot_spawn_now")
        panel:Button("Remove All Bots", "ffabot_clear")
        panel:Button("Generate Navmesh (Map Reloads)", "ffabot_generate_nav")
    end)

    -- ==========================================
    -- Tab 2: AI & Combat
    -- ==========================================
    spawnmenu.AddToolMenuOption("Utilities", "FFA NextBots", "FFANextBots_AI", "AI & Combat", "", "", function(panel)
        PrepareSubPanel(panel)

        panel:Help("--- Bot Stats & Reaction ---")
        panel:NumSlider("Bot Health (HP)", "ffabot_health", 50, 300, 0)
        panel:NumSlider("Bot Accuracy Multiplier", "ffabot_accuracy", 0.3, 2.0, 2)
        panel:NumSlider("Reaction Time (sec)", "ffa_bot_reaction_time", 0.0, 2.0, 2)
        panel:ControlHelp("Delay before a bot opens fire after spotting a target.")
    end)

    -- ==========================================
    -- Tab 3: Loadout & Visuals
    -- ==========================================
    spawnmenu.AddToolMenuOption("Utilities", "FFA NextBots", "FFANextBots_Loadout", "Loadout & Visuals", "", "", function(panel)
        PrepareSubPanel(panel)

        -- Allowed Weapons Selection List
        panel:Help("--- Allowed Weapons (Click to Toggle) ---")
        panel:Help("If none selected: bots use default HL2 weapons.")

        local wepList = vgui.Create("DListView", panel)
        wepList:SetTall(180)
        wepList:SetMultiSelect(false)
        wepList:AddColumn("Active"):SetFixedWidth(45)
        wepList:AddColumn("Weapon")
        wepList:AddColumn("Category")

        -- Gather and sort all spawnable SWEPs by category and display name
        local allWeps = {}
        for _, swep in pairs(weapons.GetList()) do
            if swep.Spawnable and swep.ClassName then
                table.insert(allWeps, {
                    class = swep.ClassName,
                    name = swep.PrintName or swep.ClassName,
                    cat = swep.Category or "Other"
                })
            end
        end
        table.sort(allWeps, function(a, b) return (a.cat .. a.name) < (b.cat .. b.name) end)

        for _, w in ipairs(allWeps) do
            local activeStr = SelectedWeapons[w.class] and "YES" or ""
            local line = wepList:AddLine(activeStr, w.name, w.cat)
            line.ClassName = w.class
        end

        -- Toggle weapon state locally and sync with the server
        wepList.OnRowSelected = function(_, _, row)
            local cls = row.ClassName
            local newState = not SelectedWeapons[cls]
            SelectedWeapons[cls] = newState or nil
            row:SetColumnText(1, newState and "YES" or "")

            net.Start("FFABot_ToggleWeapon")
            net.WriteString(cls)
            net.WriteBool(newState)
            net.SendToServer()
        end
        panel:AddItem(wepList)

        local resetWepBtn = panel:Button("Uncheck All Weapons")
        resetWepBtn.DoClick = function()
            SelectedWeapons = {}
            for _, line in ipairs(wepList:GetLines()) do line:SetColumnText(1, "") end
            net.Start("FFABot_ClearSelections")
            net.WriteString("weapons")
            net.SendToServer()
        end

        -- Allowed Playermodels Selection List
        panel:Help("--- Allowed Playermodels (Click to Toggle) ---")
        panel:CheckBox("If none selected: Workshop models only", "ffabot_only_custom_pm")

        local pmList = vgui.Create("DListView", panel)
        pmList:SetTall(180)
        pmList:SetMultiSelect(false)
        pmList:AddColumn("Active"):SetFixedWidth(45)
        pmList:AddColumn("Playermodel")

        -- Gather and sort all registered valid playermodels alphabetically
        local allPMs = {}
        for name, mdl in pairs(player_manager.AllValidModels()) do
            table.insert(allPMs, { name = name, mdl = mdl })
        end
        table.sort(allPMs, function(a, b) return a.name < b.name end)

        for _, p in ipairs(allPMs) do
            local activeStr = SelectedModels[p.mdl] and "YES" or ""
            local line = pmList:AddLine(activeStr, p.name)
            line.ModelPath = p.mdl
        end

        -- Toggle playermodel state locally and sync with the server
        pmList.OnRowSelected = function(_, _, row)
            local mdl = row.ModelPath
            local newState = not SelectedModels[mdl]
            SelectedModels[mdl] = newState or nil
            row:SetColumnText(1, newState and "YES" or "")

            net.Start("FFABot_ToggleModel")
            net.WriteString(mdl)
            net.WriteBool(newState)
            net.SendToServer()
        end
        panel:AddItem(pmList)

        local resetPmBtn = panel:Button("Uncheck All Playermodels")
        resetPmBtn.DoClick = function()
            SelectedModels = {}
            for _, line in ipairs(pmList:GetLines()) do line:SetColumnText(1, "") end
            net.Start("FFABot_ClearSelections")
            net.WriteString("models")
            net.SendToServer()
        end

        -- Overhead Nametag Appearance (Client-side)
        panel:Help("--- Overhead Nametag Appearance ---")
        panel:NumSlider("Nametag Size", "ffa_nb_nametag_scale", 0.5, 3.0, 2)
        panel:NumSlider("Nametag Distance", "ffa_nb_nametag_dist", 200, 2500, 0)

        local colorMixer = vgui.Create("DColorMixer", panel)
        colorMixer:SetLabel("Nametag Color")
        colorMixer:SetPalette(true)
        colorMixer:SetAlphaBar(false)
        colorMixer:SetWangs(true)
        colorMixer:SetHeight(160)

        local r, g, b = string.match(cvarTagColor:GetString(), "(%d+)%s+(%d+)%s+(%d+)")
        colorMixer:SetColor(Color(tonumber(r) or 255, tonumber(g) or 255, tonumber(b) or 255))

        function colorMixer:ValueChanged(col)
            RunConsoleCommand("ffa_nb_nametag_color", string.format("%d %d %d", col.r, col.g, col.b))
        end
        panel:AddItem(colorMixer)
    end)
end)