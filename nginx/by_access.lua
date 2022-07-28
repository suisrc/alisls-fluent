-- access_by_lua
local spp = ngx.var.skip_pre_path or "/api/iam/v1/a/" -- 跳过忽略的接口
if spp and string.sub(ngx.var.uri, 1, #spp) == spp or ngx.var.uri == "/healthz" then
    -- ngx.log(ngx.ERR, "skip pre path: ", ngx.var.uri)
    return
end
-- 子请求验证权限
local auz = ngx.var.auth_uri_path or "/authz" -- 验证的接口
local res = ngx.location.capture(auz, { copy_all_vars = true })
-- 设置响应的cookie信息
local cookies = res.header["Set-Cookie"]
if cookies then
    ngx.header["Set-Cookie"] = cookies
end
if res.status >= ngx.HTTP_OK and res.status < ngx.HTTP_SPECIAL_RESPONSE then
    for k,v in pairs(res.header) do 
        -- 传递请求头信息
        if string.byte(k,1) == 88 and string.byte(k,2) == 45 then
            ngx.req.set_header(k, v)
        end
    end
    -- 继续主请求内容
    return
end
-- 请求被认证服务终止，以认证服务器结果作为请求结果返回
for k,v in pairs(res.header) do
    ngx.header[k] = v
end
ngx.header.content_type = res.header["Content-Type"]
ngx.status = res.status
ngx.say(res.body)
ngx.exit(res.status)