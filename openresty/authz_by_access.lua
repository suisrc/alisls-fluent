-- access_by_lua
local spp = ngx.var.lua_skip_pre_path or "/api/iam/v1/a/" -- 跳过忽略的接口
if spp and string.sub(ngx.var.uri, 1, #spp) == spp or ngx.var.uri == "/healthz" then
    -- ngx.log(ngx.ERR, "skip pre path: ", ngx.var.uri)
    return
end
-- 子请求验证权限
local auz = ngx.var.lua_auth_uri_path or "/authz" -- 验证的接口
local res = ngx.location.capture(auz, { copy_all_vars = true, ctx = ngx.ctx })
-- 设置响应的cookie信息
if res.status >= ngx.HTTP_OK and res.status < ngx.HTTP_SPECIAL_RESPONSE then
    for k,v in pairs(res.header) do 
        -- 传递请求头信息
        if string.byte(k,1) == 88 and string.byte(k,2) == 45 then
            ngx.req.set_header(k, v)
        end
    end
    local cookies = res.header["Set-Cookie"]
    if cookies then
        ngx.header["Set-Cookie"] = cookies
    end
    -- 继续主请求内容
    return
end
-- 请求被认证服务终止，以认证服务器结果作为请求结果返回
for k,v in pairs(res.header) do
    if string.byte(k,1) == 88 and string.byte(k,2) == 45 then
        -- 特殊标记的请求头信息，忽略(缓存上下文中,日志系统可能需要)
        if ngx.ctx.sub_headers == nil then
            ngx.ctx.sub_headers = {}
        end
        ngx.ctx.sub_headers[k] = v
    else
        ngx.header[k] = v
    end
end
ngx.header.content_type = res.header["Content-Type"] or res.header["content-type"]
ngx.status = res.status
ngx.say(res.body)
ngx.exit(res.status)

