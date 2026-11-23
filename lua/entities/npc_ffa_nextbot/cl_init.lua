include("shared.lua")

-- Create font used for the 3D floating nametag above each bot's head
surface.CreateFont("FFABot_NameTag", {
    font = "Roboto",
    size = 26,
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

    -- Hide nametag beyond 900 units to keep the screen clean and save performance
    local distSqr = ply:GetPos():DistToSqr(self:GetPos())
    if distSqr > 900 ^ 2 then return end

    -- Orient the 3D2D text plane so it always faces the local player's camera
    local headPos = self:GetPos() + Vector(0, 0, 80)
    local ang = (ply:EyePos() - headPos):Angle()
    ang:RotateAroundAxis(ang:Forward(), 90)
    ang:RotateAroundAxis(ang:Right(), -90)

    local alpha = math.Clamp(255 * (1 - (distSqr / (900 ^ 2))), 0, 255)

    cam.Start3D2D(headPos, ang, 0.14)
        draw.SimpleTextOutlined(
            name,
            "FFABot_NameTag",
            0, 0,
            Color(255, 255, 255, alpha),
            TEXT_ALIGN_CENTER,
            TEXT_ALIGN_CENTER,
            1.5,
            Color(0, 0, 0, alpha)
        )
    cam.End3D2D()
end