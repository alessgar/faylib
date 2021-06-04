--[[
	Fay's Library
	version 1.0.0
]]--

FayLib = FayLib || {}
FayLib.Backend = FayLib.Backend || {}

-- Basic Logger Function
function FayLib.Backend.Log(msg, warning)
	local newMSG = "[FayLib] "
	if warning then
		newMSG = newMSG .. "(WARN) "
	end
	print(newMSG .. msg)
end

-- Helper function that can be used to expose API functions to the public table
local function addToAPI(moduleInfo)
	local modName = moduleInfo[1]
	local funcList = moduleInfo[2]
	FayLib[modName] = FayLib[modName] || {}

	for funcName, functionCode in pairs(funcList) do
		FayLib[modName][funcName] = functionCode
	end
end

FayLib.Backend.Log("Begin Load", false)

-- Helper functions to recursively add lua files, so I don't have to edit this file each time I add something
local function addFiles(modFolder, sPath)
	-- load lua files in folder based on name
	local files, directories = file.Find(modFolder .. sPath .. "*.lua", "LUA")
	if SERVER then
		for _, f in pairs(files) do
			if string.find(f:lower(), "sv_") then
				addToAPI( include(modFolder .. sPath .. f) )
			elseif string.find(f:lower(), "sh_") then
				addToAPI( include(modFolder .. sPath .. f) )
				AddCSLuaFile(modFolder .. sPath .. f)
			elseif string.find(f:lower(), "cl_") then
				AddCSLuaFile(modFolder .. sPath .. f)
			end
		end
	else
		for _, f in pairs(files) do
			addToAPI( include(modFolder .. sPath .. f) )
		end
	end
	-- recursively search module directories
	files, directories = file.Find(modFolder .. sPath .. "*", "LUA")
	for _, f in pairs(directories) do
		FayLib.Backend.Log("Module Found: " .. f, false)
		addFiles(modFolder, sPath .. f .. "/")
	end
end

-- Load all modules recursively
addFiles("faylib/", "")

FayLib.Backend.Log("Load Complete", false)