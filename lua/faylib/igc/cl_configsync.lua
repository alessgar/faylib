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

local modName = "IGC"
FayLib[modName] = FayLib[modName] || {}

local function addAPIFunction(funcName, functionCode)
	FayLib.Backend.AddToAPI(modName, funcName, functionCode)
end
-- END BOILERPLATE CODE

FayLib[modName]["Config"] = FayLib[modName]["Config"] || {}
FayLib[modName]["Config"]["Client"] = FayLib[modName]["Config"]["Client"] || {}
FayLib[modName]["Config"]["Shared"] = FayLib[modName]["Config"]["Shared"] || {}
FayLib[modName]["Config"]["SharedReady"] = FayLib[modName]["Config"]["SharedReady"] || false

-- returns whether give value can be stored in config
local allowedTypes = {"number", "string", "boolean", "nil", "Vector", "Angle", "Color", "table"}
local function canSetAsValue(value)
	if !table.HasValue( allowedTypes, type(value) ) then
		return false
	end
	
	return true
end

-- returns whether value is NaN or INF
local function isNANOrINF(value)
	if type(value)=="number" then
		if value == (1/0) || value ~= value then
			return true
		end
	end
	
	return false
end

-- returns whether value is "true" or "false" or not
local function isStringBool(value)
	if(type(value) == "string") then
		return (value == "true" || value == "false")
	end
	
	return false
end

addAPIFunction("DefineClientKey", function(addonName, keyName, defaultValue)
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
	
	FayLib[modName]["Config"]["Client"][addonName] = FayLib[modName]["Config"]["Client"][addonName] || {}
	FayLib[modName]["Config"]["Client"][addonName][keyName] = defaultValue
	
	hook.Run("IGCConfigUpdate", addonName)
	hook.Run("IGCClientConfigUpdate", addonName)
end)

addAPIFunction("GetClientKey", function(addonName, keyName)
	return FayLib[modName]["Config"]["Client"][addonName]["_"..keyName]
end)

addAPIFunction("GetSharedKey", function(addonName, keyName)
	return FayLib[modName]["Config"]["Shared"][addonName]["_"..keyName]
end)

addAPIFunction("IsSharedReady", function() 
	return FayLib[modName]["Config"]["SharedReady"]
end)

addAPIFunction("SetClientKey", function(addonName, keyName, newValue)
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
	
	FayLib[modName]["Config"]["Client"][addonName][keyName] = newValue
	
	hook.Run("IGCConfigUpdate", addonName)
	hook.Run("IGCClientConfigUpdate", addonName)
end)

addAPIFunction("SaveClientConfig", function(addonName, fileName, folderName)
	if folderName == nil then
		folderName = "faylib"
	end

	folderName = tostring(folderName)
	fileName = tostring(fileName)
	local saveString = util.TableToJSON( FayLib[modName]["Config"]["Client"][addonName] )
	file.CreateDir( folderName )
	file.Write( folderName.."/"..fileName..".json", saveString)
end)

addAPIFunction("LoadClientConfig", function(addonName, fileName, folderName)
	-- add default variable if folder name not given
	if folderName == nil then
		folderName = "faylib"
	end
	
	-- load provided config file
	folderName = tostring(folderName)
	fileName = tostring(fileName)
	local loadStr = file.Read( folderName.."/"..fileName..".json", "DATA" )
	if loadStr == nil then
		--FayLib.Backend.Log("IGC - A save file was not found when LoadConfig was invoked, so a new one will be created based off the default values", false)
		FayLib[modName]["SaveClientConfig"](addonName, fileName, folderName)
		return
	end
	
	-- turn config into table format and check for declared config variables that are missing from file
	local fileTable = util.JSONToTable( loadStr )
	local fileKeyList = table.GetKeys(fileTable)
	local verifyKeyList = table.GetKeys(FayLib[modName]["Config"]["Client"][addonName])
	local notFoundVars = {}
	for _,key in ipairs(verifyKeyList) do
		if !table.HasValue(fileKeyList, key) then
			notFoundVars[key] = FayLib[modName]["Config"]["Client"][addonName][key]
		end
	end
	
	-- load config into provided addon table
	FayLib[modName]["Config"]["Client"][addonName] = fileTable
	
	-- add missing variables from before
	for key,val in pairs(notFoundVars) do
		FayLib[modName]["Config"]["Client"][addonName][key] = val
		print("Big Chungus Client: "..key)
	end
	
	-- add fix for "Colors will not have the color metatable" bug
	local keyList = table.GetKeys(FayLib[modName]["Config"]["Client"][addonName])
	for i=1,#keyList do
		if type(FayLib[modName]["Config"]["Client"][addonName][keyList[i]]) == "table" then
			local innerTable = FayLib[modName]["Config"]["Client"][addonName][keyList[i]]
			local innerKeyList = table.GetKeys(innerTable)
			if(#innerKeyList == 4 && innerTable.a ~= nil && innerTable.r ~= nil && innerTable.g ~= nil && innerTable.b ~= nil) then
				FayLib[modName]["Config"]["Client"][addonName][keyList[i]] = Color(innerTable.r, innerTable.g, innerTable.b, innerTable.a)
			end
		end
	end
	
	-- fire related hooks
	hook.Run("IGCConfigUpdate", addonName)
	hook.Run("IGCClientConfigUpdate", addonName)
end)

-- handles shared variable sync from server
net.Receive( "FAYLIB_IGC_SYNC", function( len )
	local addonName = net.ReadString()
	local sharedString = net.ReadString()
	FayLib[modName]["Config"]["Shared"][addonName] = util.JSONToTable( sharedString )
	
	--add fix for "Colors will not have the color metatable" bug
	local keyList = table.GetKeys(FayLib[modName]["Config"]["Shared"][addonName])
	for i=1,#keyList do
		if type(FayLib[modName]["Config"]["Shared"][addonName][keyList[i]]) == "table" then
			local innerTable = FayLib[modName]["Config"]["Shared"][addonName][keyList[i]]
			local innerKeyList = table.GetKeys(innerTable)
			if(#innerKeyList == 4 && innerTable.a ~= nil && innerTable.r ~= nil && innerTable.g ~= nil && innerTable.b ~= nil) then
				FayLib[modName]["Config"]["Shared"][addonName][keyList[i]] = Color(innerTable.r, innerTable.g, innerTable.b, innerTable.a)
			end
		end
	end
	
	hook.Run("IGCConfigUpdate", addonName)
	hook.Run("IGCSharedConfigUpdate", addonName)
end )

-- handles first-time shared config sync during client lua startup
net.Receive( "FAYLIB_IGC_SYNCFIRST", function( len )
	local sharedString = net.ReadString()
	FayLib[modName]["Config"]["Shared"] = util.JSONToTable( sharedString )
	
	--add fix for "Colors will not have the color metatable" bug
	local outerKeyList = table.GetKeys(FayLib[modName]["Config"]["Shared"])
	for _,addonName in ipairs(outerKeyList) do
		local keyList = table.GetKeys(FayLib[modName]["Config"]["Shared"][addonName])
		for i=1,#keyList do
			if type(FayLib[modName]["Config"]["Shared"][addonName][keyList[i]]) == "table" then
				local innerTable = FayLib[modName]["Config"]["Shared"][addonName][keyList[i]]
				local innerKeyList = table.GetKeys(innerTable)
				if(#innerKeyList == 4 && innerTable.a ~= nil && innerTable.r ~= nil && innerTable.g ~= nil && innerTable.b ~= nil) then
					FayLib[modName]["Config"]["Shared"][addonName][keyList[i]] = Color(innerTable.r, innerTable.g, innerTable.b, innerTable.a)
				end
			end
		end
	end
	
	FayLib[modName]["Config"]["SharedReady"] = true
	hook.Run("IGCSharedConfigReady")
end )

-- as soon as possible, start the first-time shared config sync request
hook.Add( "InitPostEntity", "FAYLIB_IGC_CLIENTINITSYNC", function()
	net.Start("FAYLIB_IGC_SYNCFIRST")
	net.SendToServer()
end )