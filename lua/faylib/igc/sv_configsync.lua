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

NOTE: This is the Server API! Check cl_configsync.lua for the Client API.

NOTE 2: The only difference between server-side and shared variables is that shared ones are networked to the client.
Keep in mind that they are treated as one the same on the server end, so the shared keys will always be equal to the server-side equivalent key.

NOTE 3: The following values/types have been tested with and can be saved properly into a configuration - numbers, strings, booleans, nil, Vectors, Angles, Colors, tables

NOTE 4: any NaN or INF values will be turned into a 0 to avoid a bug that causes broken JSON to output (according to the gmod wiki). You will get a warning in the console when this happens.

FUNCTIONS:

void IGC:DefineKey(string addonName, string keyName, any defaultValue, boolean sharedMode=false)
 - Defines a server-side/shared configuration key for the specified addon, as well as the value it will take if no save is loaded
 - if sharedMode is true, the key will be networked to the client

any IGC:GetKey(string addonName, string keyName)
 - Attempts to get the value of a server-side/shared configuration variable for the given addon
 - returns nil if not found

void IGC:SetKey(string addonName, string keyName, any newValue)
 - Sets an existing server-side/shared configuration key for the specified addon to the specified value

void IGC:SyncShared(string addonName, Player ply=nil)
 - Will sync the shared configuration for the given addon on the client of the specified player, if provided
 - If a player is not provided, then all players will have their shared configuration for the addon synced
 - To prevent net message spam, this function is not run inside IGC:SetKey and IGC:DefineKey. It is up to you to determine when a sync is necessary after defining/setting keys.
 - It is run automatically inside IGC:LoadClientConfig

void IGC:SaveConfig(string addonName, fileName, folderName="faylib")
 - Saves a copy of the server-side/shared configuration for the specified addon onto the disk using the provided folder and fileName

void IGC:LoadConfig(string addonName, fileName, folderName="faylib")
 - Attempts to load a saved server-side/shared configuration for the given addon from the provided folder and fileName
 - saves configuration of default values (from IGC:DefineKey) if the file is not found
 - Automatically syncs shared configuration of addon with all connected players if configuration file is successfully loaded
 - If a previously declared key is not present in loaded config, the default value of that key will be inserted into the config table

HOOKS:

IGCConfigUpdate(string addonName)
 - Called when server-side or shared configuration value(s) are updated
 - provides the addon name for the configuration that was updated

IGCServerConfigUpdate(string addonName)
 - Called when server-side configuration value(s) are updated
 - provides the addon name for the configuration that was updated

IGCSharedConfigUpdate(string addonName)
 - Called when shared configuration value(s) are updated
 - provides the addon name for the configuration that was updated

]]--

local FayLib = FayLib

local util_AddNetworkString = SERVER && util.AddNetworkString
local hook_Run = hook.Run
local util_TableToJSON = util.TableToJSON
local net_Start = net.Start
local net_WriteString = net.WriteString
local net_Broadcast = SERVER && net.Broadcast
local net_Send = SERVER && net.Send
local net_Receive = net.Receive
local table_GetKeys = table.GetKeys

local modName = "IGC"
local funcList = {}

local function addToAPITable(funcName, functionCode)
	funcList[funcName] = functionCode
end
-- END BOILERPLATE CODE

util_AddNetworkString( "FAYLIB_IGC_SYNC" )
util_AddNetworkString( "FAYLIB_IGC_SYNCFIRST" )

local newCFG = {}
newCFG.Server = {}
newCFG.Shared = {}
addToAPITable("Config", newCFG)
addToAPITable("ConfigLookup", {})

-- defines a key in the given addons config
addToAPITable("DefineKey", function(addonName, keyName, defaultValue, sharedMode)
	if sharedMode == nil then
		sharedMode = false
	end

	keyName = FayLib.IGC.sharedDefineKey(addonName, keyName, defaultValue, "Server")

	FayLib.IGC.ConfigLookup[addonName] = FayLib.IGC.ConfigLookup[addonName] || {}
	FayLib.IGC.ConfigLookup[addonName][keyName] = sharedMode
	if sharedMode then
		FayLib.IGC.Config.Shared[addonName] = FayLib.IGC.Config.Shared[addonName] || {}
		FayLib.IGC.Config.Shared[addonName][keyName] = defaultValue
	end

	-- run related hooks
	hook_Run("IGCConfigUpdate", addonName)
	hook_Run("IGCServerConfigUpdate", addonName)
	if sharedMode then
		hook_Run("IGCSharedConfigUpdate", addonName)
	end
end)

-- gets the current state of the key in the given addon
addToAPITable("GetKey", function(addonName, keyName)
	return FayLib.IGC.Config.Server[addonName]["_" .. keyName]
end)

-- overwrite a kay with new data
addToAPITable("SetKey", function(addonName, keyName, newValue)
	FayLib.IGC.sharedDefineKey(addonName, keyName, newValue, "Server")

	keyName = "_" .. keyName

	if FayLib.IGC.ConfigLookup[addonName][keyName] then
		FayLib.IGC.Config.Shared[addonName][keyName] = newValue
	end

	-- run related hooks
	hook_Run("IGCConfigUpdate", addonName)
	hook_Run("IGCServerConfigUpdate", addonName)
	if sharedMode then
		hook_Run("IGCSharedConfigUpdate", addonName)
	end
end)

-- sync any updated shared variables to the client
addToAPITable("SyncShared", function(addonName, ply)
	local sharedString = util_TableToJSON( FayLib.IGC.Config.Shared[addonName] )
	net_Start("FAYLIB_IGC_SYNC")
	net_WriteString(addonName)
	net_WriteString(sharedString)
	if ply == nil then
		net_Broadcast()
	else
		net_Send(ply)
	end
end)

-- save configuration to disk
addToAPITable("SaveConfig", function(addonName, fileName, folderName)
	FayLib.IGC.sharedSaveConfig(addonName, fileName, folderName, "Server")
end)

-- load configuration from disk
addToAPITable("LoadConfig", function(addonName, fileName, folderName)
	FayLib.IGC.sharedLoadConfig(addonName, fileName, folderName, "Server")

	-- copy any "shared" keys to the shared config table
	local keyList = table_GetKeys(FayLib.IGC.Config.Server[addonName])

	for i = 1, #keyList do
		if FayLib.IGC.ConfigLookup[addonName][keyList[i]] then
			FayLib.IGC.Config.Shared[addonName][keyList[i]] = FayLib.IGC.Config.Server[addonName][keyList[i]]
		end
	end

	-- sync new shared table with client and fire related hooks
	FayLib.IGC.SyncShared(addonName)
	hook_Run("IGCConfigUpdate", addonName)
	hook_Run("IGCServerConfigUpdate", addonName)
	hook_Run("IGCSharedConfigUpdate", addonName)
end)

-- when a client requests a first-time shared config sync, send off the entire shared table instead of the normal single addon table
net_Receive( "FAYLIB_IGC_SYNCFIRST", function( len, ply )
	local sharedString = util_TableToJSON( FayLib.IGC.Config.Shared )
	net_Start("FAYLIB_IGC_SYNCFIRST")
		net_WriteString(sharedString)
	net_Send(ply)
end )

return {modName, funcList}