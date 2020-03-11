local ctest = computer_test





local MODNAME = ctest.get_modname()

local EDITOR_FORMSPEC_NAME = MODNAME..":metadata_editor"

local editor_formspec_header = {
    "size[12,8]",
    "position[0.5, 0.5]",
    "real_coordinates[true]",
}

local editor_formspec_footer = {
    "field[0, 7.5; 10, 0.5;label;; %s (%s, %s, %s)]",
    "button[10, 7.5; 1, 0.5;cancel;Cancel]",
    "button[11, 7.5; 1, 0.5;save;Save]",
}

local editor_formspec_hidden = {
    "field[20,20; 1,1;posx;;%s]",
    "field[20,20; 1,1;posy;;%s]",
    "field[20,20; 1,1;posz;;%s]",
}

local editor_formspec_body = {
    "label[0.1,0.25;Fields]",
    "button[2, 0; 0.5, 0.5;delete;-]",
    "button[2.5, 0; 0.5, 0.5;add;+]",
    "textlist[0,0.5; 3,7.0;fieldlist;%s;%s;false]",
    "textarea[3,0; 12,7.5;fieldvalue;;%s]",
}

local function reparse_json(json_string) 
    local table = minetest.parse_json(json_string)
    if (table == nil) then return nil end
    return minetest.write_json(table, true), table
end

local function getEditorFormspec(metatable, pos, selected_index, player )
    selected_index = selected_index or 1
    local fieldlist = {}
    local index = 1
    local metastring
    local metastrings = {} 

    for fieldname, value in pairs(metatable.fields) do
        table.insert(fieldlist, fieldname)
        
        metastring = value

        local status, formatted_metastring, metastringtable  = pcall(reparse_json, metastring)
        if (status and formatted_metastring) then 
            metastring = formatted_metastring 
            table.insert(metastrings, metastring)

            for subfieldname,_ in pairs(metastringtable) do
                table.insert(fieldlist, index+1,"   --"..subfieldname)
                table.insert(metastrings, minetest.write_json(_, true))
                index=index+1
            end
        else table.insert(metastrings, metastring)
        end

        index = index + 1
    end



    local fieldlist_string = table.concat(fieldlist, ',')

    local header = table.concat(editor_formspec_header)

    local body = string.format(
        table.concat(editor_formspec_body),
        fieldlist_string,
        selected_index,
        minetest.formspec_escape(metastrings[selected_index])
    )

    local footer = string.format(
        table.concat(editor_formspec_footer),
        minetest.formspec_escape("Metadata at pos:"),
        pos.x, pos.y, pos.z
    )

    local hidden = string.format(table.concat(editor_formspec_hidden), pos.x, pos.y, pos.z)

    return header..body..footer..hidden
end



ctest.register_craftitem("meta_editor", {
    description="Right click a node to edit its metadata",
    inventory_image="computer_test_meta_editor.png",

    on_use=function(itemstack, player, pointed_thing) 
        local meta = minetest.get_meta(pointed_thing.under)
        if (meta) then
            local metatable = meta:to_table()
            minetest.show_formspec(player:get_player_name(), EDITOR_FORMSPEC_NAME, getEditorFormspec(metatable, pointed_thing.under, nil, player))
        end
    end
})

ctest.register_craftitem("meta_copier", {
    description="Right click a node to copy its metadata, right click another node to apply it.",
    inventory_image="computer_test_meta_copier.png",


})

local button_callbacks = {
    delete=function(player, formname, fields, pos)

    end,
    
    add=function(player, formname, fields, pos)

    end,
    
    save=function(player, formname, fields, pos)

    end,
    
    cancel=function(player, formname, fields, pos)

    end,
}


minetest.register_on_player_receive_fields(
    function (player, formname, fields)
        computer_test.dump(fields, 'warning')
        local pos = computer_test.fields_to_pos(fields)
        if ( pos == nil or fields.quit or formname ~= EDITOR_FORMSPEC_NAME) then
            return
        end

        -- Check for button presses
        for button, callback in pairs(button_callbacks) do
            if fields[button] then
                callback(player, formname, fields, pos)
                return
            end
        end

        -- Handle list selection
        if fields.fieldlist then
            local selected_index = tonumber(string.sub(fields.fieldlist, 5))
            local meta = minetest.get_meta(pos)
            local metatable = meta:to_table()
            minetest.show_formspec(player:get_player_name(), EDITOR_FORMSPEC_NAME, getEditorFormspec(metatable, pos, selected_index, player))
        end
    end
)