local projHome = arg[1]
local url = arg[2]
local srcDir = projHome.."/lua"
local depsDir = projHome.."/allo/deps"
local libDir = projHome.."/allo/lib"

function os.system(cmd, notrim)
    local f = assert(io.popen(cmd, 'r'))
    local s = assert(f:read('*a'))
    f:close()
    if notrim then return s end
    s = string.gsub(s, '^%s+', '')
    s = string.gsub(s, '%s+$', '')
    return s
end

function os.uname()
    return os.system("uname -s")
end

if os.uname():find("^Darwin") ~= nil then
    package.cpath = package.cpath..";"..libDir.."/osx64/?.dylib"
elseif string.match(package.cpath, "so") then
    package.cpath = package.cpath..";"..libDir.."/linux64/?.so"
elseif string.match(package.cpath, "dll") then
    package.cpath = package.cpath..";"..libDir.."/win64/?.dll"
end

package.path = package.path
    ..";"..srcDir.."/?.lua"
    ..";"..depsDir.."/alloui/lua/?.lua"
    ..";"..depsDir.."/alloui/lib/cpml/?.lua"
    ..";"..depsDir.."/alloui/lib/pl/lua/?.lua"
    
-- Establish globals
require("liballonet")
Client = require("alloui.client")
ui = require("alloui.ui")
class = require('pl.class')
tablex = require('pl.tablex')
pretty = require('pl.pretty')

-- start app
require("main")
