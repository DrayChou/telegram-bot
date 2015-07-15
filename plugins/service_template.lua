--[[
vardump msg: 
{
  date = 1433438016,
  flags = 16,
  from = {
    access_hash = 1,
    first_name = "Dray",
    flags = 528,
    id = 64163268,
    last_name = "🌞",
    phone = "16128881024",
    print_name = "Dray_🌞",
    type = "user"
  },
  id = "157104",
  out = false,
  service = false,
  text = "kick",
  to = {
    first_name = "Bot",
    flags = 144,
    id = 109098660,
    last_name = "DC",
    phone = "13134829895",
    print_name = "Bot_DC",
    type = "user"
  },
  unread = true
}
vardump chat_info: 
false


vardump msg: 
{
  date = 1433438082,
  flags = 16,
  from = {
    access_hash = 1,
    first_name = "Dray",
    flags = 528,
    id = 64163268,
    last_name = "🌞",
    phone = "16128881024",
    print_name = "Dray_🌞",
    type = "user"
  },
  id = "157108",
  out = false,
  service = false,
  text = "kick",
  to = {
    flags = 16,
    id = 17071158,
    members = {
      {
        access_hash = 1,
        first_name = "Star",
        flags = 24,
        id = 63406757,
        last_name = "Brilliant",
        print_name = "Star_Brilliant",
        real_first_name = "Star",
        real_last_name = "Brilliant",
        type = "user"
      },
      [0] = {
        access_hash = 1,
        first_name = "dabao",
        flags = 16,
        id = 96586640,
        last_name = "ou",
        print_name = "dabao_ou",
        type = "user"
      }
    },
    members_num = 48,
    print_name = "Bots-测试请和机器人私聊，勿在公共频道刷",
    title = "Bots-测试请和机器人私聊，勿在公共频道刷",
    type = "chat"
  },
  unread = true
}
vardump chat_info: 
false
]]

local function run(msg, matches)
    vardump(user_info("user#id64163268"))
    vardump(user_info("妹_蛇"))
    vardump(user_info("Dray"))
    vardump(user_info("@vickyatmes"))
    vardump(user_info("+8618651049664"))
    
   -- avoid this plugins to process user messages
   if not msg.realservice then
      -- return "Are you trying to troll me?"
      return nil
   end
   print("Service message received: " .. matches[1])
end

return {
   description = "Template for service plugins",
   usage = "",
   patterns = {
      "^[!|#|/]!tgservice (.*)$" -- Do not use the (.*) match in your service plugin
   },
   run = run
}
