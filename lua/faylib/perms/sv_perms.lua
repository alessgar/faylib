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

NOTE: This is the Server API! Check cl_perms.lua for the Client API.

FUNCTIONS:

void Perms:SetAdminMod(string addonName, string adminMod)
 - Tells Perms what admin mod it should use when dealing with a particular addon

any Perms:AddPrivilege(string addonName, string privName, string minAccess="superadmin", string comment="A privilege created through FayLib", string category=addonName)
 - Adds the given privilege string to your admin mod of choice
 - If the set admin mod is ever unavailable, it will fall back to the built-in gmod admin system
 - If an admin mod is ever not set, it will fall back to the built-in gmod admin system

void Perms:UpdatePrivilege(string addonName, string privName, string minAccess="superadmin")
 - Updates a given privileges' mininimum access group, really only useful when using the built in gmod admin system

boolean Perms:PlayerHasAccess(string addonName, string privName, Player ply)
 - Will return whether or not the player has access to the given privilege
 - If the set admin mod is ever unavailable, it will fall back to the built-in gmod admin system

]]--

local FayLib = FayLib

local modName = "Perms"
FayLib[modName] = FayLib[modName] || {}

local function addAPIFunction(funcName, functionCode)
    FayLib.Backend.AddToAPI(modName, funcName, functionCode)
end
-- END BOILERPLATE CODE

util.AddNetworkString( "FAYLIB_Perms_SYNCPrivs" )
util.AddNetworkString( "FAYLIB_Perms_AddFAdminPriv" )

FayLib[modName]["AdminMod"] = FayLib[modName]["AdminMod"] || {}
FayLib[modName]["PrivList"] = FayLib[modName]["PrivList"] || {}

local validMinAccess = {"user", "admin", "superadmin"}

local function isAdminModAvailable(adminMod)
    return table.HasValue(FayLib[modName].getAvailableAdminMods(), adminMod)
end

addAPIFunction("SetAdminMod", function(addonName, adminMod)
    FayLib[modName]["PrivList"][addonName] = FayLib[modName]["PrivList"][addonName] || {}

    FayLib[modName]["AdminMod"][addonName] = adminMod

    net.Start("FAYLIB_Perms_SYNCPrivs")
        net.WriteString(util.TableToJSON(FayLib[modName]["AdminMod"]))
        net.WriteString(util.TableToJSON(FayLib[modName]["PrivList"]))
    net.Broadcast()
end)

addAPIFunction("AddPrivilege", function(addonName, privName, minAccess, comment, category )
    if minAccess == nil || !table.HasValue(validMinAccess, minAccess) then
        minAccess = "superadmin"
    end

    if comment == nil then
        comment = "A privilege created through FayLib"
    end

    if category == nil then
        category = addonName
    end

    FayLib[modName]["PrivList"][addonName][privName] = minAccess
    net.Start("FAYLIB_Perms_SYNCPrivs")
        net.WriteString(util.TableToJSON(FayLib[modName]["AdminMod"]))
        net.WriteString(util.TableToJSON(FayLib[modName]["PrivList"]))
    net.Broadcast()

    if isAdminModAvailable("ulx") then
        ULib.ucl.registerAccess( privName, minAccess, comment, category )
    end

    if isAdminModAvailable("fadmin") then
        local minAccessNum = 2
        if minAccess == "user" then
            minAccessNum = 0
        elseif minAccess == "admin" then
            minAccessNum = 1
        end

        FAdmin.Access.AddPrivilege(privName, minAccessNum)

        if minAccess == "superadmin" then
            RunConsoleCommand("fadmin", "addprivilege", "superadmin", privName)
        elseif minAccess == "admin" then
            RunConsoleCommand("fadmin", "addprivilege", "superadmin", privName)
            RunConsoleCommand("fadmin", "addprivilege", "admin", privName)
        end

        net.Start("FAYLIB_Perms_AddFAdminPriv")
            net.WriteString(privName)
            net.WriteInt(minAccessNum, 4)
        net.Broadcast()
    end
end)

addAPIFunction("UpdatePrivilege", function(addonName, privName, minAccess)
    if minAccess == nil || !table.HasValue(validMinAccess, minAccess) then
        minAccess = "superadmin"
    end

    FayLib[modName]["PrivList"][addonName][privName] = minAccess
    net.Start("FAYLIB_Perms_SYNCPrivs")
        net.WriteString(util.TableToJSON(FayLib[modName]["AdminMod"]))
        net.WriteString(util.TableToJSON(FayLib[modName]["PrivList"]))
    net.Broadcast()
end)

net.Receive("FAYLIB_Perms_SYNCPrivs", function(len, ply)
    net.Start("FAYLIB_Perms_SYNCPrivs")
        net.WriteString(util.TableToJSON(FayLib[modName]["AdminMod"]))
        net.WriteString(util.TableToJSON(FayLib[modName]["PrivList"]))
    net.Send(ply)
end)

hook.Add( "InitPostEntity", "FAYLIB_Perms_SERVERINITSYNC", function()
    for addonName, addonPrivList in pairs(FayLib[modName]["PrivList"]) do
        for privName, minAccess in pairs(addonPrivList) do
            FayLib[modName]["AddPrivilege"](addonName, privName, minAccess)
        end
    end
end )