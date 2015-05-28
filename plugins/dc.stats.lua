-- Saves the number of messages from a user
-- Can check the number of messages with !stats

do

local NUM_MSG_MAX = 5
local TIME_CHECK = 4 -- seconds
local DEFAULT_SHOW_LIMIT = 25 -- 显示的最多条数

local function user_print_name(user)
  if user.print_name then
    return user.print_name
  end

  local text = ''
  if user.first_name then
    text = user.last_name..' '
  end
  if user.lastname then
    text = text..user.last_name
  end

  return text
end

-- Returns a table with `name` and `msgs` and `msgs_day`
local function get_msgs_user_chat(user_id, chat_id, day_id)
  local user_info = {}
  local uhash = 'user:'..user_id
  local user = redis:hgetall(uhash)

  local um_hash = 'msgs:'..user_id..':'..chat_id..':'..day_id
  if day_id:lower() == 'all' then
    um_hash = 'msgs:'..user_id..':'..chat_id
  end

  user_info.name = user_print_name(user)..' ('..user_id..')'
  user_info.msgs = tonumber(redis:get(um_hash) or 0)
  return user_info
end

local function get_msg_num_stats(msg, day_id, limit)
  if msg.to.type == 'chat' then
    local chat_id = msg.to.id
    -- Users on chat
    local hash = 'chat:'..chat_id..':users'
    local users = redis:smembers(hash)
    local users_info = {}

    -- Get user info
    for i = 1, #users do
      local user_id = users[i]
      local user_info = get_msgs_user_chat(user_id, chat_id, day_id)
      table.insert(users_info, user_info)
    end

    -- Sort users by msgs number
    table.sort(users_info, function(a, b)
        if a.msgs and b.msgs then
          return a.msgs > b.msgs
        end
      end)

    local text = ''
    local log_num = 0
    for k,user in pairs(users_info) do
        -- 加前缀
        if log_num == 0 then
          text = text..day_id:upper()..' TOP '..limit..'\n'
        end

        log_num = log_num + 1
        text = text..user.name..' => '..user.msgs..'\n'

        -- 如果超过50个了，不再输出
        if log_num >= limit then
            break
        end
    end

    return text
  end
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
  local hash = 'msgs:*:'..our_id
  local r = redis:eval(redis_scan, 1, hash)
  local text = 'Users: '..r

  hash = 'chat:*:users'
  r = redis:eval(redis_scan, 1, hash)
  text = text..'\nChats: '..r

  hash = 'chat:*:users:*'
  r = redis:eval(redis_scan, 1, hash)
  text = text..'\nChatsDays: '..r

  return text

end

local function run(msg, matches)
  if matches[1]:lower() == "stats1" then
    if msg.to.type == 'chat' then
      -- 解析第二个参数
      local day_id = os.date("%Y%m%d")
      if matches[2] then
        day_id = matches[2]
      end

      -- 解析查询的数量
      local limit = SHOW_LIMIT_NUM
      if matches[3] then
          limit = matches[3]
      end

      return get_msg_num_stats(msg, day_id, limit)
    elseif is_sudo(msg) then
      return get_bot_stats()
    else
      return 'Stats works only on chats'
    end
  end
end

local usage_txt = ""
usage_txt = usage_txt.."!stats: Returns a list of Username [telegram_id]: msg_num only top"..SHOW_LIMIT_NUM..'\n'
usage_txt = usage_txt.."!stats 20150528: Returns this day stats"..'\n'
usage_txt = usage_txt.."!stats all: Returns All days stats"..'\n'
usage_txt = usage_txt.."!stats 20150528 "..SHOW_LIMIT_NUM..": Returns a list only top "..SHOW_LIMIT_NUM..'\n',

return {
  description = "Plugin to update user stats.",
  usage = usage_txt,
  patterns = {
    "^!([Ss]tats1)$",
    "^!([Ss]tats1) (.+)$",
    "^!([Ss]tats1) (.+) (.+)$"
    },
  run = run,
  pre_process = pre_process
}

end
