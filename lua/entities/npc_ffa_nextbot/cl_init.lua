include("shared.lua")

local cvarTagScale = CreateClientConVar("ffa_nb_nametag_scale", "1.0", true, false)
local cvarTagColor = CreateClientConVar("ffa_nb_nametag_color", "255 255 255", true, false)
local cvarTagDist  = CreateClientConVar("ffa_nb_nametag_dist", "900", true, false)

-- Pre-allocated objects to avoid per-frame garbage collection micro-stutters
local HEAD_OFFSET   = Vector(0, 0, 80)
local TAG_COLOR     = Color(255, 255, 255, 255)
local OUTLINE_COLOR = Color(0, 0, 0, 255)

-- Create font used for the 3D floating nametag above each bot's head
surface.CreateFont("FFABot_NameTag", {
    font = "Roboto",
    size = 32,
    weight = 700,
    antialias = true
})

-- Clean up the client-side weapon prop when the bot entity is removed
function ENT:OnRemove()
    if IsValid(self.ClientWeaponModel) then
        self.ClientWeaponModel:Remove()
    end
end

-- Render the bot's equipped worldmodel aligned to its right hand bone
function ENT:DrawWeaponModel()
    local mdl = self:GetActiveWeaponWorldModel()
    if not mdl or mdl == "" then return end

    -- Create or update the cached ClientsideModel if the weapon model changed
    if not IsValid(self.ClientWeaponModel) or self.ClientWeaponModel:GetModel() ~= mdl then
        if IsValid(self.ClientWeaponModel) then
            self.ClientWeaponModel:Remove()
        end
        self.ClientWeaponModel = ClientsideModel(mdl, RENDERGROUP_OPAQUE)
        if IsValid(self.ClientWeaponModel) then
            self.ClientWeaponModel:SetNoDraw(true)
        end
    end

    local wep = self.ClientWeaponModel
    if not IsValid(wep) then return end

    local boneId = self:LookupBone("ValveBiped.Bip01_R_Hand")
    if not boneId then return end

    local matrix = self:GetBoneMatrix(boneId)
    if not matrix then return end

    local pos = matrix:GetTranslation()
    local ang = matrix:GetAngles()

    -- Offset and rotate the weapon model to fit properly inside the right palm
    pos = pos + ang:Forward() * 3.5 + ang:Right() * 1.0 + ang:Up() * -1.0
    ang:RotateAroundAxis(ang:Up(), 180)
    ang:RotateAroundAxis(ang:Forward(), 180)

    wep:SetPos(pos)
    wep:SetAngles(ang)
    wep:SetupBones()
    wep:DrawModel()
end

-- Main client-side render pass: draw the bot, its weapon, and a distance-faded 3D2D nametag
function ENT:Draw()
    self:DrawModel()
    self:DrawWeaponModel()

    local name = self:GetBotName()
    if not name or name == "" then return end

    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    -- Hide nametag beyond configured distance to keep the screen clean and save performance
    local maxDist = math.Clamp(cvarTagDist:GetFloat(), 200, 2500)
    local maxDistSqr = maxDist ^ 2
    local distSqr = ply:GetPos():DistToSqr(self:GetPos())
    if distSqr > maxDistSqr then return end

    -- Orient the 3D2D text plane so it always faces the local player's camera
    local headPos = self:GetPos() + HEAD_OFFSET
    local ang = (ply:EyePos() - headPos):Angle()
    ang:RotateAroundAxis(ang:Forward(), 90)
    ang:RotateAroundAxis(ang:Right(), -90)

    local alpha = math.Clamp(255 * (1 - (distSqr / maxDistSqr)), 0, 255)
    local scale = 0.14 * math.Clamp(cvarTagScale:GetFloat(), 0.5, 3.0)

    local r, g, b = string.match(cvarTagColor:GetString(), "(%d+)%s+(%d+)%s+(%d+)")
    TAG_COLOR.r = tonumber(r) or 255
    TAG_COLOR.g = tonumber(g) or 255
    TAG_COLOR.b = tonumber(b) or 255
    TAG_COLOR.a = alpha
    OUTLINE_COLOR.a = alpha

    cam.Start3D2D(headPos, ang, scale)
        draw.SimpleTextOutlined(
            name,
            "FFABot_NameTag",
            0, 0,
            TAG_COLOR,
            TEXT_ALIGN_CENTER,
            TEXT_ALIGN_CENTER,
            1.5,
            OUTLINE_COLOR
        )
    cam.End3D2D()
end