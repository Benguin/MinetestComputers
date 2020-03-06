local files = {
    'computer',
}

for key, file in ipairs(files) do
    dofile(minetest.get_modpath(mfcore.get_modname()).."/"..file..".lua")
end
