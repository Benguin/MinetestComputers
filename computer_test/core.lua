local MODNAME = "computer_test"
local REGNAME = ":"..MODNAME
local READABLE_NAME = "Computer Test"

computer_test = {}


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
function computer_test.get_mod_name(readable)
    if (readable) then return READABLE_NAME
    else return MODNAME 
    end
end

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
    local base_string = string.format("[%s] ", MOD_READABLE_NAME)

    local message_types = {
        error   = "\27[31;1mERROR: \27[0m ",
        warning = "\27[33;1mWarning: \27[0m ",
        red = "\27[31mWarning: ",
        yellow = "\27[33mWarning: "
    }

    if (color ~= nil and message_types[color] ~= nil and disable_color ~= false) then
        base_string = base_string .. message_types[color]
    end

    local output = base_string ..  (message or 'nil')
    print(output)
end

function computer_test.dump(object, color, disable_color)
    dumped_object = dump(object)

    computer_test.log(dumped_object, color, disable_color)
end



return computer_test