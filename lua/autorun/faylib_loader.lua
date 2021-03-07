FayLib = FayLib || {}
FayLib.Backend = FayLib.Backend || {}

-- Basic Logger Function
function FayLib.Backend.Log(msg, warning)
	local newMSG = "[FayLib] "
	if warning then
		newMSG = newMSG.."(WARN) "
	end
	print(newMSG..msg)
end

-- Helper function that can be used to expose API functions to the public table
function FayLib.Backend.AddToAPI(modNme, funcName, functionCode)
	FayLib[modNme][funcName] = functionCode
end

FayLib.Backend.Log("Begin Load", false)

-- Helper functions to recursively add lua files, so I don't have to edit this file each time I add something
local function addFiles(modFolder, sPath)
	-- load lua files in folder based on name
	local files, directories = file.Find(modFolder..sPath.."*.lua", "LUA")
	if SERVER then
		for _, f in pairs(files) do
			if(string.find(f:lower(), "sv_")) then
				include(modFolder..sPath..f)
			elseif(string.find(f:lower(), "sh_")) then
				include(modFolder..sPath..f)
				AddCSLuaFile(modFolder..sPath..f)
			elseif(string.find(f:lower(), "cl_")) then
				AddCSLuaFile(modFolder..sPath..f)
			end
		end
	else
		for _, f in pairs(files) do
			include(modFolder..sPath..f)
		end
	end
	-- recursively search module directories
	files, directories = file.Find(modFolder..sPath.."*", "LUA")
	for _, f in pairs(directories) do
		FayLib.Backend.Log("Module Found: "..f, false)
		addFiles(modFolder, sPath..f.."/")
	end
end

-- Load all modules recursively
addFiles("faylib/", "")

FayLib.Backend.Log("Load Complete", false)