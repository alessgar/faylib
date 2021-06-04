--[[

 ___  ________                  ________  ________  _____ ______   _______           ________  ________  ________   ________ ___  ________
|\  \|\   ___  \               |\   ____\|\   __  \|\   _ \  _   \|\  ___ \         |\   ____\|\   __  \|\   ___  \|\  _____\\  \|\   ____\
\ \  \ \  \\ \  \  ____________\ \  \___|\ \  \|\  \ \  \\\__\ \  \ \   __/|        \ \  \___|\ \  \|\  \ \  \\ \  \ \  \__/\ \  \ \  \___|
 \ \  \ \  \\ \  \|\____________\ \  \  __\ \   __  \ \  \\|__| \  \ \  \_|/__       \ \  \    \ \  \\\  \ \  \\ \  \ \   __\\ \  \ \  \  ___
  \ \  \ \  \\ \  \|____________|\ \  \|\  \ \  \ \  \ \  \    \ \  \ \  \_|\ \       \ \  \____\ \  \\\  \ \  \\ \  \ \  \_| \ \  \ \  \|\  \
   \ \__\ \__\\ \__\              \ \_______\ \__\ \__\ \__\    \ \__\ \_______\       \ \_______\ \_______\ \__\\ \__\ \__\   \ \__\ \_______\
    \|__|\|__| \|__|               \|_______|\|__|\|__|\|__|     \|__|\|_______|        \|_______|\|_______|\|__| \|__|\|__|    \|__|\|_______|


A backend API designed to easily create complex addon configurations that can be edited, saved, and loaded without a large, complicated configutation file for users
Especially useful if you want to allow user configuration while in-game, as this module provides various functions and hooks to enable just that!

NOTE: This is the Client API! Check sv_configsync.lua for the Server API.

NOTE 2: Shared variables are read-only, as they are supposed to be variables the server has decided to share with you.

NOTE 3: The following values/types have been tested with and can be saved properly into a configuration - numbers, strings, booleans, nil, Vectors, Angles, Colors, tables

NOTE 4: any NaN or INF values will be turned into a 0 to avoid a bug that causes broken JSON to output (according to the gmod wiki). You will get a warning in the console when this happens.

FUNCTIONS:

void IGC:DefineClientKey(string addonName, string keyName, any defaultValue)
 - Defines a client-side configuration key for the specified addon, as well as the value it will take if no save is loaded

any IGC:GetClientKey(string addonName, string keyName)
 - Attempts to get the value of a client-side configuration variable for the given addon
 - returns nil if not found

any IGC:GetSharedKey(string addonName, string keyName)
 - Attempts to get the value of a shared configuration variable for the given addon
 - returns nil if not found

boolean IGC:IsSharedReady()
 - Returns true if the initial shared config sync has occurred (happens during server join, during client lua startup)

void IGC:SetClientKey(string addonName, string keyName, any newValue)
 - Sets an existing client-side configuration key for the specified addon to the specified value

void IGC:SaveClientConfig(string addonName, fileName, folderName="faylib")
 - Saves a copy of the client-side configuration for the specified addon onto the disk using the provided folder and fileName

void IGC:LoadClientConfig(string addonName, fileName, folderName="faylib")
 - Attempts to load a saved client-side configuration for the given addon from the provided folder and fileName
 - saves configuration of default values (from IGC:DefineClientKey) if the file is not found
 - If a previously declared key is not present in loaded config, the default value of that key will be inserted into the config table

HOOKS:

IGCConfigUpdate(string addonName)
 - Called when client-side or shared configuration value(s) are updated
 - provides the addon name for the configuration that was updated

IGCClientConfigUpdate(string addonName)
 - Called when client-side configuration value(s) are updated
 - provides the addon name for the configuration that was updated

IGCSharedConfigUpdate(string addonName)
 - Called when shared configuration value(s) are updated
 - provides the addon name for the configuration that was updated

IGCSharedConfigReady()
 - Called when shared configuration value(s) are populated for the first time
 - no addon name given because all addon configurations are assumed to be updated

]]--

local FayLib = FayLib

local hook_Run = hook.Run
local ipairs = ipairs
local net_Receive = net.Receive
local net_ReadString = net.ReadString
local util_JSONToTable = util.JSONToTable
local table_GetKeys = table.GetKeys
local hook_Add = hook.Add
local net_Start = net.Start
local net_SendToServer = CLIENT && net.SendToServer

local modName = "IGC"
local funcList = {}

local function addToAPITable(funcName, functionCode)
	funcList[funcName] = functionCode
end
-- END BOILERPLATE CODE

local newCFG = {}
newCFG.Client = {}
newCFG.Shared = {}
newCFG.SharedReady = false
addToAPITable("Config", newCFG)

-- defines a key in the given addons config
addToAPITable("DefineClientKey", function(addonName, keyName, defaultValue)
	FayLib.IGC.sharedDefineKey(addonName, keyName, defaultValue, "Client")

	-- run related hooks
	hook_Run("IGCConfigUpdate", addonName)
	hook_Run("IGCClientConfigUpdate", addonName)
end)

-- gets the current state of the client key in the given addon
addToAPITable("GetClientKey", function(addonName, keyName)
	return FayLib.IGC.Config.Client[addonName]["_" .. keyName]
end)

-- gets the current state of the shared key in the given addon
addToAPITable("GetSharedKey", function(addonName, keyName)
	return FayLib.IGC.Config.Shared[addonName]["_" .. keyName]
end)

-- fetch whether the shared cache has been fetched for the first time
addToAPITable("IsSharedReady", function()
	return FayLib.IGC.Config.SharedReady
end)

-- overwrite a kay with new data
addToAPITable("SetClientKey", function(addonName, keyName, newValue)
	FayLib.IGC.sharedDefineKey(addonName, keyName, newValue, "Client")

	-- run related hooks
	hook_Run("IGCConfigUpdate", addonName)
	hook_Run("IGCClientConfigUpdate", addonName)
end)

-- save configuration to disk
addToAPITable("SaveClientConfig", function(addonName, fileName, folderName)
	FayLib.IGC.sharedSaveConfig(addonName, fileName, folderName, "Client")
end)

-- load configuration from disk
addToAPITable("LoadClientConfig", function(addonName, fileName, folderName)
	FayLib.IGC.sharedLoadConfig(addonName, fileName, folderName, "Client")

	-- fire related hooks
	hook_Run("IGCConfigUpdate", addonName)
	hook_Run("IGCClientConfigUpdate", addonName)
end)

-- handles shared variable sync from server
net_Receive( "FAYLIB_IGC_SYNC", function( len )
	local addonName = net_ReadString()
	local sharedString = net_ReadString()
	FayLib.IGC.Config.Shared[addonName] = util_JSONToTable( sharedString )

	FayLib.IGC.colorFix("Shared", addonName)

	hook_Run("IGCConfigUpdate", addonName)
	hook_Run("IGCSharedConfigUpdate", addonName)
end )

-- handles first-time shared config sync during client lua startup
net_Receive( "FAYLIB_IGC_SYNCFIRST", function( len )
	local sharedString = net_ReadString()
	FayLib.IGC.Config.Shared = util_JSONToTable( sharedString )

	local outerKeyList = table_GetKeys(FayLib.IGC.Config.Shared)
	for _,addonName in ipairs(outerKeyList) do
		FayLib.IGC.colorFix("Shared", addonName)
	end

	FayLib.IGC.Config.SharedReady = true
	hook_Run("IGCSharedConfigReady")
end )

-- as soon as possible, start the first-time shared config sync request
hook_Add( "InitPostEntity", "FAYLIB_IGC_CLIENTINITSYNC", function()
	net_Start("FAYLIB_IGC_SYNCFIRST")
	net_SendToServer()
end )

return {modName, funcList}