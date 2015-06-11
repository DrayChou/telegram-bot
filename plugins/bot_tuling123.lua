do

local tuling_config = load_from_file('data/tuling.lua')

-- 图灵机器人的KEY
local tuling_url = "http://www.tuling123.com/openapi/api"
local consumer_key = tuling_config.consumer_key

local function getTuling(user_id,info)
    local url = tuling_url.."&key="..consumer_key
    url=url.."&info="..info
    url=url.."&userid="..user_id
    
    vardump(url)
    
    local res,status = http.request(url)
    
    vardump(res)
    
    if status ~= 200 then return nil end
    local data = json:decode(res)
    
    return data.text
end

local function run(msg, matches)
    return getTuling(msg.from.id,matches[1])
end

return {
    description = "询问图灵小机器人", 
    usage = {
        "!bot info: 请求图灵的机器人接口，并返回回答"
    },
    patterns = {
        "^![Bb]ot (.*)$"
    }, 
    run = run 
}

end
