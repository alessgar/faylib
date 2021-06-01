--[[

 ________  _______   ________  _____ ______   ___  ________   ________  ___  ________  ________   ________      
|\   __  \|\  ___ \ |\   __  \|\   _ \  _   \|\  \|\   ____\ |\   ____\|\  \|\   __  \|\   ___  \|\   ____\     
\ \  \|\  \ \   __/|\ \  \|\  \ \  \\\__\ \  \ \  \ \  \___|_\ \  \___|\ \  \ \  \|\  \ \  \\ \  \ \  \___|_    
 \ \   ____\ \  \_|/_\ \   _  _\ \  \\|__| \  \ \  \ \_____  \\ \_____  \ \  \ \  \\\  \ \  \\ \  \ \_____  \   
  \ \  \___|\ \  \_|\ \ \  \\  \\ \  \    \ \  \ \  \|____|\  \\|____|\  \ \  \ \  \\\  \ \  \\ \  \|____|\  \  
   \ \__\    \ \_______\ \__\\ _\\ \__\    \ \__\ \__\____\_\  \ ____\_\  \ \__\ \_______\ \__\\ \__\____\_\  \ 
    \|__|     \|_______|\|__|\|__|\|__|     \|__|\|__|\_________\\_________\|__|\|_______|\|__| \|__|\_________\
                                                     \|_________\|_________|                        \|_________|
                                                                                                                

A backend API designed to make it easy to work between different admin mods on a server.
This will do all the communication between addons so you don't have to!

Note: To see the client and server API, please see the respective cl_perms and sv_perms files!

]]--

local FayLib = FayLib

local modName = "Perms"
FayLib[modName] = FayLib[modName] || {}

local function addAPIFunction(funcName, functionCode)
    FayLib.Backend.AddToAPI(modName, funcName, functionCode)
end
-- END BOILERPLATE CODE

FayLib[modName]["AdminMod"] = FayLib[modName]["AdminMod"] || {}
FayLib[modName]["PrivList"] = FayLib[modName]["PrivList"] || {}

local function isAdminModAvailable(adminMod)
    return table.HasValue(FayLib[modName].getAvailableAdminMods(), adminMod)
end

FayLib[modName].getAvailableAdminMods = function()
    local availableAdminMods = {"gmod"}

    if ULib != nil && ulx != nil then
        table.insert(availableAdminMods, "ulx")
    end

    if FAdmin != nil then
        table.insert(availableAdminMods, "fadmin")
    end

    return availableAdminMods
end

addAPIFunction("PlayerHasAccess", function(addonName, privName, ply)
    local adminMod = FayLib[modName]["AdminMod"][addonName]

    if adminMod == nil || !isAdminModAvailable(adminMod) then
        adminMod = "gmod"
    end

    local minAccess = FayLib[modName]["PrivList"][addonName][privName]
    if adminMod == "gmod" then
        if minAccess == "superadmin" then
            return ply:IsUserGroup( "superadmin" )
        elseif minAccess == "admin" then
            return ply:IsUserGroup( "admin" ) || ply:IsUserGroup( "superadmin" )
        elseif minAccess == "user" then
            return true
        end
    elseif adminMod == "ulx" then
        return ULib.ucl.query( ply, privName, true )
    elseif adminMod == "fadmin" then
        local res = FAdmin.Access.PlayerHasPrivilege(ply, privName, ply, false)

        if res then
            return true
        end
    end

    return false
end)