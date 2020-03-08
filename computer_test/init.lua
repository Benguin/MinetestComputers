local MODNAME = "computer_test"
local READABLE_NAME = "Computer Test"

computer_test = {}

function computer_test.get_modname(readable)
    if (readable) then return READABLE_NAME
    else return MODNAME 
    end
end
local files = {
    'core',
    'computer',
}

for key, file in ipairs(files) do
    dofile(minetest.get_modpath(MODNAME).."/"..file..".lua")
end
