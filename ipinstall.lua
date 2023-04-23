--IPInstaller - Internet Program Installer
-- by googer (Def-Try), 23.04.23

--BASE VARIABLES
--[[
Files list
format: 
{url, tmpdir, fileinstalldir}
note that install dir is not real installation path of file. file will e installed to installdir + tmpdir + fileinstalldir
 eg:
 file {"/some/url", "/file-name"}
 installdir = "/usr"
 resulf: file will be installed to /usr/file-name
also, if url starts with "!", it will be interpreted as standalone url.
 eg:
 files {"!https://example.com/file-name", "/bin/file-name"}, {"/other-file-name", "/lib/file-name"}
 baseurl = "https://my-cool-git-host.scam"
 result: /bin/file-name will be downloaded from https://example.com/file-name,
         /lib/file-name will be downloaded from https://my-cool-git-host.scam/other-file-name
]]
local files = {
}

--URL of program basic repository.
--leave this blank if you ade downloading files from different sources
local baseurl = "-"

local tmpdir = "/tmp" -- temp. dir for files downloads. will be deleted in case of fail and after install
local installdir = "/usr" -- basic installation directory. see also: files

local PROGRAM_NAME = "-" -- Name of your program
local PROGRAM_DESCRIPTION = "-"
local INSTALLER_NAME = "IPInstaller - Internet Program Installer" -- name of your installer program
local INSTALLER_DESCRIPTION = "This is just a dummy installer program that does nothing" -- description of your installer program

--END BASE VARIABLES

local component = require("component")
local shell = require("shell")
local fs = require("filesystem")
local internet = require("internet")
local process = require("process")

if not component.isAvailable("internet") then
  io.stderr:write("This program requires an internet card to run.")
  return
end

local args, options = shell.parse(...)
options.q = options.q or options.Q
options.h = options.h or options.help

if options.h or #args ~= 1 then
	local seg = fs.segments(shell.resolve(process.info().path))
	io.write(INSTALLER_NAME.."\n")
	io.write(INSTALLER_DESCRIPTION.."\n\n")
  io.write("Usage: "..seg[#seg].." [-qQ] <action...>\n")
  io.write(" -q: Quiet mode - no status messages.\n")
  io.write(" -Q: Superquiet mode - no error messages.\n")
  io.write("Actions:\n")
  io.write("  install: Install program to your PC\n")
  io.write("  uninstall: Uninstall program from your PC\n")
  io.write("  info: Get info about this program")
  return
end

if args[1] == "info" then
	io.write(PROGRAM_NAME.."\n")
	io.write(PROGRAM_DESCRIPTION)
	return
end

if args[1] == "uninstall" then
	for _,file in pairs(files) do
		if not options.q and fs.remove(installdir..file[2]) then
			print("Deleted file "..installdir..file[2])
		end
	end
	if not options.q then
		print("Successfully uninstalled "..PROGRAM_NAME)
	end
	return
end

if not options.q then
	print("Please wait, while "..INSTALLER_NAME.." is downloading program files...")
end

local function download(url, filename)
	local f
	local result, response = pcall(internet.request, url, nil, {["user-agent"]="Wget/OpenComputers"})
	if result then
	  local result, reason = pcall(function()
	    for chunk in response do
	      if not f then
	        f, reason = io.open(filename, "wb")
	        if not f then
	        	if not options.Q then
	        		io.stderr:write("Failed opening file for writing: "..reason)
	        	end
	        	return nil, reason
	        end
	      end
	      f:write(chunk)
	    end
	  end)
	  if not result then
	    if f then
	      f:close()
	      fs.remove(filename)
	    end
	    if not options.Q then
	    	io.stderr:write("HTTP request failed: " .. reason .. "\n")
	    end
	    return nil, reason
	  end
	  
	  if f then
	    f:close()
	  end
	else
		if not options.Q then
	  	io.stderr:write("HTTP request failed: " .. response .. "\n")
	  end
	  return nil, response
	end
	return true
end

local function move(from, to)
	local ok, reason = fs.copy(from, to)
	if not ok then return nil, reason end
	fs.remove(from)
	return true
end

fs.makeDirectory(tmpdir)
for _,f in pairs(files) do
	fs.makeDirectory(fs.concat(tmpdir, f[2], ".."))
end

local successing = true
for _,v in pairs(files) do
	local url
	if v[1]:sub(0,1) ~= "!" then
		url = baseurl..v[1]
	else
		url = v[1]:sub(2)
	end
	local ok, reason = download(url, tmpdir..v[2])
	if not ok then
		successing = false
		break
	end
	if not options.q then
		print("Downloaded "..v[2])
	end
end

if not successing then
	if not options.Q then
		io.stderr:write("Files download failed(check log)\nAborting installation")
	end
	fs.remove(tmpdir)
	return false
end
if not options.q then
	print("All OK, installing "..PROGRAM_NAME)
end

fs.makeDirectory(installdir)
for _,f in pairs(files) do
	fs.makeDirectory(fs.concat(installdir, f[2], ".."))
end
for _,file in pairs(files) do
	if not move(tmpdir..file[2], installdir..file[2]) then
		io.stderr:write("Couldn't install file \""..file[2].."\"\n")
	end
end
fs.remove(tmpdir)
if not options.q then
	print("Successfully installed "..PROGRAM_NAME)
end
return