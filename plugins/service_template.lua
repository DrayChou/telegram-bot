local function run(msg, matches)
    dump(msg)
    
    dump(chat_info(msg.to.id))
    
    send_msg (msg.from.print_name, 'pong', ok_cb, false)
    
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
      "^!!tgservice (.*)$" -- Do not use the (.*) match in your service plugin
   },
   run = run
}
