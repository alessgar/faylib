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

NOTE: This is the Client API! Check sv_bpackets.lua for the Server API. 

NOTE 2: Just because this will allow you to send larger files DOES NOT mean it is fast! On a peer-to-peer server, I was averaging ~44KB/sec.
It will likely be slower over the public internet, so do try to minimize the size of what you send.

NOTE 3: Just like net messages, these will not protect you from exploiters. It is up to you to design your networking in a way that
will minimize the effects of those maliciously injecting clientside lua.

BENCHMARKS: (peer to peer, meaning best conditions)
  - 5MB (maximum size allowed by BPackets, ~78.1x net message max)
    - server -> client : 35s
    - client -> server : 73s
  - 1MB (~15.6x net message max)
    - server -> client : 4s
    - client -> server : 15s
  - 500KB (~7.81x net message max)
    - server -> client : 2s
    - client -> server : 8s
  - 100KB (~1.56x net message max)
    - server -> client : 1s
    - client -> server : 1s

FUNCTIONS:

void BPackets:SendTableToServer(string netStr, table inputTable)
 - Will network the given table to the server, using the provided network string
 - Network strings must be defined and provided by the developer

void BPackets:SendStringToServer(string netStr, string inputString)
 - Will network the given string to the server, using the provided network string
 - Network strings must be defined and provided by the developer

void BPackets:SetupReceiver(string netStr, function callback)
 - When a given network string receives a string/table, the given callback will be called with the string/table

]]--

local FayLib = FayLib

local net_Receive = net.Receive
local net_ReadString = net.ReadString
local net_ReadInt = net.ReadInt

local modName = "BPackets"
FayLib[modName] = FayLib[modName] || {}

local function addAPIFunction(funcName, functionCode)
    FayLib.Backend.AddToAPI(modName, funcName, functionCode)
end
-- END BOILERPLATE CODE

--[[

    WRITING-BASED FUNCTIONALITY

]]--

-- send table to server
addAPIFunction("SendTableToServer", function(netStr, inputTable)
    -- clean the table
    local localIdentifier, segmentCount = FayLib[modName].tableSetup(inputTable)

    -- size limit of 5MB
    if segmentCount > 83 then
        FayLib.Backend.Log("BPackets - The string you were trying to send exceeds maximum size limits (5MB). The string will not be sent.", true)
    end

    FayLib[modName].setupLookup(localIdentifier, segmentCount, netStr, "Table")

    -- send initial handshake packet
    FayLib[modName].SendHandshakePacket(netStr, "Table", localIdentifier, segmentCount)
end)

-- send string to server
addAPIFunction("SendStringToServer", function(netStr, inputString)
    -- clean the string
    local localIdentifier, segmentCount = FayLib[modName].stringSetup(inputString)

    -- size limit of 5MB
    if segmentCount > 83 then
        FayLib.Backend.Log("BPackets - The string you were trying to send exceeds maximum size limits (5MB). The string will not be sent.", true)
    end

    FayLib[modName].setupLookup(localIdentifier, segmentCount, netStr, "String")

    -- send initial handshake packet
    FayLib[modName].SendHandshakePacket(netStr, "String", localIdentifier, segmentCount)
end)

-- handle incoming packets
net_Receive("BPACKETS_CLIENTREQ", function(len)
    local identifier = net_ReadString()
    local segmentNum = net_ReadInt(8)

    FayLib[modName].networkReceiveFunc(identifier, segmentNum)
end)