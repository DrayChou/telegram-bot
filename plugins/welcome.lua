do

local function user_print_name(user)
    local text = ''
    if user.username then
        text = text..' @'..user.username
    elseif user.print_name then
        text = user.print_name
    else
        if user.first_name then
            text = user.last_name..' '
        end
        if user.lastname then
            text = text..user.last_name
        end
    end
    return text
end

function pre_process(msg)
    if msg.to.type == "chat" and msg.service == true then
        vardump(msg)

        local res = "";
        if msg.action.type == "chat_add_user" then
            -- 别人邀请来的
            res = "Welcome " .. user_print_name(msg.action.user) .. " by " .. user_print_name(msg.from)
        elseif msg.action.type == "chat_add_user_link" then
            -- 自己点链接进来的
            res = "Welcome " .. user_print_name(msg.from) .. " by link"
        elseif msg.action.type == "chat_del_user" then
            -- 离开群的
            if msg.action.user.id == msg.from.id then
                -- 自己离开群的
                res = "Bye bye " .. user_print_name(msg.action.user)
            else
                -- 被踢出群的
                res = "Bye bye " .. user_print_name(msg.action.user) .. " by " .. user_print_name(msg.from)
            end
        end

        send_msg(get_receiver(msg), res, ok_cb, false)
        msg.text = res
    end

    return msg
end

function run(msg, matches)
    return "Welcome, "  .. matches[1]
end

return {
    description = "Says Welcome to someone",
    usage = "say Welcome to [name]",
    patterns = {
        "^[!|#|/][W|w]elcome (.*)$"
    },
    run = run,
    pre_process = pre_process
}

end
