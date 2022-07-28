-- access_by_lua
local iam = "/api/iam/v1/a/"
if string.sub(ngx.var.uri, 1, #iam) == iam or ngx.var.uri == "/healthz" then
    return
end
local res = ngx.location.capture("/authz", { copy_all_vars = true })
local cookies = res.header["Set-Cookie"]
if cookies then
    ngx.header["Set-Cookie"] = cookies
end
if res.status >= ngx.HTTP_OK and res.status < ngx.HTTP_SPECIAL_RESPONSE then
    for k,v in pairs(res.header) do
        if string.byte(k,1) == 88 and string.byte(k,2) == 45 then
            ngx.req.set_header(k, v)
        end
    end
    return
end
for k,v in pairs(res.header) do
    ngx.header[k] = v
end
ngx.header.content_type = res.header["Content-Type"]
ngx.status = res.status
ngx.say(res.body)
ngx.exit(res.status)