local MODNAME = computer_test.get_modname()
local REGNAME = MODNAME..":"



-- Registration Functions
function computer_test.register_node(name, definition)
    return minetest.register_node(REGNAME .. name, definition)
end

function computer_test.register_entity(name, definition)
    return minetest.register_entity(REGNAME .. name, definition)
end

function computer_test.register_craftitem(name, definition)
    return minetest.register_craftitem(REGNAME .. name, definition)
end

-- GETTERS


function computer_test.get_setting(setting, default)
	if type(default) == "boolean" then
		local read = minetest.settings:get_bool(MODNAME..":"..setting)
		if read == nil then
			return default
		else
			return read
		end
	elseif type(default) == "string" then
		return minetest.settings:get(MODNAME..":"..setting) or default
	elseif type(default) == "number" then
		return tonumber(minetest.settings:get(MODNAME..":"..setting) or default)
    end
end

-- LOGGERS
function computer_test.log(message, color, disable_color) 
    local base_string = string.format("[%s] ", computer_test.get_modname(true))

    local message_types = {
        error   = "\27[31;1mERROR: \27[0m ",
        warning = "\27[33;1mWarning: \27[0m ",
        red = "\27[31m",
        yellow = "\27[33m"
    }

    if (color ~= nil and message_types[color] ~= nil and disable_color ~= false) then
        base_string = base_string .. message_types[color]
    end

    local output = base_string ..  (message or 'nil')
    print(output)
end

function computer_test.dump(object, color, disable_color)
    local dumped_object = dump(object)

    computer_test.log(dumped_object, color, disable_color)
end

-- DIRECTION ASSISTANCE
function computer_test.facedir_to_dir(facedir)
    local dirs = {
        [0] =  {x = 0, y = 1, z = 0},
        [1] =  {x = 0, y = 0, z = 1},
        [2] =  {x = 0, y = 0, z =-1},
        [3] =  {x = 1, y = 0, z = 0},
        [4] =  {x =-1, y = 0, z = 0},
        [5] =  {x = 0, y =-1, z = 0},
    }
    local axis_direction = (facedir - (facedir % 4)) / 4
    return dirs[axis_direction]
end


-- OTHER
function table.slice(tbl, first, last, step)
    local sliced = {}
  
    for i = first or 1, last or #tbl, step or 1 do
      sliced[#sliced+1] = tbl[i]
    end
  
    return sliced
  end
  

function table.copy(obj, seen)
    if type(obj) ~= 'table' then return obj end
    if seen and seen[obj] then return seen[obj] end
    local s = seen or {}
    local res = setmetatable({}, getmetatable(obj))
    s[obj] = res
    for k, v in pairs(obj) do 
        res[table.copy(k, s)] = table.copy(v, s) 
    end
        
    return res
end

function string.split(inputstr, sep)
    if sep == nil then
            sep = "%s"
    end
    local t={}
    for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
            table.insert(t, str)
    end
    return t
end



return computer_test