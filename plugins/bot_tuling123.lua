do

local tuling_config = load_from_file('data/tuling.lua')

-- 图灵机器人的KEY
local tuling_url = "http://www.tuling123.com/openapi/api"
local consumer_key = tuling_config.consumer_key

local function getTuling(user_id,info)
    local url = tuling_url.."?key="..consumer_key
    url = url.."&info="..info
    url = url.."&userid="..user_id
    
    vardump(url)
    
    local res,status = http.request(url)
    
    vardump(res)
    
    if status ~= 200 then return nil end
    local data = json:decode(res)
    
    local text = data.text
    
    -- 如果有链接
    if data.url then
        text = "\n"..text.." "..data.url
    end
    
    -- 如果是新闻
    if data.code == 302000 then
        for k,new in pairs(data.list) do
            text = text.."\n 标题:".." "..new.article
            text = text.."\n 来源:".." "..new.source
            text = text.."\n".." "..new.detailurl
            text = text.."\n".." "..new.icon
            
            if k >= 3 then
                break;
            end
        end
    end
    
    -- 如果是菜谱
    if data.code == 308000 then
        for k,new in pairs(data.list) do
            text = text.."\n 名称:".." "..new.name
            text = text.."\n 详情:".." "..new.info
            text = text.."\n".." "..new.detailurl
            text = text.."\n".." "..new.icon
            
            if k >= 3 then
                break;
            end
        end
    end
    
    -- 如果是列车
    if data.code == 305000 then
        for k,new in pairs(data.list) do
            text = text.."\n 车次:".." "..new.trainnum
            text = text.."\n 起始站:".." "..new.start
            text = text.."\n 到达站:".." "..new.terminal
            text = text.."\n 开车时间:".." "..new.starttime
            text = text.."\n 到达时间:".." "..new.endtime
            text = text.."\n".." "..new.detailurl
            text = text.."\n".." "..new.icon
            
            if k >= 3 then
                break;
            end
        end
    end
    
    -- 如果是航班
    if data.code == 306000 then
        for k,new in pairs(data.list) do
            text = text.."\n 航班:".." "..new.flight
            text = text.."\n 航班路线:".." "..new.route
            text = text.."\n 开车时间:".." "..new.starttime
            text = text.."\n 到达时间:".." "..new.endtime
            text = text.."\n 航班状态:".." "..new.state
            text = text.."\n".." "..new.detailurl
            text = text.."\n".." "..new.icon
            
            if k >= 3 then
                break;
            end
        end
    end
    
    return text
end

local function run(msg, matches)
    return getTuling(msg.from.id,matches[1])
end

return {
    description = "询问图灵小机器人", 
    usage = {
        "!bot info: 请求图灵的机器人接口，并返回回答。",
        "Request Turing robot, and return the results. Only support Chinese.",
        "升级链接|Upgrade link:http://www.tuling123.com/openapi/record.do?channel=98150",
        "图灵机器人注册邀请地址，每有一个用户通过此地址注册账号，增加本接口可调用次数 1000次/天。",
        "Turing robot registration invitation address, each user has a registered account through this address, increase the number of calls this interface can be 1000 times / day. Translation from Google!"
    },
    patterns = {
        "^![Bb]ot (.*)$"
    }, 
    run = run 
}

end
