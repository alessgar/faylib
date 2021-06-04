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
local funcList = {}

local function addToAPITable(funcName, functionCode)
    funcList[funcName] = functionCode
end
-- END BOILERPLATE CODE

addToAPITable("AdminMod", {})
addToAPITable("PrivList", {})

-- Updates the clientside privilege list and admin mod preferences list when the server says so
net.Receive("FAYLIB_Perms_SYNCPrivs", function(len)
    local newAModString = net.ReadString()
    local newPrivsString = net.ReadString()
    FayLib.Perms.AdminMod = util.JSONToTable(newAModString)
    FayLib.Perms.PrivList = util.JSONToTable(newPrivsString)

    -- if FAdmin is available when we first sync, we run AddPrivilege on the client so that the permissions appear on the FAdmin menu
    if net.ReadBool() && FayLib.Perms.isAdminModAvailable("fadmin") then
        for addonName, addonPrivList in pairs(FayLib.Perms.PrivList) do
            for privName, minAccess in pairs(addonPrivList) do
                -- we have to convert minAccess to a number for FAdmin
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

-- used to run needed FAdmin code clientside when a permission is added
net.Receive("FAYLIB_Perms_AddFAdminPriv", function(len)
    local privName = net.ReadString()
    local minAccessNum = net.ReadInt(4)
    FAdmin.Access.AddPrivilege(privName, minAccessNum)
end)

-- when game is loaded, request current privilege lists from server
hook.Add( "InitPostEntity", "FAYLIB_Perms_CLIENTINITSYNC", function()
    net.Start("FAYLIB_Perms_SYNCPrivs")
    net.SendToServer()
end )

return {modName, funcList}