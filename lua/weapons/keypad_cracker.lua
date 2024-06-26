-- This is sorta horrible
AddCSLuaFile()

local keypad_crack_time = CreateConVar( "keypad_crack_time", "20", { FCVAR_ARCHIVE }, "Seconds for keypad cracker to crack keypad" )

if SERVER then
    util.AddNetworkString( "KeypadCracker_Hold" )
    util.AddNetworkString( "KeypadCracker_Sparks" )
end

if CLIENT then
    SWEP.PrintName = "Keypad Cracker"
    SWEP.Slot = 4
    SWEP.SlotPos = 1
    SWEP.DrawAmmo = false
    SWEP.DrawCrosshair = true
end

-- SWEP.Author = "Willox" removed for consistency with other SWEP, but credit is still here.
SWEP.Instructions = "Hold up to Keypad."
SWEP.Contact = ""
SWEP.Purpose = "Handheld Keypad Cracker tool used to force entry into player bases."
SWEP.Category = "Raid Tools"
SWEP.UseHands = true
SWEP.ViewModelFOV = 65
SWEP.ViewModelFlip = false
SWEP.ViewModel = Model( "models/weapons/cstrike/c_c4.mdl" )
SWEP.WorldModel = Model( "models/weapons/w_c4.mdl" )
SWEP.Spawnable = true
SWEP.AdminOnly = false
SWEP.AnimPrefix = "python"
SWEP.Sound = Sound( "weapons/deagle/deagle-1.wav" )
SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "none"
SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"
SWEP.KeyCrackSound = Sound( "buttons/blip2.wav" )
SWEP.IdleStance = "slam"

function SWEP:Initialize()
    self:SetHoldType( self.IdleStance )

    if SERVER then
        net.Start( "KeypadCracker_Hold" )
        net.WriteEntity( self )
        net.WriteBit( true )
        net.Broadcast()
        self:SetCrackTime( keypad_crack_time:GetInt() )
    end
end

function SWEP:SetupDataTables()
    self:NetworkVar( "Int", 0, "CrackTime" )
end

function SWEP:PrimaryAttack()
    self:SetNextPrimaryFire( CurTime() + 0.4 )
    if self.IsCracking or not IsValid( self:GetOwner() ) then return end
    local tr = self:GetOwner():GetEyeTrace()
    local ent = tr.Entity

    if IsValid( ent ) and tr.HitPos:Distance( self:GetOwner():GetShootPos() ) <= 50 and ent.IsKeypad then
        self.IsCracking = true
        self.StartCrack = CurTime()
        self.EndCrack = CurTime() + self:GetCrackTime()
        self:SetWeaponHoldType( "pistol" ) -- TODO: Send as networked message for other clients to receive

        if SERVER then
            net.Start( "KeypadCracker_Hold" )
            net.WriteEntity( self )
            net.WriteBit( true )
            net.Broadcast()

            timer.Create( "KeyCrackSounds: " .. self:EntIndex(), 1, self:GetCrackTime(), function()
                if IsValid( self ) and self.IsCracking then
                    self:EmitSound( self.KeyCrackSound, 100, 100 )
                end
            end )
        else
            self.Dots = self.Dots or ""
            local entindex = self:EntIndex()

            timer.Create( "KeyCrackDots: " .. entindex, 0.5, 0, function()
                if not IsValid( self ) then
                    timer.Remove( "KeyCrackDots: " .. entindex )
                else
                    local len = string.len( self.Dots )

                    local dots = {
                        [0] = ".",
                        [1] = "..",
                        [2] = "...",
                        [3] = ""
                    }

                    self.Dots = dots[len]
                end
            end )
        end
    end
end

function SWEP:Holster()
    self.IsCracking = false

    if SERVER then
        timer.Remove( "KeyCrackSounds: " .. self:EntIndex() )
    else
        timer.Remove( "KeyCrackDots: " .. self:EntIndex() )
    end

    return true
end

function SWEP:Reload()
    return true
end

function SWEP:Succeed()
    self.IsCracking = false
    local tr = self:GetOwner():GetEyeTrace()
    local ent = tr.Entity
    self:SetWeaponHoldType( self.IdleStance )

    if SERVER and IsValid( ent ) and tr.HitPos:Distance( self:GetOwner():GetShootPos() ) <= 50 and ent.IsKeypad then
        ent:Process( true )
        net.Start( "KeypadCracker_Hold" )
        net.WriteEntity( self )
        net.WriteBit( true )
        net.Broadcast()
        net.Start( "KeypadCracker_Sparks" )
        net.WriteEntity( ent )
        net.Broadcast()
    end

    if SERVER then
        timer.Remove( "KeyCrackSounds: " .. self:EntIndex() )
    else
        timer.Remove( "KeyCrackDots: " .. self:EntIndex() )
    end
end

function SWEP:Fail()
    self.IsCracking = false
    self:SetWeaponHoldType( self.IdleStance )

    if SERVER then
        net.Start( "KeypadCracker_Hold" )
        net.WriteEntity( self )
        net.WriteBit( true )
        net.Broadcast()
        timer.Remove( "KeyCrackSounds: " .. self:EntIndex() )
    else
        timer.Remove( "KeyCrackDots: " .. self:EntIndex() )
    end
end

function SWEP:Think()
    if not self.StartCrack then
        self.StartCrack = 0
        self.EndCrack = 0
    end

    if self.IsCracking and IsValid( self:GetOwner() ) then
        local tr = self:GetOwner():GetEyeTrace()

        if not IsValid( tr.Entity ) or tr.HitPos:Distance( self:GetOwner():GetShootPos() ) > 50 or not tr.Entity.IsKeypad then
            self:Fail()
        elseif self.EndCrack <= CurTime() then
            self:Succeed()
        end
    else
        self.StartCrack = 0
        self.EndCrack = 0
    end

    self:NextThink( CurTime() )

    return true
end

if CLIENT then
    SWEP.BoxColor = Color( 10, 10, 10, 200 )

    surface.CreateFont( "KeypadCrack", {
        font = "Trebuchet",
        size = 100,
        weight = 600,
    } )

    surface.CreateFont( "KeypadCrackNumbers", {
        font = "Trebuchet",
        size = 80,
        weight = 600,
    } )

    function SWEP:PostDrawViewModel( vm )
        if not self.IsCracking then return end
        if not self.StartCrack then
            self.StartCrack = CurTime()
            self.EndCrack = CurTime() + self:GetCrackTime()
        end

        if not IsValid( vm ) then return end

        local bone = vm:LookupBone( "v_weapon.c4" )
        if not bone then return end

        local pos, ang = vm:GetBonePosition( bone )
        if not pos then return end

        ang:RotateAroundAxis( ang:Right(), 180 )
        ang:RotateAroundAxis( ang:Forward(), -90 )
        cam.Start3D2D( pos - ang:Right() * 0.75 + ang:Up() * 4 + ang:Forward() * 4.33, ang, 0.005 )

        local frac = math.Clamp( ( CurTime() - self.StartCrack ) / ( self.EndCrack - self.StartCrack ), 0, 1 ) -- Between 0 and 1 (a fraction omg segregation)
        local dots = self.Dots or ""
        local x, y = -330, 25
        local w, h = 680, 100
        draw.RoundedBox( 4, x, y, w, h, self.BoxColor )
        surface.SetDrawColor( Color( 255 + frac * -255, frac * 255, 40 ) )
        surface.DrawRect( x + 5, y + 5, frac * ( w - 10 ), h - 10 )
        surface.SetFont( "KeypadCrack" )

        local fontw, fonth = surface.GetTextSize( "Cracking" )
        local fontx, fonty = ( x + w / 2 ) - fontw / 2, ( y + h / 2 ) - fonth / 2

        surface.SetTextPos( fontx, fonty - 120 )
        surface.SetTextColor( color_black )
        surface.DrawText( "Cracking" .. dots )
        surface.SetTextPos( fontx, fonty - 120 )
        surface.SetTextColor( color_white )
        surface.DrawText( "Cracking" .. dots )

        local timeLeft = math.Round( self.EndCrack - CurTime() )
        surface.SetFont( "KeypadCrackNumbers" )
        surface.SetTextPos( fontx - 90, fonty + 110 )
        surface.SetTextColor( color_black )
        surface.DrawText( timeLeft .. " seconds left" )
        surface.SetTextPos( fontx - 90, fonty + 110 )
        surface.SetTextColor( color_white )
        surface.DrawText( timeLeft .. " seconds left" )

        cam.End3D2D()
    end

    SWEP.DownAngle = Angle( -10, 0, 0 )
    SWEP.LowerPercent = 1
    SWEP.SwayScale = 0

    function SWEP:GetViewModelPosition( pos, ang )
        if self.IsCracking then
            local delta = FrameTime() * 3.5
            self.LowerPercent = math.Clamp( self.LowerPercent - delta, 0, 1 )
        else
            local delta = FrameTime() * 5
            self.LowerPercent = math.Clamp( self.LowerPercent + delta, 0, 1 )
        end

        ang:RotateAroundAxis( ang:Forward(), self.DownAngle.p * self.LowerPercent )
        ang:RotateAroundAxis( ang:Right(), self.DownAngle.p * self.LowerPercent )

        return self.BaseClass.GetViewModelPosition( self, pos, ang )
    end

    net.Receive( "KeypadCracker_Hold", function()
        local ent = net.ReadEntity()
        local state = net.ReadBit() == 1

        if IsValid( ent ) and ent:IsWeapon() and ent:GetClass():lower() == "keypad_cracker" and not game.SinglePlayer() and ent.SetWeaponHoldType then
            if not state then
                ent:SetWeaponHoldType( ent.IdleStance )
                ent.IsCracking = false
            else
                ent:SetWeaponHoldType( "pistol" )
                ent.IsCracking = true
            end
        end
    end )

    net.Receive( "KeypadCracker_Sparks", function()
        local ent = net.ReadEntity()

        if IsValid( ent ) then
            local vPoint = ent:GetPos()
            local effect = EffectData()
            effect:SetStart( vPoint )
            effect:SetOrigin( vPoint )
            effect:SetEntity( ent )
            effect:SetScale( 2 )
            util.Effect( "cball_bounce", effect )
            ent:EmitSound( "buttons/combine_button7.wav", 100, 100 )
        end
    end )
end
