-- Saves the number of messages from a user
-- Can check the number of messages with !stats

do

local NUM_MSG_MAX = 5
local TIME_CHECK = 4 -- seconds
local DEFAULT_SHOW_LIMIT = 10 -- 显示的最多条数

-- 拿去间隔时间的日期 20151103 2015-11-03
function day_step(old_day,step)
    local y,m,d
    if("0" ~= string.sub(old_day,5,5)) then
        m=string.sub(old_day,5,6)
    else
        m=string.sub(old_day,6,6)
    end
    
    if("0" ~= string.sub(old_day,7,7)) then
        d=string.sub(old_day,7,8)
    else
        d=string.sub(old_day,8,8)
    end
    
    y=string.sub(old_day,0,4)
    
    local old_time=os.time{year=y,month=m,day=d}
    local new_time=old_time+86400*step
    
    local new_day=os.date("*t",new_time)
    local res=""
    
    if(tonumber(new_day.day)<10 and tonumber(new_day.month)<10)then
        res=new_day.year.."0"..new_day.month.."0"..new_day.day
    elseif tonumber(new_day.month)<10 then
        res=new_day.year.."0"..new_day.month..new_day.day
        
    elseif tonumber(new_day.day)<10 then
        res=new_day.year..new_day.month.."0"..new_day.day
    else
        res=new_day.year..new_day.month..new_day.day
    end
    return res
end

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

local users_list = {}
-- 回调函数 返回所有成员的信息
local function returnids(cb_extra, success, result)
	for k,v in pairs(result.members) do
	    local user_info = {}
	    user_info.id = tonumber(v.id)
	    user_info.name = user_print_name(v)..' ('..v.id..')'
	    table.insert(users_list, user_info)
	end
    
	-- vardump("returnids：")
	-- vardump(users_list)
    
	return users_list
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
    
    if day_id == 'TODAY' or day_id == 'TD' or day_id == 'T' then
        um_hash = 'msgs:'..user_id..':'..chat_id..':'..os.date("%Y%m%d")
    end
    
    user_info.id = tonumber(user_id)
    user_info.name = user_print_name(user)..' ('..user_id..')'
    user_info.msgs = tonumber(redis:get(um_hash) or 0)
    return user_info
end

-- 得到用户的信息列表
local function get_users(msg, day_id)
    if msg.to.type == 'chat' then
	    local users_info = {}
        local chat_id = msg.to.id
        
        -- vardump("用户列表·2：")
		-- vardump(users_list)
        
        -- 从用户消息的受众那边拿到用户列表
        --if users_list then
        -- for k, v in pairs(users_list) do
        --  local user_info = get_msgs_user_chat(v.id, chat_id, day_id)
        --  table.insert(users_info, user_info)
        -- end
        --else
        local hash = 'chat:'..chat_id..':users'
        local users = redis:smembers(hash)
        --        -- Get user info
        for i = 1, #users do
            local user_id = users[i]
            local user_info = get_msgs_user_chat(user_id, chat_id, day_id)
            table.insert(users_info, user_info)
        end
        --end
        
        return users_info
    end
end

-- 重建群每日发言数数据
local function rebuild_stats_data(search_chat_id, search_day_id)
    
    print('update chat day stats-> search_chat_id:'..search_chat_id..' day_id: '..search_day_id)
    
    -- 查询所有的天数的数据的统计资料，一般只执行一次
    local hash = 'msgs:*:'..search_chat_id..':'..search_day_id
    local res = redis:keys(hash)
    local today_id = tonumber(os.date("%Y%m%d"))
    
    -- 拆开成数组的格式
    local count = {}
    for k, row in pairs(res) do
        local keys = row:split(":")
        local user_id = tonumber(keys[2] or 0)
        local chat_id = tonumber(keys[3] or 0)
        local day_id = tonumber(keys[4] or 0)
        
        if count[chat_id] == nil then
            count[chat_id] = {}
            count[chat_id][day_id] = 0
        else
            if count[chat_id][day_id] == nil then
                count[chat_id][day_id] = 0
            end
        end
        
        count[chat_id][day_id] = count[chat_id][day_id] + tonumber(redis:get(row) or 0)
    end
    
    -- 比较拿出每个讨论组里发言最多的一天
    for c, days in pairs(count) do
        local mxd = nil
        local mxm = 0
        local mid = nil
        local mim = 99999999
        
        for d, n in pairs(days) do
            if n > mxm then
                mxd = d
                mxm = n
            end
            
            if n < mim then
                mid = d
                mim = n
            end
            
            redis:set('stats:chat:'..c..':'..d, n)
        end
        
        vardump("max_day:"..mxd..'\t'.."min_day:"..mid)
        
        if search_day_id == '*' then
            redis:set('stats:chat:'..c..':max_day', mxd)
            redis:set('stats:chat:'..c..':min_day', mid)
        else
            if tonumber(search_day_id) == today_id then
                vardump("search_day_id == today_id:"..today_id)
            else
                local max_day = tonumber(redis:get('stats:chat:'..c..':max_day') or 0)
                local min_day = tonumber(redis:get('stats:chat:'..c..':min_day') or 0)
                local max_msgs = tonumber(redis:get('stats:chat:'..c..':'..max_day) or 0)
                local min_msgs = tonumber(redis:get('stats:chat:'..c..':'..min_day) or 0)
                
                vardump("old_max_day:"..max_day..'\t'.."old_max_msgs:"..max_msgs..'\t'.."old_min_day:"..min_day..'\t'.."old_min_msgs:"..min_msgs)
                
                if mxm > max_msgs then
                    vardump("new_max_day:"..mxd)
                    redis:set('stats:chat:'..c..':max_day', mxd)
                end
                
                if mim < min_msgs then
                    vardump("new_min_day:"..mid)
                    redis:set('stats:chat:'..c..':min_day', mid)
                end
            end
        end
    end
end


-- 统计群最大最小的发言量
local function get_chat_mx(chat_id)
    
    local max_msgs = 0
    local min_msgs = 0
    local max_day = tonumber(redis:get('stats:chat:'..chat_id..':max_day') or 0)
    local min_day = tonumber(redis:get('stats:chat:'..chat_id..':min_day') or 0)
    
    if max_day == 0 or min_day == 0 then
        
        rebuild_stats_data('*', '*')
        
        max_day = tonumber(redis:get('stats:chat:'..chat_id..':max_day') or 0)
        min_day = tonumber(redis:get('stats:chat:'..chat_id..':min_day') or 0)
        
    end
    
    max_msgs = redis:get('stats:chat:'..chat_id..':'..max_day)
    min_msgs = redis:get('stats:chat:'..chat_id..':'..min_day)
    
    return max_day, max_msgs, min_day, min_msgs
end


------------------------------------ 以上为功能函数

-- 加载聊天室聊天状态
local function get_char_stats(msg, day_id, limit)
    if msg.to.type == 'chat' then
        local chat_id = msg.to.id
        
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
        
        local max_day, max_msgs, min_day, min_msgs = get_chat_mx(chat_id)
        
        -- 统计
        text = text..'top sum: '..top_sum..'\n'
        text = text..'all sum: '..sum..'\n'
        text = text..'top/all: '..string.format("%6.2f", ((top_sum/sum)*100))..'%\n'
        --        text = text..'chat_id: '..chat_id..'\n'
        text = text..'max day: '..max_day..' => '..max_msgs..'\n'
        text = text..'min day: '..min_day..' => '..min_msgs..'\n'
        return text
    end
end


-- 加载用户聊天信息
local function get_user_stats(msg, user_id)
    if user_id == 'me' then
        user_id = msg.from.id
    else
        user_id = tonumber(user_id)
    end
    
    -- 统计用户和所有用户所有发言的计数
    local all_users_info = get_users(msg, 'ALL')
    local user_all_num = 0
    local all_sum = 0
    for k,user in pairs(all_users_info) do
        all_sum = all_sum + tonumber(user.msgs)
        
        if user.id == user_id then
            user_all_num = tonumber(user.msgs)
        end
    end
    
    -- 统计用户和所有用户今天发言的计数
    local day_users_info = get_users(msg, os.date("%Y%m%d"))
    local user_day_num = 0
    local day_sum = 0
    for k,user in pairs(day_users_info) do
        day_sum = day_sum + tonumber(user.msgs)
        
        if user.id == user_id then
            user_day_num = tonumber(user.msgs)
        end
    end
    
    local uhash = 'user:'..user_id
    local user = redis:hgetall(uhash)
    
    -- 统计
    local text = ''
    text = text..user_print_name(user)..' state:\n'
    text = text..'stats count: '..user_all_num..'\n'
    text = text..'all user sum: '..all_sum..'\n'
    text = text..'user/all: '..string.format("%6.2f", ((user_all_num/all_sum)*100))..'%\n'
    text = text..'user today count: '..user_day_num..'\n'
    text = text..'all user today sum: '..day_sum..'\n'
    text = text..'user/all: '..string.format("%6.2f", ((user_day_num/day_sum)*100))..'%\n'
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
    
    -- 刷新重新统计这个群的每日最多和最少
    if msg.to.type == 'chat' then
        local today_id = os.date("%Y%m%d")
        rebuild_stats_data(msg.to.id, today_id)
        rebuild_stats_data(msg.to.id, day_step(today_id, -1))
    end
    
    return msg
end

-- 得到机器的状态
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
    
    -- 有多少条发言数最大最小统计
    hash = 'stats:chat:*:*'
    r = redis:eval(redis_scan, 1, hash)
    text = text..'\nStats:chat: '..r
    
    return text
    
end


local function run(msg, matches)
    if matches[1]:lower() == "stats" then
        if msg.to.type == 'chat' then
            -- 解析第二个参数
            local day_id = os.date("%Y%m%d")
            if matches[2] then
                day_id = matches[2]:upper()
        	else
	        	day_id = 'ALL'
            end
            
            -- 解析查询的数量
            local limit = DEFAULT_SHOW_LIMIT
            
            -- 默认总表单输出数据量为每日的一半
            if day_id == 'ALL' then
                limit = limit/2
            end
            
            if day_id == 'TODAY' or day_id == 'TD' or day_id == 'T' then
	            day_id = os.date("%Y%m%d")
            end
            
            if matches[3] then
                limit = tonumber(matches[3])
            end
            
			-- 统计人数
            local receiver = get_receiver(msg)
			local chat = 'chat#id'..msg.to.id
	    	local res = chat_info(chat, returnids, {receiver=receiver})
			-- vardump("用户列表·1：")
			-- vardump(res)
			-- vardump(users_list)
			-- vardump(receiver)
            
            return get_char_stats(msg, day_id, limit)
        elseif is_sudo(msg) then
            return get_bot_stats()
        else
            return 'Stats works only on chats'
        end
    end
    
    if matches[1]:lower() == "state" then
        return get_user_stats(msg, matches[2])
    end
end


return {
    description = "Plugin to update user stats.",
    usage = {
        "!stats: Returns a list of Username [telegram_id]: msg_num only top"..DEFAULT_SHOW_LIMIT,
        "!stats t|td|today|20150528: Returns this day stats",
        "!stats all: Returns All days stats",
        "!stats 20150528 "..DEFAULT_SHOW_LIMIT..": Returns a list only top "..DEFAULT_SHOW_LIMIT,
        "!state user_id: Returns this user All days stats"
    },
    patterns = {
        "^[!|#|/]([Ss]tats)$",
        "^[!|#|/]([Ss]tats) ([%w]+)$",
        "^[!|#|/]([Ss]tats) ([%w]+) ([-|%w]+)$",
        "^[!|#|/]([Ss]tate) ([%w]+)$"-- 读取用户的信息
    },
    run = run,
    pre_process = pre_process
}

end
