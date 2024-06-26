AddCSLuaFile( "cl_init.lua" )
AddCSLuaFile( "sh_init.lua" )

include( "sh_init.lua" )

util.AddNetworkString( "Keypad_Wire" )

net.Receive( "Keypad_Wire", function( _, ply )
    local ent = net.ReadEntity()
    if not IsValid( ply ) or not IsValid( ent ) or ent:GetClass() ~= "keypad_wire" then return end
    if ent:GetKeypadStatus() ~= ent.Status_None then return end
    if ply:EyePos():Distance( ent:GetPos() ) >= 120 then return end

    if ent.Next_Command_Time and ent.Next_Command_Time > CurTime() then return end
    ent.Next_Command_Time = CurTime() + 0.05

    local command = net.ReadUInt( 4 )

    if command == ent.Command_Enter then
        local val = tonumber( ent:GetValue() .. net.ReadUInt( 8 ) )

        if val and val > 0 and val <= 9999 then
            ent:SetValue( tostring( val ) )
            ent:EmitSound( "buttons/button15.wav" )
        end
        return
    end

    if command == ent.Command_Abort then
        ent:SetValue( "" )
        return
    end

    if command == ent.Command_Accept then
        if ent:GetValue() == ent:GetPassword() then
            ent:Process( true )
        else
            ent:Process( false )
        end

        return
    end

    if command == ent.Command_ID then
        if ent:GetKeypadOwner() == ply then
            ent:Process( true )
            return
        end

        local steamid = ply:SteamID()
        if ent.AllowedPlayers[steamid] then
            ent:Process( true )
            return
        end

        ent:Process( false )
    end
end )

function ENT:SetValue( val )
    self.Value = val

    if self:GetSecure() then
        self:SetText( string.rep( "*", #val ) )
    else
        self:SetText( val )
    end
end

function ENT:GetValue()
    return self.Value
end

function ENT:Process( granted )
    self:GetData()
    local length, repeats, delay, initdelay, outputKey

    if granted then
        self:SetKeypadStatus( self.Status_Granted )
        length = math.max( self.KeypadData.LengthGranted, GetConVar( "keypad_min_granted_hold_lenght" ):GetFloat() )
        initdelay = math.min( self.KeypadData.InitDelayGranted, GetConVar( "keypad_max_granted_initial_lenght" ):GetFloat() )
        repeats = math.min( self.KeypadData.RepeatsGranted, 50 )
        delay = self.KeypadData.DelayGranted
        outputKey = "Access Granted"
    else
        self:SetKeypadStatus( self.Status_Denied )
        length = self.KeypadData.LengthDenied
        repeats = math.min( self.KeypadData.RepeatsDenied, 50 )
        delay = self.KeypadData.DelayDenied
        initdelay = self.KeypadData.InitDelayDenied
        outputKey = "Access Denied"
    end

    -- 0.25 after last timer
    timer.Simple( math.max( initdelay + length * ( repeats + 1 ) + delay * repeats + 0.25, 2 ), function()
        if IsValid( self ) then
            self:Reset()
        end
    end )

    timer.Simple( initdelay, function()
        if IsValid( self ) then
            for i = 0, repeats do
                timer.Simple( length * i + delay * i, function()
                    if IsValid( self ) then
                        Wire_TriggerOutput( self, outputKey, self.KeypadData.OutputOn )
                    end
                end )

                timer.Simple( length * ( i + 1 ) + delay * i, function()
                    if IsValid( self ) then
                        Wire_TriggerOutput( self, outputKey, self.KeypadData.OutputOff )
                    end
                end )
            end
        end
    end )

    if granted then
        self:EmitSound( "buttons/button9.wav" )
    else
        self:EmitSound( "buttons/button11.wav" )
    end
end

function ENT:SetData( data )
    self.KeypadData = data
    self:SetPassword( data.Password or "1337" )
    self:Reset()
    duplicator.StoreEntityModifier( self, "keypad_wire_password_passthrough", self.KeypadData )
end

function ENT:GetData()
    return self.KeypadData
end

function ENT:GetData()
    if not self.KeypadData then
        self:SetData( {
            Password = false,
            RepeatsGranted = 0,
            RepeatsDenied = 0,
            LengthGranted = 0,
            LengthDenied = 0,
            DelayGranted = 0,
            DelayDenied = 0,
            InitDelayGranted = 0,
            InitDelayDenied = 0,
            OutputOn = 0,
            OutputOff = 0,
            Secure = false
        } )
    end

    return self.KeypadData
end

function ENT:Reset()
    self:GetData()
    self:SetValue( "" )
    self:SetKeypadStatus( self.Status_None )
    self:SetSecure( self.KeypadData.Secure )
    Wire_TriggerOutput( self, "Access Granted", self.KeypadData.OutputOff )
    Wire_TriggerOutput( self, "Access Denied", self.KeypadData.OutputOff )
end

duplicator.RegisterEntityModifier( "keypad_wire_password_passthrough", function( ply, entity, data )
    entity:SetKeypadOwner( ply )
    entity:SetData( data )
end )
