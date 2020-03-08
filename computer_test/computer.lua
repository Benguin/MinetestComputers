

local screen_formspec_header = {
    "size[9,5]",
    "position[0.5, 0.5]",
    "real_coordinates[true]",
}


local screen_formspec_terminal_footer = {
    "field[0, 4.5; 8.5, 0.5;command;;]",
    "field_close_on_enter[command;false]",
    "button[8.5, 4.5; 0.5, 0.5;submit;¬]"
}

-- substitute %s for file contents
local screen_formspec_editor = "textarea[0, 0; 9, 4.5;file;;%s]"

local screen_formspec_editor_footer = {
    "field_close_on_enter[command;false]",
    "button[7.0, 4.5; 1, 0.5;cancel;cancel]",
    "button[8.0, 4.5; 1, 0.5;save;save]"
}

-- take array of strings and return them concatenated
local function get_formspec_string(formspec) 
    local formstring = ""
    for i, string in ipairs(formspec) do   
        formstring = formstring..string
    end
    return formstring
end


-- Store a positional value as hidden (off-screen) formspec fields
local function pos_to_hidden_fields(pos) 
    local base_string = "field[20,20;1,1;%s;;%s]"
    local fields = {}
    for axis,value in pairs(pos) do
        table.insert(fields, string.format(base_string, "pos"..axis, value))
    end
    return fields
end

-- Take lines and reutrn them as fromspec labels, with height offsets appropriate to the line number
local function format_terminal_output(lines)
    if (lines == nil) then return "" end
    local top_pad = 0
    local spacing = 0.25
    local output = ""
    local base_string = "label[0.375, %s; %s]"
    local lines = lines
    if (#lines > 16) then
        lines = table.slice(lines, #lines-16, #lines)
    end

    for i,line in ipairs(lines) do
        local yPos = top_pad + (spacing*i)
        output = output..string.format(base_string, yPos, minetest.formspec_escape(line))
    end

    return output
end

-- Generate the formspec for the terminal screen
local function get_terminal_formspec(pos) 
    local meta = minetest.get_meta(pos)

    local header = get_formspec_string(screen_formspec_header)
    local output = format_terminal_output(
        minetest.parse_json(meta:get_string("output"))
    )
    local footer = get_formspec_string(screen_formspec_terminal_footer)
    local hidden = get_formspec_string(pos_to_hidden_fields(pos))

    return header..output..footer..hidden
end

-- Store an environment for each computer type here, autofills when using get_computer_environment(pos)
local computer_environments = {

}


-- Take an array of files and a file path (starting in root/) and return the file / array at the destination (or false if not found)
local function get_file_from_filename(files, filename) 
    if (files == nil or filename == nil) then return false end

    local fname_parts
    if (type(filename) == "table" ) then
        fname_parts = filename
    else    
        fname_parts = string.split(filename, '/')
    end
    
    if (#fname_parts > 1) then
        if (files[fname_parts[1]]) then 
            
            return get_file_from_filename(files[fname_parts[1]], table.slice(fname_parts, 2))
        else return false
        end
    else
        if (files[fname_parts[1]]) then 
            return files[fname_parts[1]] 
        else return false
        end
    end
end


--  two-way conversion between signal names and signal codes, for use as special terminal signals.
local builtin_signals = {
    -- CLEAR signal, clears the current terminal screen output
    [1]='clear',
    CLEAR=1,
}

-- Given a full filepath, this returns the containing folder of the destination file
local function get_containing_folder(files, fullpath)
    local pathparts = string.split(fullpath, '/')
    local pwd = files
    for i = 1, #pathparts,1 do
        local file = pwd[pathparts[i]]
        if(type(file) == "table") then
            pwd = file
        elseif (type(file) == "string" or type(file) == nil) then
            return pwd
        end
    end

end

-- Generate the formspec for the terminal file editor
local function get_terminal_edit_formspec(pos, player, file, filename) 
    file = file or ""

    local header = get_formspec_string(screen_formspec_header)
    local editor = string.format(screen_formspec_editor, minetest.formspec_escape(file))
    local filename = string.format("field[0, 4.5; 7, 0.5;filename;;%s]", filename)
    local footer = get_formspec_string(screen_formspec_editor_footer)
    local hidden = get_formspec_string(pos_to_hidden_fields(pos))

    local formspec =  (header..editor..filename..footer..hidden)
    return formspec
    

end


-- Array of commands the shell recognises natively. These commands are the only way to access the uninhibited lua modding environment
local builtin_commands = {
    ls = function(pos, player, files, pwd, arg)
        local lfiles = get_file_from_filename(files, pwd)

        if (lfiles == false) then return "No files found" end

        local output = {"ls: /"..pwd..":",}

        for filename,file in pairs(lfiles) do
            table.insert(output, "---- "..filename)
        end

        return output
    end,

    run=function(pos, player, files, pwd, args)
        local filename = args[1]
        local value_error = false
        args = table.slice(args, 2)
       
        -- function to substitide script arguments
        local function rep_arg(str)
            if (#args > 0) then
                return table.remove(args, 1)
            else
                value_error = true 
            end
        end

        -- Return error if no filename was given
        if (filename == nil) then return "Run: no filename given" end

        local lfiles = get_file_from_filename(files, pwd)
        local file = get_file_from_filename(lfiles, filename)

        -- Return error if file not found:
        if (file == false) then return "Run: file at ".. pwd ..'/'..filename.." not found." end

        -- Substitute the script's arguments with the ones given via shell
        local file_w_args = string.gsub(file,"%$", rep_arg)

        -- If the arguments couldn't be substituted, show error
        if (value_error) then return "Run ["..filename.."]: incorrect number of arguments supplied to shell script" end

        -- Limit the script's environment
        local func = setfenv(loadstring(file_w_args), computer_test.get_computer_environment(pos, player))
        local status, output = pcall(func)

        if (status) then
            return output
        else 
            return "Run ["..filename.."] Error: " .. output
        end
    end,


    clear=function(pos, player)
        return builtin_signals.CLEAR
    end,

    edit=function(pos, player, files, pwd, args)
        local filename = args[1]

        -- if no filename given, create timestamped blank file:
        if (filename == nil) then filename="new_file_"..os.date("%x-%X", os.time()) end

        local fullpath = string.format("%s/%s", pwd, filename)
        local file = get_file_from_filename(files, fullpath)
        
        -- Default file contents:
        if (not file) then  file = "" end
        local formspec = get_terminal_edit_formspec(pos, player, file, fullpath)
        return {
            formspec_name = "computer_test:terminal_edit_screen",
            formspec=formspec,
            output={
                "Edit: editing file at " .. fullpath,
            }
        }
    end,

    mv=function(pos, player, files, pwd, args, env)
        local filename = args[1]
        local newname = args[2]

        local fullpath = string.format("%s/%s", pwd, filename)
        local newpath = string.format("%s/%s", pwd, newname)

        local file = get_file_from_filename(files, fullpath)
        local newfile = get_file_from_filename(files, newpath)

        if (not file) then 
            return "mv: Src file not found '"..fullpath.."'"
        elseif (newfile) then
            return "mw: destination file already exists '"..newpath.."'"
        end

        local folder = get_containing_folder(files, fullpath)
        folder[newname] = file
        folder[filename] = nil
        env.meta:set_string("files", minetest.write_json(files))
        
        return "Moved file."
    end,
}

local default_fake_env = {
    ls=builtin_commands.ls,
    test=builtin_commands.test,
    run=builtin_commands.run,
    edit=builtin_commands.edit,
    print=function (pos, player, message)
        local meta=minetest.get_meta(pos)
        local output = minetest.parse_json(meta:get_string("output"))
        table.insert(output, message)
        meta:set_string("output", minetest.write_json(output))
        minetest.show_formspec(player:get_player_name(), "computer_test:terminal_screen", get_terminal_formspec(pos))
    end,
    clear=builtin_commands.clear,
    mv=builtin_commands.mv,
    write_output=write_output,
    getfenv=getfenv,
    pairs=pairs,
    ipairs=ipairs,
    type=type,
    string=string,
    table=table,
    type=type,
    pcall=pcall,
    computer_test={
        log=computer_test.log,
        dump=computer_test.dump,
    },
    signals=builtin_signals,
}


function computer_test.get_computer_environment(pos, player)
    if (computer_environments[pos] == nil) then
        computer_environments[pos] = table.copy(default_fake_env)
    end

    local env  = computer_environments[pos]
    local meta = minetest.get_meta(pos)
    env.files  = minetest.parse_json(meta:get_string("files"))
    env.pwd    = meta:get_string("PWD")
    env.pos    = pos
    env.player = player
    env.meta   = meta

    return env
end

-- run a shell builtin command and pass its arguments, or look for files in the current directory to run
local function execute_command(pos, player, command, args)
    local fake_environment = computer_test.get_computer_environment(pos, player)
    local files = fake_environment.files
    local pwd = fake_environment.pwd

    if (builtin_commands[command] == nil) then 
        table.insert(args, 1, command)
        return builtin_commands.run(pos, player, files, pwd, args)
    else
        return fake_environment[command](pos, player, files, pwd, args, fake_environment)
    end
end

-- Extract positional value back out of formspec hidden fields
local function fields_to_pos(fields)
    local pos = nil
    if (fields.posx and fields.posy and fields.posz) then
        pos = {
            x = fields.posx,
            y = fields.posy,
            z = fields.posz
        }
    end
    return pos
end

-- Initialise TestOS in computer metadata:
local function comp_after_place_node(pos, placer)
    local meta = minetest.get_meta(pos)
    meta:set_string("PWD", "root")
    meta:set_string("files", minetest.write_json({
        root={
            hello_world="print('HELLO WORLD!')"
        }
    }))
    meta:set_string("output", minetest.write_json({
        "Welcome to TestOS!",
    }))
end


-- Write output to computer console at pos
local function write_output(pos, output, player) 
    -- Return if no output
    if (output == nil) then 
        return  
    end
    
    -- computer_test.log("COMMAND OUTPUT:\n"..dump(output), 'red')

    -- Get existing text
    local meta = minetest.get_meta(pos)
    local stored_output = minetest.parse_json(meta:get_string("output"))
    local next_formspec_name = "computer_test:terminal_screen"
    local next_formspec = nil

    -- Check if output was a special signal
    if (type(output) == "number") then 
        local signal = builtin_signals[output]

        if (signal ~= nil) then 
            if (signal == 'clear') then
                stored_output = {" "}
            end
        end
    end
    
    if (type(output) == "string") then
        table.insert(stored_output, output)
    end

    
    -- Either display a new formspec, or write output
    if (type(output) == "table") then
        if (output.formspec_name ~= nil and player ~= nil) then
            for i, line in ipairs(output.output) do
                table.insert(stored_output, line)
            end

            next_formspec_name = output.formspec_name
            next_formspec = output.formspec
        else
            for i, line in ipairs(output) do
                table.insert(stored_output, line)
            end
        end
    end
    meta:set_string("output", minetest.write_json(stored_output))
    minetest.show_formspec(player:get_player_name(), next_formspec_name, next_formspec or get_terminal_formspec(pos))
end

local computer_def = {
    description = "Computer",
    tiles = {

        {
            name="computer_test_computer_front.png",
            animation = {
                type="vertical_frames",
                aspect_w=16,
                aspect_h=16,
                length=2.0
            }
        },
        {
            name="computer_test_computer_back.png",
            animation = {
                type="vertical_frames",
                aspect_w=16,
                aspect_h=16,
                length=0.2
            }
        },
        "computer_test_computer_side.png",
        "computer_test_computer_side.png",
        "computer_test_computer_side.png",
        "computer_test_computer_side.png"
    },
    drawtype = "normal",
    is_ground_content= false,
    groups={cracky=1},
    paramtype="light",
    paramtype2="facedir",
    light_source=10,


    after_place_node=comp_after_place_node,

    on_rightclick = function(pos, node, player, itemstack, pointed_thing)
        --TODO Add permission check on formspec
        minetest.show_formspec(player:get_player_name(), "computer_test:terminal_screen", get_terminal_formspec(pos))
    end,
    
    on_place=function(itemstack, placer, pointed_thing)
        local rotation_to_add = {
            2,
            2,
            0,
            3,
            1,
            0,
        }

        minetest.rotate_and_place(itemstack, placer, pointed_thing)
        local node = minetest.get_node(pointed_thing.above)

        -- Set the rotation dependent on direciton
        --  the rotate_and_place gets it a bit wrong..
        local rotation = node.param2%4
        local axisDir = (node.param2-rotation)/4

        local dir = computer_test.facedir_to_dir(node.param2)
        if (dir.x ~=0 or dir.z ~= 0) then 
            node.param2 = (axisDir*4) + rotation_to_add[axisDir+1]
        end

        minetest.set_node(pointed_thing.above, node)
        -- Manually call after_place_node
        -- TODO are we missing any callbacks here?
        comp_after_place_node(pointed_thing.above, placer)
    end
}

computer_test.register_node("computer", computer_def)

-- Catch formspec field submissions


local receive_terminal_fields = function(pos, player, formname, fields)
    if (fields.command ~= nil) then
        local tokens = string.split(fields.command, ' ')
        local command = tokens[1]
        local args = table.slice(tokens, 2)

        if (command ~= nil) then
            local output = execute_command(pos, player, command, args)
            write_output(pos, output, player)
        end
    end
end

local receive_terminal_edit_fields = function(pos, player, formname, fields)
    local meta = minetest.get_meta(pos)
    local filepath = fields.filename
    local new_file = fields.file
    if fields.save ~= nil  then
        local pathparts = string.split(filepath, '/')
        local files = minetest.parse_json(meta:get_string("files"))
        local pwd = files
        for i = 1, #pathparts,1 do
            local file = pwd[pathparts[i]]
            if (type(file) == "string") then
                pwd[pathparts[i]] = new_file
                break
            elseif(type(file) == "table") then
                pwd = file
            elseif (file == nil) then
                pwd[pathparts[i]] = new_file
                break
            else
                computer_test.log("Else statement reached in save file function", 'error')
            end

        end
        meta:set_string("files", minetest.write_json(files))
        

    elseif fields.cancel then

    end

    minetest.show_formspec(player:get_player_name(), "computer_test:terminal_screen", get_terminal_formspec(pos))

end



minetest.register_on_player_receive_fields(
    function (player, formname, fields)
        local pos = fields_to_pos(fields)
        if ( pos == nil or fields.quit) then
            return
        end

        if (formname == "computer_test:terminal_screen") then
            receive_terminal_fields(pos, player, formname, fields)
        elseif (formname == "computer_test:terminal_edit_screen") then
            receive_terminal_edit_fields(pos, player, formname, fields)
        end
        
   
    end
)


-- 

