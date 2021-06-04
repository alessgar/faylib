--[[

 ________  ___  ________  ________  _______   ________          ________  ________  ________  ___  __    _______  _________  ________      
|\   __  \|\  \|\   ____\|\   ____\|\  ___ \ |\   __  \        |\   __  \|\   __  \|\   ____\|\  \|\  \ |\  ___ \|\___   ___\\   ____\     
\ \  \|\ /\ \  \ \  \___|\ \  \___|\ \   __/|\ \  \|\  \       \ \  \|\  \ \  \|\  \ \  \___|\ \  \/  /|\ \   __/\|___ \  \_\ \  \___|_    
 \ \   __  \ \  \ \  \  __\ \  \  __\ \  \_|/_\ \   _  _\       \ \   ____\ \   __  \ \  \    \ \   ___  \ \  \_|/__  \ \  \ \ \_____  \   
  \ \  \|\  \ \  \ \  \|\  \ \  \|\  \ \  \_|\ \ \  \\  \|       \ \  \___|\ \  \ \  \ \  \____\ \  \\ \  \ \  \_|\ \  \ \  \ \|____|\  \  
   \ \_______\ \__\ \_______\ \_______\ \_______\ \__\\ _\        \ \__\    \ \__\ \__\ \_______\ \__\\ \__\ \_______\  \ \__\  ____\_\  \ 
    \|_______|\|__|\|_______|\|_______|\|_______|\|__|\|__|        \|__|     \|__|\|__|\|_______|\|__| \|__|\|_______|   \|__| |\_________\
                                                                                                                               \|_________|
                                                                                                                                           
A backend API designed to allow the transmission of tables and strings that are larger than 60KB.

Please see sv_bpackets.lua and cl_bpackets.lua for the respective server and client APIs!

]]--

local FayLib = FayLib

local table_HasValue = table.HasValue
local type = type
local util_JSONToTable = util.JSONToTable
local pairs = pairs
local table_GetKeys = table.GetKeys
local Color = Color
local net_Receive = net.Receive
local net_ReadBool = net.ReadBool
local net_ReadString = net.ReadString
local net_ReadInt = net.ReadInt
local net_Start = net.Start
local net_WriteString = net.WriteString
local net_WriteInt = net.WriteInt
local net_Send = SERVER && net.Send
local net_SendToServer = CLIENT && net.SendToServer
local tostring = tostring
local string_len = string.len
local math_ceil = math.ceil
local math_random = math.random
local string_sub = string.sub
local util_TableToJSON = util.TableToJSON
local os_time = os.time
local timer_Create = timer.Create
local net_WriteBool = net.WriteBool
local net_Broadcast = net.Broadcast

local modName = "BPackets"
local funcList = {}

local function addToAPITable(funcName, functionCode)
    funcList[funcName] = functionCode
end
-- END BOILERPLATE CODE

addToAPITable("Segments", {})
addToAPITable("IdentifierLookup", {})

addToAPITable("ReceivedSegments", {})
addToAPITable("SegmentCallbacks", {})

-- returns whether give value can be stored in config
local allowedTypes = {"number", "string", "boolean", "nil", "Vector", "Angle", "Color", "table"}
addToAPITable("canSetAsValue", function(value)
    if !table_HasValue( allowedTypes, type(value) ) then
        return false
    end

    return true
end)

-- returns whether value is NaN or INF
addToAPITable("isNANOrINF", function(value)
    if type(value) == "number" && (value == (1 / 0) || value != value) then
        return true
    end

    return false
end)

-- returns whether value is "true" or "false" or not
addToAPITable("isStringBool", function(value)
    if type(value) == "string" then
        return value == "true" || value == "false"
    end

    return false
end)

-- Uses all segments to piece the string/table back together, before calling the callback function
local function completeObject(identifier, segmentCount, netStr, isTable, ply)
    local finalString = ""

    -- piece string together
    for i = 1, segmentCount do
        finalString = finalString .. FayLib.BPackets.ReceivedSegments[identifier][i]
    end

    -- delete data that is no longer needed
    FayLib.BPackets.ReceivedSegments[identifier] = nil

    local finalObj = finalString

    -- turn string back into table, if needed
    if isTable then
        finalObj = {}
        FayLib.BPackets.receiveTableHelper(finalObj, util_JSONToTable(finalString))
    end

    -- fire callback
    FayLib.BPackets.SegmentCallbacks[netStr](finalObj, ply)
end

--[[

    READING-BASED FUNCTIONALITY

]]--

-- recursive function to fix data that may have been broken
addToAPITable("receiveTableHelper", function(root, inputTable)
    for key,value in pairs(inputTable) do
        if type(value) == "table" then
            root[key] = {}
            local innerKeyList = table_GetKeys(value)
            if #innerKeyList == 4 && value.a != nil && value.r != nil && value.g != nil && value.b != nil then
                root[key] = Color(value.r, value.g, value.b, value.a)
            else
                FayLib.BPackets.receiveTableHelper(root[key], value)
            end
        else
            root[key] = value
        end
    end
end)

-- reused code between both sv and cl APIs, used to request next segment of table/string
addToAPITable("networkReceiveFunc", function(identifier, segmentNum, ply)
    local netStr = FayLib.BPackets.IdentifierLookup[identifier].NetStr
    local segmentCount = FayLib.BPackets.IdentifierLookup[identifier].SegmentCount
    local sentType = FayLib.BPackets.IdentifierLookup[identifier].Type

    net_Start( netStr )
        net_WriteBool(false)
        net_WriteString(sentType)
        net_WriteString(identifier)
        net_WriteInt(segmentCount, 8)
        net_WriteInt(segmentNum, 8)
        net_WriteString(FayLib.BPackets.Segments[identifier][segmentNum])
    if SERVER then net_Send(ply) else net_SendToServer() end
end)

-- The equivalent of net.Receive, but for our large tables.
addToAPITable("SetupReceiver", function(netStr, callback)
    FayLib.BPackets.SegmentCallbacks[netStr] = callback

    net_Receive(netStr, function(len, ply)
        local mode = net_ReadBool()
        local sentType = net_ReadString()
        local identifier = net_ReadString()
        local segmentCount = net_ReadInt(8)

        -- determine whether handsake or data chunk message
        if mode then
            FayLib.BPackets.ReceivedSegments[identifier] = {}

            -- request first data chunk message
            if SERVER then net_Start( "BPACKETS_CLIENTREQ" ) else net_Start( "BPACKETS_SERVREQ" ) end
                net_WriteString(identifier)
                net_WriteInt(1, 8)
            if SERVER then net_Send( ply ) else net_SendToServer() end
        else
            -- store data chunk for concatenation later
            local segmentNum = net_ReadInt(8)
            FayLib.BPackets.ReceivedSegments[identifier][segmentNum] = net_ReadString()

            -- check if all chunks received
            if #table_GetKeys(FayLib.BPackets.ReceivedSegments[identifier]) == segmentCount then
                -- if true, concatenate and fire callback
                if sentType == "Table" then
                    completeObject(identifier, segmentCount, netStr, true, ply)
                elseif sentType == "String" then
                    completeObject(identifier, segmentCount, netStr, false, ply)
                end
            else
                -- if not, request next chunk
                if SERVER then net_Start( "BPACKETS_CLIENTREQ" ) else net_Start( "BPACKETS_SERVREQ" ) end
                    net_WriteString(identifier)
                    net_WriteInt(segmentNum + 1, 8)
                if SERVER then net_Send( ply ) else net_SendToServer() end
            end
        end
    end)
end)

--[[

    WRITING-BASED FUNCTIONALITY

]]--

-- Send the handshake packet, which informs the other end (assuming receiver is set up) about a new table/string incoming
addToAPITable("SendHandshakePacket", function(netStr, objType, localIdentifier, segmentCount, broadcast, ply)
    net_Start( netStr )
        net_WriteBool(true)
        net_WriteString("Table")
        net_WriteString(localIdentifier)
        net_WriteInt(segmentCount, 8)
    if SERVER then
        if broadcast then
            net_Broadcast()
        else
            net_Send(ply)
        end
    else
        net_SendToServer()
    end
end)

-- recursive function to clean data and make a deep copy
addToAPITable("writeTableHelper", function(root, inputTable)
    for key,value in pairs(inputTable) do
        if type(value) == "table" then -- recursion
            root[key] = {}
            FayLib.BPackets.writeTableHelper(root[key], value)
        elseif FayLib.BPackets.canSetAsValue(value) && !FayLib.BPackets.isNANOrINF(v) then -- check for valid values for networked table
            if FayLib.BPackets.isStringBool(value) then -- check if string representaiton of bool (must be converted)
                FayLib.Backend.Log("BPackets - A value (" .. tostring(key) .. " , " .. tostring(value) .. ") was a string equal to \"true\" or \"false\", so it was set to the respective boolean value instead due to techinical limits.", true)

                if value == "true" then
                    value = true
                else
                    value = false
                end
            end

            root[key] = value
        else
            FayLib.Backend.Log("BPackets - A value (" .. tostring(key) .. " , " .. tostring(value) .. ") is unable to be written to tables due to technical limits. It will be removed from the final table.", true)
        end
    end
end)

-- prepares a given string for transmission
addToAPITable("stringSetup", function(inputString)
    -- determine size of string
    local tableSize = string_len( inputString ) + 1

    -- begin to split table string as needed
    local segmentCount = math_ceil(tableSize / 60000)

    local localIdentifier = tostring(math_random( 1, 1000000 ))

    FayLib.BPackets.Segments[localIdentifier] = {}
    for i = 1, segmentCount do
        FayLib.BPackets.Segments[localIdentifier][i] = string_sub(inputString, 0, 60000)
        inputString = string_sub(inputString, 60001)
    end

    return localIdentifier, segmentCount
end)

-- converts a table into a string to prepare it for transmission
addToAPITable("tableSetup", function(inputTable)
    local sendingTable = {}
    FayLib.BPackets.writeTableHelper(sendingTable, inputTable)

    -- convert table to string
    local tableString = util_TableToJSON( sendingTable )

    return FayLib.BPackets.stringSetup(tableString)
end)

-- save identifying information about an identifier for later
addToAPITable("setupLookup", function(localIdentifier, segmentCount, netStr, sentType)
    FayLib.BPackets.IdentifierLookup[localIdentifier] = {
        NetStr = netStr,
        SegmentCount = segmentCount,
        Type = sentType,
        CreationTime = os_time(),
    }
end)

-- every minute, remove any leftover packets that are more than 10 minutes old for security/memory saving
timer_Create( "BPACKETS_CLEANUP", 60, 0, function()
    local curTime = os_time()
    for identifier,identifierInfo in pairs(FayLib.BPackets.IdentifierLookup) do
        if curTime - identifierInfo.CreationTime > 600 then
            FayLib.BPackets.IdentifierLookup[identifier] = nil
            FayLib.BPackets.Segments[identifier] = nil
        end
    end
end)

return {modName, funcList}