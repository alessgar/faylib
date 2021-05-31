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

Note: To see the client and server API, please see the respective cl_configsync and sv_configsync files!

]]--

local FayLib = FayLib

local table_HasValue = table_HasValue
local type = type
local table_GetKeys = table_GetKeys
local Color = Color
local tostring = tostring
local file_Read = file_Read
local util_JSONToTable = util_JSONToTable
local ipairs = ipairs
local pairs = pairs
local util_TableToJSON = util_TableToJSON
local file_CreateDir = file_CreateDir
local file_Write = file_Write

local modName = "IGC"
FayLib[modName] = FayLib[modName] || {}

-- returns whether give value can be stored in config
local allowedTypes = {"number", "string", "boolean", "nil", "Vector", "Angle", "Color", "table"}
FayLib[modName].canSetAsValue = function(value)
    if !table_HasValue( allowedTypes, type(value) ) then
        return false
    end

    return true
end

-- returns whether value is NaN or INF
FayLib[modName].isNANOrINF = function(value)
    if type(value) == "number" && (value == (1 / 0) || value != value) then
        return true
    end

    return false
end

-- returns whether value is "true" or "false" or not
FayLib[modName].isStringBool = function(value)
    if type(value) == "string" then
        return value == "true" || value == "false"
    end

    return false
end

-- add fix for "Colors will not have the color metatable" bug
FayLib[modName].colorFix = function(realm, addonName)
    local keyList = table_GetKeys(FayLib[modName]["Config"][realm][addonName])
    for i = 1, #keyList do
        if type(FayLib[modName]["Config"][realm][addonName][keyList[i]]) == "table" then
            local innerTable = FayLib[modName]["Config"][realm][addonName][keyList[i]]
            local innerKeyList = table_GetKeys(innerTable)
            if #innerKeyList == 4 && innerTable.a != nil && innerTable.r != nil && innerTable.g != nil && innerTable.b != nil then
                FayLib[modName]["Config"][realm][addonName][keyList[i]] = Color(innerTable.r, innerTable.g, innerTable.b, innerTable.a)
            end
        end
    end
end

-- Shared code for loading configuration files
FayLib[modName].sharedLoadConfig = function(addonName, fileName, folderName, realm)
    -- add default variable if folder name not given
    if folderName == nil then
        folderName = "faylib"
    end

    -- load provided config file
    folderName = tostring(folderName)
    fileName = tostring(fileName)
    local loadStr = file_Read( folderName .. "/" .. fileName .. ".json", "DATA" )
    if loadStr == nil then
        --FayLib.Backend.Log("IGC - A save file was not found when LoadConfig was invoked, so a new one will be created based off the default values", false)
        if SERVER then
            FayLib[modName]["SaveConfig"](addonName, fileName, folderName)
        else
            FayLib[modName]["SaveClientConfig"](addonName, fileName, folderName)
        end

        return
    end

    -- turn config into table format and check for declared config variables that are missing from file
    local fileTable = util_JSONToTable( loadStr )
    local fileKeyList = table_GetKeys(fileTable)
    local verifyKeyList = table_GetKeys(FayLib[modName]["Config"][realm][addonName])
    local notFoundVars = {}
    for _,key in ipairs(verifyKeyList) do
        if !table_HasValue(fileKeyList, key) then
            notFoundVars[key] = FayLib[modName]["Config"][realm][addonName][key]
        end
    end

    -- load config into provided addon table
    FayLib[modName]["Config"][realm][addonName] = fileTable

    -- add missing variables from before
    for key,val in pairs(notFoundVars) do
        FayLib[modName]["Config"][realm][addonName][key] = val
    end

    -- add fix for "Colors will not have the color metatable" bug
    FayLib[modName].colorFix(realm, addonName)
end

-- Shared code for saving configuration files
FayLib[modName].sharedSaveConfig = function(addonName, fileName, folderName, realm)
    if folderName == nil then
        folderName = "faylib"
    end

    folderName = tostring(folderName)
    fileName = tostring(fileName)

    local saveString = util_TableToJSON( FayLib[modName]["Config"][realm][addonName] )
    file_CreateDir( folderName )
    file_Write( folderName .. "/" .. fileName .. ".json", saveString)
end

-- Shared code for defining/setting config keys
FayLib[modName].sharedDefineKey = function(addonName, keyName, defaultValue, realm)
    -- make sure the value type is supported
    if !FayLib[modName].canSetAsValue(defaultValue) then
        FayLib.Backend.Log("IGC - An invalid value value being assigned to key \"" .. keyName .. "\" ", true)
        return
    end

    -- values cannot be NAN or INF
    if FayLib[modName].isNANOrINF(defaultValue) then
        FayLib.Backend.Log("IGC - A value being assigned to key \"" .. keyName .. "\" was NaN or INF, so it was set to 0 instead", true)
        defaultValue = 0
    end

    -- string representations of booleans must be converted to booleans
    if FayLib[modName].isStringBool(defaultValue) then
        FayLib.Backend.Log("IGC - A value being assigned to key \"" .. keyName .. "\" was a string equal to \"true\" or \"false\", so it was set to the respective boolean value instead", true)
        if defaultValue == "true" then
            defaultValue = true
        else
            defaultValue = false
        end
    end

    keyName = "_" .. keyName

    -- apply new value to config
    FayLib[modName]["Config"][realm][addonName] = FayLib[modName]["Config"][realm][addonName] || {}
    FayLib[modName]["Config"][realm][addonName][keyName] = defaultValue
end