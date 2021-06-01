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

NOTE: This is the Client API! Check sv_perms.lua for the Server API.

FUNCTIONS:

boolean Perms:PlayerHasAccess(string addonName, string privName, Player ply)
 - Will return whether or not the player has access to the given privilege
 - If the set admin mod is ever unavailable, it will fall back to the built-in gmod admin system

]]--

local FayLib = FayLib

local modName = "Perms"
FayLib[modName] = FayLib[modName] || {}
-- END BOILERPLATE CODE

FayLib[modName]["AdminMod"] = FayLib[modName]["AdminMod"] || {}
FayLib[modName]["PrivList"] = FayLib[modName]["PrivList"] || {}

local function isAdminModAvailable(adminMod)
    return table.HasValue(FayLib[modName].getAvailableAdminMods(), adminMod)
end

net.Receive("FAYLIB_Perms_SYNCPrivs", function(len)
    local newAModString = net.ReadString()
    local newPrivsString = net.ReadString()
    FayLib[modName]["AdminMod"] = util.JSONToTable(newAModString)
    FayLib[modName]["PrivList"] = util.JSONToTable(newPrivsString)

    if isAdminModAvailable("fadmin") then
        for addonName, addonPrivList in pairs(FayLib[modName]["PrivList"]) do
            for privName, minAccess in pairs(addonPrivList) do
                local minAccessNum = 2
                if minAccess == "user" then
                    minAccessNum = 0
                elseif minAccess == "admin" then
                    minAccessNum = 1
                end

                FAdmin.Access.AddPrivilege(privName, minAccessNum)
            end
        end
    end
end)

net.Receive("FAYLIB_Perms_AddFAdminPriv", function(len)
    local privName = net.ReadString()
    local minAccessNum = net.ReadInt(4)
    FAdmin.Access.AddPrivilege(privName, minAccessNum)
end)

hook.Add( "InitPostEntity", "FAYLIB_Perms_CLIENTINITSYNC", function()
    net.Start("FAYLIB_Perms_SYNCPrivs")
    net.SendToServer()
end )