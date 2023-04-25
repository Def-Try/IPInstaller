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

--localisation strings
local localisation = {
  ["install.move"] = "Please wait, "..INSTALLER_NAME.." is moving program files",
  ["install.move.fail"] = "Couldn't move %s to %s: %s",
  ["install.move.v"] = "Moved %s to %s",
  ["install.download"] = "Please wait, "..INSTALLER_NAME.." is downloading program files",
  ["install.download.v"] = "Downloaded %s from %s",
  ["install.download.fail"] = "Failed files download. Check your internet connection or contact with installer provider.",
  ["install.download.ok"] = "All files downloaded.",
  ["install.success"] = "Successfully installed.",
  ["uninstall.delete"] = "Please wait, "..INSTALLER_NAME.." is removing program files",
  ["uninstall.delete.v"] = "Removed %s",
  ["uninstall.success"] = "Successfully uninstalled.",
  
  ["error.nointernet"] = INSTALLER_NAME.." requires an internet card to run.",
  ["error.httpfail"] = "HTTP request failed: %s",
  ["error.writefail"] = "Failed opening file for writing: %s",
  
  ["info"] = PROGRAM_NAME.."\n"..PROGRAM_DESCRIPTION,
  ["help"] = INSTALLER_NAME.."\n"..INSTALLER_DESCRIPTION.."\n\n"..[[
Usage: %s [-qQ] <action...>
 -q: Quiet mode - no status messages.
 -Q: Superquiet mode - no error messages.
 -v: Be more verbose.
Actions:
  install: Install program to your PC
  uninstall: Uninstall program from your PC
  info: Get info about this program
]]
}

--END BASE VARIABLES

local component = require("component")
local shell = require("shell")
local fs = require("filesystem")
local internet = require("internet")
local process = require("process")

if not component.isAvailable("internet") then
  io.stderr:write(localisation["error.nointernet"])
  return
end

local args, options = shell.parse(...)
options.q = options.q or options.Q
options.h = options.h or options.help

if options.h or #args ~= 1 then
  local seg = fs.segments(shell.resolve(process.info().path))
  io.write(string.format(localisation["help"], seg[#seg]))
  return
end

if args[1] == "info" then
  io.write(localisation["info"])
  return
end

if args[1] == "uninstall" then
        if not options.q then
    print(localisation["uninstall.delete"])
  end
  for _,file in pairs(files) do
    if not options.q and fs.remove(installdir..file[2]) and options.v then
      print(string.format(localisation["uninstall.delete.v"], installdir..file[2]))
    end
  end
  if not options.q then
    print(localisation["uninstall.success"])
  end
  return
end

if not options.q then
  print(localisation["install.download"])
end

local function download(url, filename)
  local f
  local result, response = pcall(internet.request, url, nil, {["user-agent"]="IPInstall/OpenComputers"})
  if result then
    local result, reason = pcall(function()
      for chunk in response do
        if not f then
          f, reason = io.open(filename, "wb")
          if not f then
            if not options.Q then
              io.stderr:write(string.format(localisation["error.writefail"].."\n", reason))
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
        io.stderr:write(string.format(localisation["error.httpfail"].."\n", reason))
      end
      return nil, reason
    end
    
    if f then
      f:close()
    end
  else
    if not options.Q then
      io.stderr:write(string.format(localisation["error.httpfail"].."\n", reason))
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

local function shorten(s, len)
  return string.sub(s, 0, math.floor(len/5)).."..."..string.sub(s, #s-len+math.floor(len/5)-4)
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
  if not options.q and options.v then
    local fr = string.find(url, "//")+2
    print(string.format(localisation["install.download.v"], v[2], shorten(string.sub(url, fr), 30)))
  end
end

if not successing then
  if not options.Q then
    io.stderr:write(localisation["install.download.fail"].."\n")
  end
  fs.remove(tmpdir)
  return false
end
if not options.q then
  print(localisation["install.download.ok"].."\n"..localisation["install.move"])
end

fs.makeDirectory(installdir)
for _,f in pairs(files) do
  fs.makeDirectory(fs.concat(installdir, f[2], ".."))
end
for _,file in pairs(files) do
  local ok, reason = move(tmpdir..file[2], installdir..file[2])
  if not ok then
    io.stderr:write(string.format(localisation["install.move.fail"].."\n", tmpdir..file[2], installdir..file[2], reason))
  elseif options.v then
    print(string.format(localisation["install.move.v"], tmpdir..file[2], installdir..file[2]))
  end
end
fs.remove(tmpdir)
if not options.q then
  print(localisation["install.success"])
end
return
