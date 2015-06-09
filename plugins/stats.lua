-- Saves the number of messages from a user
-- Can check the number of messages with !stats

do

local NUM_MSG_MAX = 5
local TIME_CHECK = 4 -- seconds
local DEFAULT_SHOW_LIMIT = 25 -- 显示的最多条数

local function user_print_name(user)
    local text = ''
    if user.print_name then
        text = user.print_name
    else
        if user.first_name then
            text = user.last_name..' '
        end
        if user.lastname then
            text = text..user.last_name
        end
    end
    
    if user.username then
        text = text..' @'..user.username
    end
    
    return text
end

-- Returns a table with `name` and `msgs` and `msgs_day`
local function get_msgs_user_chat(user_id, chat_id, day_id)
    local user_info = {}
    local uhash = 'user:'..user_id
    local user = redis:hgetall(uhash)
    
    local um_hash = 'msgs:'..user_id..':'..chat_id..':'..day_id
    if day_id == 'ALL' then
        um_hash = 'msgs:'..user_id..':'..chat_id
    end
    
    if day_id == 'TODAY' or day_id == 'TD' then
        um_hash = 'msgs:'..user_id..':'..chat_id..':'..os.date("%Y%m%d")
    end
    
    user_info.user_id = user_id
    user_info.name = user_print_name(user)..' ('..user_id..')'
    user_info.msgs = tonumber(redis:get(um_hash) or 0)
    return user_info
end


-- 得到用户的信息列表
local function get_users(msg, day_id)
    local chat_id = msg.to.id
    
    local users_info = {}
    -- 从用户消息的受众那边拿到用户列表
    if msg.to.members then
        for i,user in pairs(msg.to.members) do
            if user.type == 'user' then
                local user_id = user.id
                local user_info = get_msgs_user_chat(user_id, chat_id, day_id)
                table.insert(users_info, user_info)
            end
        end
    else
        local hash = 'chat:'..chat_id..':users'
        local users = redis:smembers(hash)
        --        -- Get user info
        for i = 1, #users do
            local user_id = users[i]
            local user_info = get_msgs_user_chat(user_id, chat_id, day_id)
            table.insert(users_info, user_info)
        end
    end
    
    return users_info
end

local function get_msg_num_stats(msg, day_id, limit)
    if msg.to.type == 'chat' then
        -- Users on chat
        local users_info = get_users(msg, day_id)
        
        -- 排序
        local order_by = 1
        if limit < 0 then
            order_by = 2
            limit = -1 * limit
        end
        
        -- Sort users by msgs number
        table.sort(users_info, function(a, b)
            if a.msgs and b.msgs then
                if order_by == 1 then
                    return a.msgs > b.msgs
                else
                    return a.msgs < b.msgs
                end
            end
        end)
        
        local top_sum = 0
        local sum = 0
        local text = ''
        local log_num = 0
        for k,user in pairs(users_info) do
            -- 加前缀
            if log_num == 0 then
                text = text..day_id:upper()..' TOP '..limit..'\n'
            end
            
            sum = sum + tonumber(user.msgs)
            log_num = log_num + 1
            -- 如果超过50个了，不再输出
            if log_num <= limit then
                top_sum = top_sum + tonumber(user.msgs)
                text = text..user.name..' => '..user.msgs..'\n'
            end
        end
        
        -- 统计
        text = text..'TOP SUM: '..top_sum..'\n'
        text = text..'ALL SUM: '..sum..'\n'
        text = text..'TOP/ALL: '..((top_sum/sum)*100)..'%\n'
        return text
    end
end

-- 加载用户聊天信息
local function get_user_msg_num_stats(msg, user_id)
    local all_users_info = get_users(msg, 'ALL')
    local day_users_info = get_users(msg, os.date("%Y%m%d"))
    
    -- 统计用户和所有用户所有发言的计数
    local user_all_num = 0
    local all_sum = 0
    for k,user in pairs(all_users_info) do
        all_sum = all_sum + tonumber(user.msgs)
        
        if user.user_id == user_id then
            user_all_num = user.msgs
        end
    end
    
    -- 统计用户和所有用户今天发言的计数
    local user_day_num = 0
    local day_sum = 0
    for k,user in pairs(day_users_info) do
        day_sum = day_sum + tonumber(user.msgs)
        
        if user.user_id == user_id then
            user_day_num = user.msgs
        end
    end
    
    -- 统计
    local text = ''
    text = text..'USER COUNT: '..user_all_num..'\n'
    text = text..'ALL USER SUM: '..all_sum..'\n'
    text = text..'USER/ALL: '..((user_all_num/all_sum)*100)..'\n'
    text = text..'USER TODAY COUNT: '..user_day_num..'\n'
    text = text..'ALL USER TODAY SUM: '..day_sum..'\n'
    text = text..'USER/ALL: '..((user_day_num/day_sum)*100)..'\n'
    return text
end

-- Save stats, ban user
local function pre_process(msg)
    -- Save user on Redis
    if msg.from.type == 'user' then
        local hash = 'user:'..msg.from.id
        if msg.from.print_name then
            redis:hset(hash, 'print_name', msg.from.print_name)
        end
        if msg.from.first_name then
            redis:hset(hash, 'first_name', msg.from.first_name)
        end
        if msg.from.last_name then
            redis:hset(hash, 'last_name', msg.from.last_name)
        end
        if msg.from.user_name then
            redis:hset(hash, 'user_name', msg.from.user_name)
        end
    end
    
    -- Save stats on Redis
    if msg.to.type == 'chat' then
        -- User is on chat
        local hash = 'chat:'..msg.to.id..':users'
        redis:sadd(hash, msg.from.id)
    end
    
    -- Total user msgs
    local hash = 'msgs:'..msg.from.id..':'..msg.to.id
    redis:incr(hash)
    
    -- Total user today msgs
    local hash_day = 'msgs:'..msg.from.id..':'..msg.to.id..':'..os.date("%Y%m%d")
    redis:incr(hash_day)
    
    -- Check flood
    if msg.from.type == 'user' then
        local hash = 'user:'..msg.from.id..':msgs'
        local msgs = tonumber(redis:get(hash) or 0)
        if msgs > NUM_MSG_MAX then
            print('User '..msg.from.id..'is flooding '..msgs)
            msg = nil
        end
        redis:setex(hash, TIME_CHECK, msgs+1)
    end
    
    return msg
end

local function get_bot_stats()
    
  local redis_scan = [[
    local cursor = '0'
    local count = 0
    repeat
      local r = redis.call("SCAN", cursor, "MATCH", KEYS[1])
      cursor = r[1]
      count = count + #r[2]
    until cursor == '0'
    return count]]
    
    -- Users
    local hash = 'msgs:*:*'
    local r = redis:eval(redis_scan, 1, hash)
    local text = 'Users: '..r
    
    -- 群
    hash = 'chat:*:users'
    r = redis:eval(redis_scan, 1, hash)
    text = text..'\nChats: '..r
    
    -- 每日的
    hash = 'msgs:*:*:*'
    r = redis:eval(redis_scan, 1, hash)
    text = text..'\nChatsDays: '..r
    
    return text
    
end

local function run(msg, matches)
    if matches[1]:lower() == "stats" then
        if msg.to.type == 'chat' then
            -- 解析第二个参数
            local day_id = os.date("%Y%m%d")
            if matches[2] then
                day_id = matches[2]:upper()
            end
            
            -- 解析查询的数量
            local limit = DEFAULT_SHOW_LIMIT
            if matches[3] then
                limit = tonumber(matches[3])
            end
            
            return get_msg_num_stats(msg, day_id, limit)
        elseif is_sudo(msg) then
            return get_bot_stats()
        else
            return 'Stats works only on chats'
        end
    end
    
    if matches[1]:lower() == "stat" then
        local user_id = tonumber(matches[2])
        return get_user_msg_num_stats(msg, user_id)
    end
end

return {
    description = "Plugin to update user stats.",
    usage = {
        "!stats: Returns a list of Username [telegram_id]: msg_num only top"..DEFAULT_SHOW_LIMIT,
        "!stats 20150528: Returns this day stats",
        "!stats all: Returns All days stats",
        "!stats 20150528 "..DEFAULT_SHOW_LIMIT..": Returns a list only top "..DEFAULT_SHOW_LIMIT,
        "!stat user_id: Returns this user All days stats"
    },
    patterns = {
        "^!([Ss]tats)$",
        "^!([Ss]tats) ([%w]+)$",
        "^!([Ss]tats) ([%w]+) ([-|%w]+)$",
        "^!([Ss]tat) ([%w]+)$"-- 读取用户的信息
    },
    run = run,
    pre_process = pre_process
}

end
