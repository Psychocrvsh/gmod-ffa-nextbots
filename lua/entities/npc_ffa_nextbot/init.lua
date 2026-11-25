AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

-- Prefixes of standard Half-Life 2 / Counter-Strike playermodels to exclude
-- when "Workshop models only" mode is active
local DEFAULT_HL2_PREFIXES = {
    "models/player/group01/", "models/player/group02/", "models/player/group03/",
    "models/player/kleiner.mdl", "models/player/mossman.mdl", "models/player/alyx.mdl",
    "models/player/barney.mdl", "models/player/breen.mdl", "models/player/eli.mdl",
    "models/player/gman_high.mdl", "models/player/monk.mdl", "models/player/odessa.mdl",
    "models/player/combine_", "models/player/police.mdl", "models/player/zombie_",
    "models/player/charple.mdl", "models/player/corpse1.mdl", "models/player/soldier_stripped.mdl",
    "models/player/hostage/", "models/player/urban.mdl", "models/player/gasmask.mdl",
    "models/player/riot.mdl", "models/player/swat.mdl", "models/player/leet.mdl",
    "models/player/guerilla.mdl", "models/player/arctic.mdl", "models/player/phoenix.mdl"
}

-- Default weapon definitions used when no custom SWEPs are selected in the menu
local FALLBACK_WEAPONS = {
    { class = "weapon_smg1", model = "models/weapons/w_smg1.mdl", holdtype = "smg", damage = 12, delay = 0.1, spread = 0.045, range = 2000, sound = "Weapon_SMG1.Single" },
    { class = "weapon_ar2", model = "models/weapons/w_irifle.mdl", holdtype = "ar2", damage = 16, delay = 0.12, spread = 0.035, range = 2600, sound = "Weapon_AR2.Single" },
    { class = "weapon_shotgun", model = "models/weapons/w_shotgun.mdl", holdtype = "shotgun", damage = 10, pellets = 6, delay = 0.85, spread = 0.08, range = 900, sound = "Weapon_Shotgun.Single" }
}

-- Select a random playermodel from the admin whitelist, Workshop pool, or all valid models
local function PickRandomPlayermodel()
    local customList = FFABot_AllowedModels or {}
    local candidates = {}

    if table.Count(customList) > 0 then
        for mdl, enabled in pairs(customList) do
            if enabled and util.IsValidModel(mdl) then
                table.insert(candidates, mdl)
            end
        end
    end

    if #candidates == 0 then
        local onlyCustom = GetConVar("ffabot_only_custom_pm"):GetBool()
        for _, mdl in pairs(player_manager.AllValidModels()) do
            local lower = string.lower(mdl)
            local isDefault = false
            if onlyCustom then
                for _, prefix in ipairs(DEFAULT_HL2_PREFIXES) do
                    if string.StartWith(lower, prefix) then
                        isDefault = true
                        break
                    end
                end
            end
            if not isDefault and util.IsValidModel(mdl) then
                table.insert(candidates, mdl)
            end
        end
    end

    if #candidates == 0 then
        for _, mdl in pairs(player_manager.AllValidModels()) do
            if util.IsValidModel(mdl) then table.insert(candidates, mdl) end
        end
    end

    return candidates[math.random(#candidates)] or "models/player/swat.mdl"
end

-- Extract combat stats and worldmodel from a stored SWEP class (HL2, MW Base, TFA, etc.)
local function BuildWeaponData(className)
    local swep = weapons.GetStored(className)
    if swep then
        local wModel = swep.WorldModel or swep.WM or ""
        if wModel == "" or not util.IsValidModel(wModel) then
            wModel = "models/weapons/w_rif_m4a1.mdl"
            if not util.IsValidModel(wModel) then wModel = "models/weapons/w_smg1.mdl" end
        end

        local ht = string.lower(swep.HoldType or (swep.Primary and swep.Primary.HoldType) or "ar2")
        if ht ~= "smg" and ht ~= "shotgun" and ht ~= "pistol" then ht = "ar2" end

        local dmg = (swep.Primary and tonumber(swep.Primary.Damage)) or 16
        dmg = math.Clamp(dmg, 6, 75)

        local rpm = (swep.Primary and tonumber(swep.Primary.RPM)) or 600
        local delay = (swep.Primary and tonumber(swep.Primary.Delay)) or (60 / math.max(rpm, 60))
        delay = math.Clamp(delay, 0.07, 1.4)

        local pellets = (swep.Primary and tonumber(swep.Primary.NumShots)) or 1
        pellets = math.Clamp(pellets, 1, 10)

        local snd = (swep.Primary and isstring(swep.Primary.Sound) and swep.Primary.Sound) or "Weapon_SMG1.Single"

        return {
            class = className,
            model = wModel,
            holdtype = ht,
            damage = dmg,
            pellets = pellets,
            delay = delay,
            spread = pellets > 1 and 0.085 or 0.04,
            range = pellets > 1 and 950 or 2600,
            sound = snd
        }
    end

    for _, fb in ipairs(FALLBACK_WEAPONS) do
        if fb.class == className then return fb end
    end
    return FALLBACK_WEAPONS[1]
end

-- Initialize bot model, health, random name, bodygroups, locomotion, and starting weapon
function ENT:Initialize()
    local chosenModel = PickRandomPlayermodel()
    self:SetModel(chosenModel)

    local hp = GetConVar("ffabot_health"):GetInt()
    self:SetHealth(hp)
    self:SetMaxHealth(hp)

    local chosenName = FFABot_Names[math.random(#FFABot_Names)]
    self:SetBotName(chosenName)
    self:SetName(chosenName)

    -- Randomize skin and bodygroups for visual variety
    self:SetSkin(math.random(0, math.max(0, self:SkinCount() - 1)))
    for i = 0, self:GetNumBodyGroups() - 1 do
        local count = self:GetBodygroupCount(i)
        if count > 1 then
            self:SetBodygroup(i, math.random(0, count - 1))
        end
    end

    self:SetCollisionGroup(COLLISION_GROUP_NPC)
    self:SetSolid(SOLID_BBOX)
    self:SetCollisionBounds(Vector(-16, -16, 0), Vector(16, 16, 72))

    -- Configure NextBot locomotion physics parameters
    self.BaseMoveSpeed = 250
    self.MovePaceMult = 1.0
    self.CombatSprintMult = 1.35
    self.IsSprintingCombat = false
    self.NextPaceChangeTime = CurTime() + math.Rand(1.5, 3.5)
    self.NextJumpTime = CurTime() + math.Rand(2.0, 4.5)
    self.NextNearMissReactTime = 0
    self.loco:SetStepHeight(22)
    self.loco:SetJumpHeight(65)
    self.loco:SetAcceleration(1050)
    self.loco:SetDeceleration(950)
    self.loco:SetDesiredSpeed(self.BaseMoveSpeed)

    self:EquipRandomWeapon()

    self.NextShotTime = CurTime() + 0.5
    self.NextTargetScan = 0
    self.Enemy = nil
    self.TargetAcquiredTime = 0
    self.ReactionDelay = 0
    self.LastTurnTime = CurTime()
end

-- Check whether bots are currently frozen via ConVar
function ENT:IsFrozen()
    local cvar = GetConVar("ffabot_freeze")
    return cvar and cvar:GetBool() or false
end

-- Apply or clear movement speed when ffabot_freeze is toggled, with combat sprint and pace variations
function ENT:SyncFreezeSpeed()
    if self:IsFrozen() then
        if self.loco:GetDesiredSpeed() ~= 0 then
            self.loco:SetDesiredSpeed(0)
        end
        return
    end

    local now = CurTime()
    if now >= (self.NextPaceChangeTime or 0) then
        self.MovePaceMult = math.Rand(0.88, 1.12)
        self.CombatSprintMult = math.Rand(1.28, 1.44)
        self.NextPaceChangeTime = now + math.Rand(1.6, 3.8)
    end

    local speedMult = self.MovePaceMult or 1.0
    if self.IsSprintingCombat then
        speedMult = speedMult * (self.CombatSprintMult or 1.35)
    end

    local desired = (self.BaseMoveSpeed or 250) * speedMult
    if math.abs(self.loco:GetDesiredSpeed() - desired) > 1 then
        self.loco:SetDesiredSpeed(desired)
    end
end

-- Attempt a controlled jump with a cooldown so bots never jump-spam
function ENT:TryJump(minDelay, maxDelay)
    if self:IsFrozen() then return false end
    local now = CurTime()
    if now < (self.NextJumpTime or 0) then return false end
    if not self.loco:IsOnGround() then return false end

    self.loco:Jump()
    self.NextJumpTime = now + math.Rand(minDelay or 3.5, maxDelay or 6.5)
    return true
end

-- Check if there is a low obstacle ahead that can be cleared with a jump
function ENT:HasLowObstacleAhead(dir)
    if not dir or dir:LengthSqr() < 0.001 then return false end
    local stepDir = Vector(dir.x, dir.y, 0):GetNormalized()
    local startLow = self:GetPos() + Vector(0, 0, 14)
    local endLow = startLow + stepDir * 44

    local lowTr = util.TraceHull({
        start = startLow,
        endpos = endLow,
        mins = Vector(-12, -12, 0),
        maxs = Vector(12, 12, 26),
        filter = self
    })

    if not lowTr.Hit then return false end

    local startHigh = self:GetPos() + Vector(0, 0, 44)
    local endHigh = startHigh + stepDir * 44
    local highTr = util.TraceHull({
        start = startHigh,
        endpos = endHigh,
        mins = Vector(-12, -12, 0),
        maxs = Vector(12, 12, 28),
        filter = self
    })

    return not highTr.Hit
end

-- Check whether a player should be ignored by bots
function ENT:ShouldIgnorePlayer(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return false end
    local ignoreMod = GetConVar("ffabot_ignore_players")
    local ignoreEngine = GetConVar("ai_ignoreplayers")
    return (ignoreMod and ignoreMod:GetBool()) or (ignoreEngine and ignoreEngine:GetBool()) or false
end

-- Arm or refresh the bot's reaction timer when acquiring or re-acquiring a visible target
function ENT:ArmReactionTimer(scale)
    local cvar = GetConVar("ffa_bot_reaction_time")
    local baseDelay = math.Clamp(cvar and cvar:GetFloat() or 0.35, 0, 2.0)
    local jitter = baseDelay * math.Rand(-0.15, 0.15)
    local mult = scale or 1.0
    self.ReactionDelay = math.max(0, (baseDelay + jitter) * mult)
    self.TargetAcquiredTime = CurTime()
end

-- React when nearby bullets whiz past the bot so it turns toward the shooter
function ENT:OnHeardNearMiss(attacker, threatPos)
    if self:IsFrozen() or self:Health() <= 0 then return end
    if not IsValid(attacker) or attacker == self then return end
    if attacker:IsPlayer() and (not attacker:Alive() or self:ShouldIgnorePlayer(attacker)) then return end
    if attacker:GetClass() == "npc_ffa_nextbot" and attacker:Health() <= 0 then return end

    local now = CurTime()
    if now < (self.NextNearMissReactTime or 0) then return end
    self.NextNearMissReactTime = now + 1.2

    if threatPos then
        self:TurnSmoothlyToward(threatPos, 420)
    end

    if not IsValid(self.Enemy) or self.Enemy:Health() <= 0 or not self:CanSeeTarget(self.Enemy) then
        if self:CanSeeTarget(attacker) then
            self:SetEnemyTarget(attacker)
            self:ArmReactionTimer(0.75)
        elseif threatPos then
            self:TurnSmoothlyToward(threatPos, 450)
        end
    end
end

-- Assign a new target and reset the reaction delay whenever the enemy changes
function ENT:SetEnemyTarget(newEnemy)
    if IsValid(newEnemy) and newEnemy:IsPlayer() and self:ShouldIgnorePlayer(newEnemy) then
        newEnemy = nil
    end
    if newEnemy == self.Enemy then return end
    self.Enemy = newEnemy
    if IsValid(newEnemy) then
        self:ArmReactionTimer(1.0)
    else
        self.TargetAcquiredTime = 0
        self.ReactionDelay = 0
    end
end

-- Return true once the bot's reaction delay has elapsed since spotting the target
function ENT:HasFinishedReacting()
    if not IsValid(self.Enemy) then return false end
    if (self.TargetAcquiredTime or 0) <= 0 then
        self:ArmReactionTimer(1.0)
    end
    return (CurTime() - self.TargetAcquiredTime) >= (self.ReactionDelay or 0)
end

-- Smoothly turn the bot toward a world position instead of snapping yaw instantaneously
function ENT:TurnSmoothlyToward(targetPos, turnRateDegPerSec)
    local now = CurTime()
    local dt = math.Clamp(now - (self.LastTurnTime or now), 0.005, 0.1)
    self.LastTurnTime = now

    local myPos = self:GetPos()
    local desiredYaw = (targetPos - myPos):Angle().y
    local currentYaw = self:GetAngles().y
    local rate = turnRateDegPerSec or (self:HasFinishedReacting() and 340 or 180)

    local nextYaw = math.ApproachAngle(currentYaw, desiredYaw, rate * dt)
    self:SetAngles(Angle(0, nextYaw, 0))
end

-- Pick a weapon from the allowed pool (or fallback HL2 weapons) and replicate its worldmodel
function ENT:EquipRandomWeapon()
    local allowed = FFABot_AllowedWeapons or {}
    local pool = {}

    for cls, enabled in pairs(allowed) do
        if enabled then
            table.insert(pool, cls)
        end
    end

    if #pool > 0 then
        self.WeaponData = BuildWeaponData(pool[math.random(#pool)])
    else
        self.WeaponData = FALLBACK_WEAPONS[math.random(#FALLBACK_WEAPONS)]
    end

    self:SetHoldTypeName(self.WeaponData.holdtype)

    local wepModel = self.WeaponData.model
    if not wepModel or wepModel == "" or not util.IsValidModel(wepModel) then
        wepModel = "models/weapons/w_smg1.mdl"
    end

    self:SetActiveWeaponWorldModel(wepModel)
end

function ENT:OnRemove()
end

-- Update movement sequences, directional move_x/move_y pose parameters, and upper-body aim angles
function ENT:UpdateAnimations()
    local ht = (self.WeaponData and self.WeaponData.holdtype) or "ar2"
    local vel = self:IsFrozen() and Vector(0, 0, 0) or self.loco:GetVelocity()
    local speed = vel:Length2D()

    local seqName = "idle_ar2"
    if speed > 15 then
        if ht == "smg" then seqName = "run_smg1"
        elseif ht == "shotgun" then seqName = "run_shotgun"
        elseif ht == "pistol" then seqName = "run_pistol"
        else seqName = "run_ar2" end
    else
        if ht == "smg" then seqName = "idle_smg1"
        elseif ht == "shotgun" then seqName = "idle_shotgun"
        elseif ht == "pistol" then seqName = "idle_pistol"
        else seqName = "idle_ar2" end
    end

    local seq = self:LookupSequence(seqName)
    if seq <= 0 then
        seq = self:LookupSequence(speed > 15 and "run_all_01" or "idle_all_01")
    end

    if seq > 0 and self:GetSequence() ~= seq then
        self:ResetSequence(seq)
        self:SetCycle(0)
    end

    if speed > 5 then
        local forward = self:GetForward()
        local right = self:GetRight()
        local dir = vel:GetNormalized()
        self:SetPoseParameter("move_x", dir:Dot(forward))
        self:SetPoseParameter("move_y", dir:Dot(right))
        local maxRate = self.IsSprintingCombat and 1.75 or 1.5
        self:SetPlaybackRate(math.Clamp(speed / 220, 0.6, maxRate))
    else
        self:SetPoseParameter("move_x", 0)
        self:SetPoseParameter("move_y", 0)
        self:SetPlaybackRate(1)
    end

    if not self:IsFrozen() and IsValid(self.Enemy) and self.Enemy:Health() > 0 and self:HasFinishedReacting() then
        local eyePos = self:GetPos() + Vector(0, 0, 56)
        local targetPos = self.Enemy:GetPos() + Vector(0, 0, 48)
        local ang = (targetPos - eyePos):Angle()
        local diffYaw = math.NormalizeAngle(ang.y - self:GetAngles().y)
        local diffPitch = math.NormalizeAngle(ang.p)

        self:SetPoseParameter("aim_yaw", math.Clamp(diffYaw, -60, 60))
        self:SetPoseParameter("aim_pitch", math.Clamp(diffPitch, -45, 45))
    else
        self:SetPoseParameter("aim_yaw", 0)
        self:SetPoseParameter("aim_pitch", 0)
    end
end

-- Advance animations every engine tick
function ENT:BodyUpdate()
    self:SyncFreezeSpeed()
    self:UpdateAnimations()
    self:FrameAdvance()
end

-- Perform a line-of-sight trace check from eye height to the target's torso
function ENT:CanSeeTarget(target)
    if not IsValid(target) then return false end
    local startPos = self:GetPos() + Vector(0, 0, 56)
    local endPos = target:GetPos() + Vector(0, 0, 48)

    local tr = util.TraceLine({
        start = startPos,
        endpos = endPos,
        filter = self
    })

    return tr.Entity == target or not tr.Hit
end

-- Scan for the closest visible player or rival FFA NextBot within 3500 units
function ENT:FindNearestEnemy()
    local bestTarget = nil
    local bestDist = 3500 ^ 2
    local myPos = self:GetPos()

    for _, ent in ipairs(ents.GetAll()) do
        if ent ~= self and IsValid(ent) then
            local validTarget = false
            if ent:IsPlayer() and ent:Alive() and not self:ShouldIgnorePlayer(ent) then
                validTarget = true
            elseif ent:GetClass() == "npc_ffa_nextbot" and ent:Health() > 0 then
                validTarget = true
            end

            if validTarget then
                local distSqr = myPos:DistToSqr(ent:GetPos())
                if distSqr < bestDist and self:CanSeeTarget(ent) then
                    bestDist = distSqr
                    bestTarget = ent
                end
            end
        end
    end

    return bestTarget
end

-- Fire hitscan bullets, emit weapon sound, and trigger muzzleflash effect
function ENT:FireAtEnemy(enemy)
    if self:IsFrozen() then return end
    if CurTime() < self.NextShotTime then return end
    if not self:HasFinishedReacting() then return end
    if not IsValid(enemy) or not self.WeaponData then return end
    if enemy:IsPlayer() and self:ShouldIgnorePlayer(enemy) then return end

    local wep = self.WeaponData
    local accMult = math.Clamp(GetConVar("ffabot_accuracy"):GetFloat(), 0.2, 2.5)
    local shootPos = self:GetPos() + Vector(0, 0, 54)
    local targetPos = enemy:GetPos() + Vector(0, 0, 46)
    local aimDir = (targetPos - shootPos):GetNormalized()

    local dist = shootPos:Distance(targetPos)
    local distFactor = math.Clamp(dist / 1400, 0.85, 1.35)
    local moveFactor = self.IsSprintingCombat and 1.15 or 1.0
    local spread = ((wep.spread or 0.04) * distFactor * moveFactor) / accMult

    self:FireBullets({
        Attacker = self,
        Inflictor = self,
        Src = shootPos,
        Dir = aimDir,
        Spread = Vector(spread, spread, 0),
        Num = wep.pellets or 1,
        Damage = wep.damage or 14,
        Force = 3,
        Tracer = 1,
        TracerName = "Tracer"
    })

    self:EmitSound(wep.sound or "Weapon_SMG1.Single", 85, math.random(96, 104))

    local fx = EffectData()
    fx:SetOrigin(shootPos + aimDir * 28)
    fx:SetAngles(aimDir:Angle())
    fx:SetScale(1)
    util.Effect("MuzzleFlash", fx)

    self.NextShotTime = CurTime() + (wep.delay or 0.12) + math.Rand(0.02, 0.1)
end

-- Build a slightly offset roaming waypoint so bots don't walk in dead-straight predictable lines
local function BuildOrganicNavPoint(area)
    local pt = area:GetRandomPoint()
    local jitter = Vector(math.Rand(-95, 95), math.Rand(-95, 95), 0)
    local candidate = pt + jitter

    local tr = util.TraceHull({
        start = candidate + Vector(0, 0, 12),
        endpos = candidate + Vector(0, 0, 12),
        mins = Vector(-16, -16, 0),
        maxs = Vector(16, 16, 72),
        mask = MASK_NPCSOLID
    })

    if not tr.StartSolid and not tr.AllSolid and util.IsInWorld(candidate + Vector(0, 0, 16)) then
        return candidate
    end
    return pt
end

-- Navigate along a Navmesh path toward a destination while scanning for enemies and avoiding stuck states
function ENT:MoveToPosition(pos, maxTime)
    if self:IsFrozen() then
        self.IsSprintingCombat = false
        self:SyncFreezeSpeed()
        return false
    end

    self.IsSprintingCombat = false

    local path = Path("Follow")
    path:SetMinLookAheadDistance(260)
    path:SetGoalTolerance(50)
    path:Compute(self, pos)

    if not path:IsValid() then
        return false
    end

    local endTime = CurTime() + (maxTime or 6)
    local lastCheckTime = CurTime()
    local lastCheckPos = self:GetPos()
    local nextObstacleScan = CurTime() + 0.35

    while path:IsValid() and CurTime() < endTime do
        if self:IsFrozen() then
            self.IsSprintingCombat = false
            self:SyncFreezeSpeed()
            return false
        end

        self:SyncFreezeSpeed()

        if IsValid(self.Enemy) and self.Enemy:IsPlayer() and self:ShouldIgnorePlayer(self.Enemy) then
            self:SetEnemyTarget(nil)
        end

        if CurTime() > self.NextTargetScan then
            self.NextTargetScan = CurTime() + 0.2
            if not IsValid(self.Enemy) or self.Enemy:Health() <= 0 or not self:CanSeeTarget(self.Enemy) then
                self:SetEnemyTarget(self:FindNearestEnemy())
            end
        end

        if IsValid(self.Enemy) and self.Enemy:Health() > 0 and self:CanSeeTarget(self.Enemy) then
            return true
        end

        path:Update(self)

        -- Occasional low-obstacle or rare natural rhythm jump without spam
        if CurTime() >= nextObstacleScan then
            nextObstacleScan = CurTime() + 0.4
            local vel = self.loco:GetVelocity()
            if vel:Length2D() > 70 then
                if self:HasLowObstacleAhead(vel) then
                    self:TryJump(3.5, 6.0)
                elseif math.random() < 0.06 then
                    self:TryJump(4.5, 7.5)
                end
            end
        end

        -- Jump and abort current path if no meaningful progress was made over 1.5s
        if CurTime() - lastCheckTime > 1.5 then
            if self:GetPos():DistToSqr(lastCheckPos) < 45 ^ 2 then
                self:TryJump(2.5, 4.5)
                return false
            end
            lastCheckTime = CurTime()
            lastCheckPos = self:GetPos()
        end

        if self.loco:IsStuck() then
            self:HandleStuck()
            return false
        end

        if path:GetLength() < 55 then
            return true
        end

        coroutine.yield()
    end

    return true
end

-- Combat state: sprint and strafe dynamically with organic shifts while checking walls and ledges, and fire at the active enemy
function ENT:EngageEnemy(enemy)
    if self:IsFrozen() then
        self.IsSprintingCombat = false
        self:SyncFreezeSpeed()
        return
    end

    if IsValid(enemy) and enemy:IsPlayer() and self:ShouldIgnorePlayer(enemy) then
        self.IsSprintingCombat = false
        self:SetEnemyTarget(nil)
        return
    end

    self.IsSprintingCombat = true
    self:SyncFreezeSpeed()

    local endEngageTime = CurTime() + math.Rand(1.0, 1.8)
    local nextShiftTime = CurTime() + math.Rand(0.35, 0.75)
    local sideDir = (math.random(0, 1) == 0 and -1 or 1)
    local moveMode = math.random(1, 3)
    local stuckTimer = CurTime()
    local lastPos = self:GetPos()
    self.LastTurnTime = CurTime()

    if (self.TargetAcquiredTime or 0) <= 0 then
        self:ArmReactionTimer(1.0)
    end

    while IsValid(enemy) and enemy:Health() > 0 and CurTime() < endEngageTime do
        if self:IsFrozen() then
            self.IsSprintingCombat = false
            self:SyncFreezeSpeed()
            return
        end

        if enemy:IsPlayer() and self:ShouldIgnorePlayer(enemy) then
            self.IsSprintingCombat = false
            self:SetEnemyTarget(nil)
            return
        end

        self.IsSprintingCombat = true
        self:SyncFreezeSpeed()

        if not self:CanSeeTarget(enemy) then
            self.TargetAcquiredTime = 0
            self.IsSprintingCombat = false
            self:MoveToPosition(enemy:GetPos(), 2.5)
            return
        end

        if (self.TargetAcquiredTime or 0) <= 0 then
            self:ArmReactionTimer(1.0)
        end

        local now = CurTime()
        if now >= nextShiftTime then
            nextShiftTime = now + math.Rand(0.35, 0.8)
            if math.random() < 0.55 then
                sideDir = -sideDir
            end
            if math.random() < 0.45 then
                moveMode = math.random(1, 3)
            end
        end

        local myPos = self:GetPos()
        local enemyPos = enemy:GetPos()
        local dist = myPos:Distance(enemyPos)
        local toEnemy = (enemyPos - myPos):GetNormalized()
        local right = toEnemy:Angle():Right()

        -- Smoothly turn yaw instead of snapping immediately toward the enemy
        self:TurnSmoothlyToward(enemyPos, self:HasFinishedReacting() and 340 or 180)

        local moveVec = right * sideDir
        if dist < 320 or moveMode == 3 then
            moveVec = moveVec - toEnemy * 0.65
        elseif dist > 850 or moveMode == 2 then
            moveVec = moveVec + toEnemy * 0.65
        end

        local dirNorm = moveVec:GetNormalized()
        local targetStep = myPos + dirNorm * 125

        -- Check for lateral walls and drop-offs before stepping sideways
        local wallTr = util.TraceHull({
            start = myPos + Vector(0, 0, 24),
            endpos = targetStep + Vector(0, 0, 24),
            mins = Vector(-16, -16, 0),
            maxs = Vector(16, 16, 48),
            filter = self
        })

        local floorTr = util.TraceLine({
            start = targetStep + Vector(0, 0, 32),
            endpos = targetStep - Vector(0, 0, 120),
            filter = self
        })

        if wallTr.Hit or not floorTr.Hit then
            sideDir = -sideDir
            if self:HasLowObstacleAhead(dirNorm) then
                self:TryJump(3.5, 6.0)
            end
        else
            self.loco:Approach(targetStep, 1)
            if math.random() < 0.015 then
                self:TryJump(4.5, 7.5)
            end
        end

        local maxRange = (self.WeaponData and self.WeaponData.range) or 2400
        if dist <= maxRange then
            self:FireAtEnemy(enemy)
        end

        if CurTime() - stuckTimer > 1.2 then
            if self:GetPos():DistToSqr(lastPos) < 25 ^ 2 then
                sideDir = -sideDir
                self:TryJump(2.5, 4.5)
            end
            stuckTimer = CurTime()
            lastPos = self:GetPos()
        end

        coroutine.yield()
    end

    self.IsSprintingCombat = false
end

-- Automatically open doors when the bot walks into them
function ENT:OnContact(ent)
    if self:IsFrozen() or not IsValid(ent) then return end

    local cls = ent:GetClass()
    if cls == "prop_door_rotating" or cls == "func_door" or cls == "func_door_rotating" then
        if (ent.NextBotUseTime or 0) < CurTime() then
            ent.NextBotUseTime = CurTime() + 1.5
            ent:Fire("Open", "", 0)
        end
    end
end

-- Main NextBot coroutine loop: alternate between combat engagement and Navmesh roaming
function ENT:RunBehaviour()
    while true do
        self:SyncFreezeSpeed()

        if self:IsFrozen() then
            self.IsSprintingCombat = false
            coroutine.wait(0.2)
        elseif IsValid(self.Enemy) and self.Enemy:Health() > 0 and not (self.Enemy:IsPlayer() and self:ShouldIgnorePlayer(self.Enemy)) then
            self:EngageEnemy(self.Enemy)
        else
            self.IsSprintingCombat = false
            self:SetEnemyTarget(nil)
            local targetPos = nil
            local areas = navmesh.GetAllNavAreas()
            if areas and #areas > 0 then
                for _ = 1, 10 do
                    local randomArea = areas[math.random(#areas)]
                    if IsValid(randomArea) and not randomArea:IsUnderwater() and randomArea:GetSizeX() > 35 and randomArea:GetSizeY() > 35 then
                        local candidate = BuildOrganicNavPoint(randomArea)
                        if self:GetPos():DistToSqr(candidate) > 450 ^ 2 then
                            targetPos = candidate
                            break
                        end
                    end
                end
            end

            if targetPos then
                self:MoveToPosition(targetPos, 6.5)
            else
                coroutine.wait(0.2)
            end
        end
        coroutine.yield()
    end
end

-- Acquire the attacker as current target upon taking damage, arming reaction delay if newly spotted
function ENT:OnInjured(dmginfo)
    local attacker = dmginfo:GetAttacker()
    if IsValid(attacker) and attacker ~= self then
        if attacker:IsPlayer() then
            if self:ShouldIgnorePlayer(attacker) then return end
            if attacker ~= self.Enemy then
                self:SetEnemyTarget(attacker)
            elseif (self.TargetAcquiredTime or 0) <= 0 then
                self:ArmReactionTimer(0.85)
            end
        elseif attacker:GetClass() == "npc_ffa_nextbot" then
            if attacker ~= self.Enemy then
                self:SetEnemyTarget(attacker)
            elseif (self.TargetAcquiredTime or 0) <= 0 then
                self:ArmReactionTimer(0.85)
            end
        end
    end
end

-- Detect nearby gunfire trajectories so bots react when bullets pass close to them
hook.Add("EntityFireBullets", "FFABot_NearMissHearing", function(attacker, data)
    if not IsValid(attacker) or not data then return end
    local src = data.Src
    local dir = data.Dir
    if not src or not dir or dir:LengthSqr() < 0.001 then return end

    local normDir = dir:GetNormalized()
    local distLimit = math.Clamp(data.Distance or 3500, 200, 4500)
    local nearRadiusSqr = 195 ^ 2

    for _, bot in ipairs(ents.FindByClass("npc_ffa_nextbot")) do
        if IsValid(bot) and bot ~= attacker and bot:Health() > 0 and not bot:IsFrozen() then
            local toBot = (bot:GetPos() + Vector(0, 0, 46)) - src
            local proj = toBot:Dot(normDir)
            if proj > 0 and proj <= distLimit then
                local closestPt = src + normDir * proj
                if closestPt:DistToSqr(bot:GetPos() + Vector(0, 0, 46)) <= nearRadiusSqr then
                    bot:OnHeardNearMiss(attacker, attacker:GetPos() + Vector(0, 0, 48))
                end
            end
        end
    end
end)

-- Trigger third-party OnNPCKilled hooks, broadcast custom killfeed entries, and spawn a ragdoll
function ENT:OnKilled(dmginfo)
    local attacker = dmginfo:GetAttacker()
    local inflictor = dmginfo:GetInflictor()

    hook.Run("OnNPCKilled", self, attacker, inflictor)

    local victimName = (self:GetBotName() ~= "" and self:GetBotName()) or "FFA Bot"
    local wepClass = (IsValid(attacker) and attacker.WeaponData and attacker.WeaponData.class) or (IsValid(inflictor) and inflictor:GetClass()) or "npc_ffa_nextbot"

    if IsValid(attacker) and attacker:IsPlayer() then
        net.Start("PlayerKilledNPC")
            net.WriteString(victimName)
            net.WriteString(wepClass)
            net.WriteEntity(attacker)
        net.Broadcast()
    elseif IsValid(attacker) then
        local attackerName = (attacker.GetBotName and attacker:GetBotName() ~= "" and attacker:GetBotName()) or attacker:GetClass()
        net.Start("NPCKilledNPC")
            net.WriteString(victimName)
            net.WriteString(wepClass)
            net.WriteString(attackerName)
        net.Broadcast()
    end

    self:BecomeRagdoll(dmginfo)
end