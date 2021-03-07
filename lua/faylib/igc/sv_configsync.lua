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

local modName = "IGC"
FayLib[modName] = FayLib[modName] || {}

local function addAPIFunction(funcName, functionCode)
	FayLib.Backend.AddToAPI(modName, funcName, functionCode)
end
-- END BOILERPLATE CODE

util.AddNetworkString( "FAYLIB_IGC_SYNC" )
util.AddNetworkString( "FAYLIB_IGC_SYNCFIRST" )

FayLib[modName]["Config"] = FayLib[modName]["Config"] || {}
FayLib[modName]["Config"]["Server"] = FayLib[modName]["Config"]["Server"] || {}
FayLib[modName]["Config"]["Shared"] = FayLib[modName]["Config"]["Shared"] || {}
FayLib[modName]["ConfigLookup"] = FayLib[modName]["ConfigLookup"] || {}

local allowedTypes = {"number", "string", "boolean", "nil", "Vector", "Angle", "Color", "table"}
local function canSetAsValue(value)
	if !table.HasValue( allowedTypes, type(value) ) then
		return false
	end
	
	return true
end

local function isNANOrINF(value)
	if type(value)=="number" then
		if value == (1/0) || value ~= value then
			return true
		end
	end
	
	return false
end

local function isStringBool(value)
	if(type(value) == "string") then
		return (value == "true" || value == "false")
	end
	
	return false
end

addAPIFunction("DefineKey", function(addonName, keyName, defaultValue, sharedMode)
	if sharedMode == nil then
		sharedMode = false
	end

	if !canSetAsValue(defaultValue) then
		FayLib.Backend.Log("IGC - An invalid value value being assigned to key \""..keyName.."\" ", true)
		return
	end
	
	if isNANOrINF(defaultValue) then
		FayLib.Backend.Log("IGC - A value being assigned to key \""..keyName.."\" was NaN or INF, so it was set to 0 instead", true)
		defaultValue = 0
	end
	
	if isStringBool(defaultValue) then
		FayLib.Backend.Log("IGC - A value being assigned to key \""..keyName.."\" was a string equal to \"true\" or \"false\", so it was set to the respective boolean value instead", true)
		if(defaultValue == "true") then
			defaultValue = true
		else
			defaultValue = false
		end
	end
	
	keyName = "_"..keyName
	
	FayLib[modName]["Config"]["Server"][addonName] = FayLib[modName]["Config"]["Server"][addonName] || {}
	FayLib[modName]["Config"]["Server"][addonName][keyName] = defaultValue
	FayLib[modName]["ConfigLookup"][addonName] = FayLib[modName]["ConfigLookup"][addonName] || {}
	FayLib[modName]["ConfigLookup"][addonName][keyName] = sharedMode
	if sharedMode then
		FayLib[modName]["Config"]["Shared"][addonName] = FayLib[modName]["Config"]["Shared"][addonName] || {}
		FayLib[modName]["Config"]["Shared"][addonName][keyName] = defaultValue
	end
	
	hook.Run("IGCConfigUpdate", addonName)
	hook.Run("IGCServerConfigUpdate", addonName)
	if sharedMode then
		hook.Run("IGCSharedConfigUpdate", addonName)
	end
end)

addAPIFunction("GetKey", function(addonName, keyName)
	return FayLib[modName]["Config"]["Server"][addonName]["_"..keyName]
end)

addAPIFunction("SetKey", function(addonName, keyName, newValue)
	if !canSetAsValue(newValue) then
		FayLib.Backend.Log("IGC - An invalid value was being assigned to key \""..keyName.."\", so the key could not be set", true)
		return
	end
	
	if isNANOrINF(newValue) then
		FayLib.Backend.Log("IGC - A value being assigned to key \""..keyName.."\" was NaN or INF, so it was set to 0 instead", true)
		newValue = 0
	end
	
	if isStringBool(newValue) then
		FayLib.Backend.Log("IGC - A value being assigned to key \""..keyName.."\" was a string equal to \"true\" or \"false\", so it was set to the respective boolean value instead", true)
		if(newValue == "true") then
			newValue = true
		else
			newValue = false
		end
	end
	
	keyName = "_"..keyName
	
	FayLib[modName]["Config"]["Server"][addonName][keyName] = newValue
	if FayLib[modName]["ConfigLookup"][addonName][keyName] then
		FayLib[modName]["Config"]["Shared"][addonName][keyName] = newValue
	end
	
	hook.Run("IGCConfigUpdate", addonName)
	hook.Run("IGCServerConfigUpdate", addonName)
	if sharedMode then
		hook.Run("IGCSharedConfigUpdate", addonName)
	end
end)

addAPIFunction("SyncShared", function(addonName, ply)
	local sharedString = util.TableToJSON( FayLib[modName]["Config"]["Shared"][addonName] )
	net.Start("FAYLIB_IGC_SYNC")
	net.WriteString(addonName)
	net.WriteString(sharedString)
	if ply == nil then
		net.Broadcast()
	else
		net.Send(ply)
	end
end)

addAPIFunction("SaveConfig", function(addonName, fileName, folderName)
	if folderName == nil then
		folderName = "faylib"
	end

	folderName = tostring(folderName)
	fileName = tostring(fileName)
	local saveString = util.TableToJSON( FayLib[modName]["Config"]["Server"][addonName] )
	file.CreateDir( folderName )
	file.Write( folderName.."/"..fileName..".json", saveString)
end)

addAPIFunction("LoadConfig", function(addonName, fileName, folderName)
	if folderName == nil then
		folderName = "faylib"
	end
	
	folderName = tostring(folderName)
	fileName = tostring(fileName)
	local loadStr = file.Read( folderName.."/"..fileName..".json", "DATA" )
	if loadStr == nil then
		FayLib.Backend.Log("IGC - A save file was not found when LoadConfig was invoked, so a new one will be created based off the default values", false)
		FayLib[modName]["SaveConfig"](addonName, fileName, folderName)
		return
	end
	
	FayLib[modName]["Config"]["Server"][addonName] = util.JSONToTable( loadStr )
	
	--add fix for "Colors will not have the color metatable" bug
	local keyList = table.GetKeys(FayLib[modName]["Config"]["Server"][addonName])
	for i=1,#keyList do
		if type(FayLib[modName]["Config"]["Server"][addonName][keyList[i]]) == "table" then
			local innerTable = FayLib[modName]["Config"]["Server"][addonName][keyList[i]]
			local innerKeyList = table.GetKeys(innerTable)
			if(#innerKeyList == 4 && innerTable.a ~= nil && innerTable.r ~= nil && innerTable.g ~= nil && innerTable.b ~= nil) then
				FayLib[modName]["Config"]["Server"][addonName][keyList[i]] = Color(innerTable.r, innerTable.g, innerTable.b, innerTable.a)
			end
		end
	end
	
	--copy any "shared" keys to the shared config table
	for i=1,#keyList do
		if FayLib[modName]["ConfigLookup"][addonName][keyList[i]] then
			FayLib[modName]["Config"]["Shared"][addonName][keyList[i]] = FayLib[modName]["Config"]["Server"][addonName][keyList[i]]
		end
	end
	
	FayLib[modName]["SyncShared"](addonName)
	hook.Run("IGCConfigUpdate", addonName)
	hook.Run("IGCServerConfigUpdate", addonName)
	hook.Run("IGCSharedConfigUpdate", addonName)
end)

net.Receive( "FAYLIB_IGC_SYNCFIRST", function( len, ply )
	local sharedString = util.TableToJSON( FayLib[modName]["Config"]["Shared"] )
	net.Start("FAYLIB_IGC_SYNCFIRST")
		net.WriteString(sharedString)
	net.Send(ply)
end )