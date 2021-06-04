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
local funcList = {}

local function addToAPITable(funcName, functionCode)
    funcList[funcName] = functionCode
end
-- END BOILERPLATE CODE

addToAPITable("AdminMod", {})
addToAPITable("PrivList", {})

-- returns whether the requested admin mod is actively loaded
addToAPITable("isAdminModAvailable", function(adminMod)
    return table.HasValue(FayLib.Perms.getAvailableAdminMods(), adminMod)
end)

-- returns a table containing all currently running admin mods
addToAPITable("getAvailableAdminMods", function()
    local availableAdminMods = {"gmod"}

    if ULib != nil && ulx != nil then
        table.insert(availableAdminMods, "ulx")
    end

    if FAdmin != nil then
        table.insert(availableAdminMods, "fadmin")
    end

    return availableAdminMods
end)

-- returns whether a player has the given privilege
addToAPITable("PlayerHasAccess", function(addonName, privName, ply)
    local adminMod = FayLib.Perms.AdminMod[addonName]

    -- fallback if preferred admin mod not available
    if adminMod == nil || !FayLib.Perms.isAdminModAvailable(adminMod) then
        adminMod = "gmod"
    end

    -- determine whether player has privilege based on admin mod
    local minAccess = FayLib.Perms.PrivList[addonName][privName]
    if adminMod == "gmod" then
        if minAccess == "superadmin" then
            return ply:IsUserGroup( "superadmin" )
        elseif minAccess == "admin" then
            return ply:IsUserGroup( "admin" ) || ply:IsUserGroup( "superadmin" )
        elseif minAccess == "user" then
            return true
        end
    elseif adminMod == "ulx" then
        return ULib.ucl.query( ply, privName, false )
    elseif adminMod == "fadmin" then
        local res = FAdmin.Access.PlayerHasPrivilege(ply, privName, ply, false)

        if res then
            return true
        end
    end

    return false
end)

return {modName, funcList}