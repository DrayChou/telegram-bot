do

-- Returns true if is not empty
local function has_usage_data(dict)
    if (dict.usage == nil or dict.usage == '') then
        return false
    end
    return true
end

-- Get commands for that plugin
local function plugin_help(name)
    local plugin = plugins[name]
    if not plugin then return nil end
    
    local text = ""
    if (type(plugin.usage) == "table") then
        for ku,usage in pairs(plugin.usage) do
            text = text..usage..'\n'
        end
        text = text..'\n'
    elseif has_usage_data(plugin) then -- Is not empty
        text = text..plugin.usage..'\n\n'
    end
    return text
end

-- !help command
local function telegram_help()
    local text = "Plugin list: \n\n"
    -- Plugins names
    for name in pairs(plugins) do
        text = text..name..'\n'
    end
    text = text..'\n'..'Write "!help [plugin name]" for more info.'
    text = text..'\n'..'Or "!help all" to show all info.'
    -- return text
    
    -- send to who send help
    send_msg (msg.from.print_name, text, ok_cb, false)
end

-- !help all command
local function help_all()
    local ret = ""
    for name in pairs(plugins) do
        ret = ret .. plugin_help(name)
    end
    -- return ret
    -- send to who send help
    send_msg (msg.from.print_name, ret, ok_cb, false)
end

local function run(msg, matches)
    if matches[1] == "!help" then
        return telegram_help(msg)
    elseif matches[1] == "!help all" then
        return help_all(msg)
    else 
        local text = plugin_help(matches[1])
        if not text then
            text = telegram_help(msg)
        end
        return text
    end
end

return {
    description = "Help plugin. Get info from other plugins.  ", 
    usage = {
        "!help: Show list of plugins.",
        "!help all: Show all commands for every plugin.",
        "!help [plugin name]: Commands for that plugin."
    },
    patterns = {
        "^!help$",
        "^!help all",
        "^!help (.+)"
    }, 
    run = run 
}

end
