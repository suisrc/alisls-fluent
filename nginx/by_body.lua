-- body_filter_by_lua
-- https://github.com/openresty/lua-nginx-module/issues/1092

if ngx.is_subrequest then
    return -- 不记录子请求
end
if ngx.ctx.resp_buffered == nil then
    local ajson = "application/json"
    local rtype = ngx.var.upstream_http_content_type
    -- ngx.log(ngx.ERR, "content_type: ", rtype)
    if rtype and string.sub(rtype, 1, #ajson) ~= ajson then
        return -- 只记录json内容
    end
end
local chunk, eof = ngx.arg[1], ngx.arg[2]
-- ngx.log(ngx.ERR, "chunk: ", chunk)
if chunk ~= nil and chunk ~= "" then
    -- 这种行为很容易导致LuaJIT发生GC，但是这确实是当前唯一解决方案
    ngx.ctx.resp_buffered = (ngx.ctx.resp_buffered or "")..chunk
end

-- -- 获取当前响应数据
-- if ngx.ctx.resp_buffered == nil then
--     ngx.ctx.resp_buffered = {}
-- end
-- -- 如果非最后一次响应，将当前响应赋值
-- if chunk ~= nil and chunk ~= "" then
--     -- 非子请求，非空
--     table.insert(ngx.ctx.resp_buffered, chunk)
--     -- 将当前响应赋值为空，以修改后的内容作为最终响应
--     -- 注意，这里会导致无法进行流处理，只记录json数据
--     ngx.arg[1] = nil
-- end
-- -- 如果为最后一次响应，对所有响应数据进行处理
-- if eof then
--     -- 获取所有响应数据
--     local body = table.concat(ngx.ctx.resp_buffered)
--     ngx.ctx.resp_buffered = nil
--     -- 进行你所需要进行的处理
--     -- ... 此处可以增加敏感词检测等操作
--     -- 重新赋值响应数据，以修改后的内容作为最终响应
--     ngx.arg[1] = body
-- end