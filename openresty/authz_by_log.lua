-- log_by_lua
local cjson = require "cjson"
local logger = require "resty.logger.socket"
if not logger.initted() then
    local ok, err = logger.init{
        host= ngx.var.lua_syslog_host or "logs-svc.default.svc.cluster.local", -- 127.0.0.1
        port= ngx.var.lua_syslog_port or 5144,
        sock_type= ngx.var.lua_syslog_type or "udp",
        -- flush after each log, >1会发生日志丢失
        flush_limit= ngx.var.lua_syslog_limit or 1, 
        --drop_limit= 5678
    }
    if not ok then
        ngx.log(ngx.ERR, "failed to initialize the logger: ", err)
        return
    end
end
-- https://www.cnblogs.com/JohnABC/p/6182915.html
-- https://nginx.org/en/docs/http/ngx_http_core_module.html#variables
-- https://nginx.org/en/docs/http/ngx_http_proxy_module.html#variables
-- https://openresty-reference.readthedocs.io/en/latest/Lua_Nginx_API/#ngxvarvariable
-- https://zhuanlan.zhihu.com/p/67904411
-- construct the custom access log message in the Lua variable "msg"
-- traceId, flowId, clientId, tokenId, remoteIp, userAgent(终端), referer(界面), 
-- accountCode, userCode, tenantCode, roleCode, appCode(应用), appTenCode(租户应用)
-- service(服务), serviceAddr 
-- method(方法), status(状态), rqtime(请求), rptime(耗时), result_2(成功，失败，重定向), rqheader, rpheader(返回前端的header信息)
-- host(域名), path(路径), body(参数,只记录json), json(只有返回json结果才记录)
local msg = {}
msg.traceId = ngx.var.http_x_request_id
msg.clientId = ngx.var.http_x_client_id or ngx.var.cookie__xc
msg.remoteIp = ngx.var.realip_remote_addr or ngx.var.remote_addr
msg.userAgent = ngx.var.http_user_agent or ""
msg.referer = ngx.var.http_referer or ""
msg.flowId = ngx.var.arg_flow or ""
-- 登录者信息
-- 通过令牌获取登录者信息
local tblj = {}
local token = ngx.var.http_x_request_sky_authorize
if token then
    -- 解析base64令牌 to json
    tblj = cjson.decode(ngx.decode_base64(token))
end
msg.tokenId = tblj.jti or ""
msg.nickname = tblj.nnm or ""
msg.accountCode = tblj.sub or ""
msg.tenantCode = tblj.tco or ""
msg.userCode = tblj.uco or ""
msg.userTenCode = tblj.tuc or ""
msg.appCode = tblj.three or ""
msg.appTenCode = tblj.app or ""
msg.roleCode = tblj.trc or tblj.rol or ""
if msg.tokenId == "" then
    if ngx.var.http_authorization then
        local auth = ngx.var.http_authorization
        local auth_type = string.match(auth, "^Bearer%s+(%w+)")
        if auth_type == "kst" then
            msg.tokenId = string.sub(auth, 52, 76)
        end
    elseif ngx.var.cookie_kat then
        local auth = ngx.var.cookie_kat
        local auth_type = string.match(auth, "^(%w+)")
        if auth_type == "kst" then
            msg.tokenId = string.sub(auth, 45, 69)
        end
    end
end
-- 请求描述
msg.host = ngx.var.host or ""
msg.path = ngx.var.request_uri or ""
msg.method = ngx.var.request_method or ""
msg.status = ngx.var.status or ""
msg.startTime = os.date("%Y-%m-%dT%H:%M:%S", ngx.req.start_time()) or ""
msg.reqTime = ngx.var.request_time or ""
-- msg.reqTime = ngx.now() - msg.startTime
-- msg.reqHeaders = ngx.req.raw_header(true) or ""
-- msg.reqCookies = ngx.var.http_cookie or ""
msg.reqHeaders = ""
msg.reqHeader2s = ""
local rpsky = "x-request-sky-" -- 包含认证敏感信息，不能对外开放
for k, v in pairs(ngx.req.get_headers()) do
    -- authorization, cookie中包含用户登录的敏感信息，不能对外开放
    if k == 'authorization' or k == "cookie" or string.sub(k, 1, #rpsky) == rpsky then
        if type(v) == "table" then
            for _, v1 in pairs(v) do
                msg.reqHeader2s = msg.reqHeader2s..k..": "..v1.."\n"
            end
        else
            msg.reqHeader2s = msg.reqHeader2s..k..": "..v.."\n"
        end
    else
        if type(v) == "table" then
            for _, v1 in pairs(v) do
                msg.reqHeaders = msg.reqHeaders..k..": "..v1.."\n"
            end
        else
            msg.reqHeaders = msg.reqHeaders..k..": "..v.."\n"
        end
    end
end
msg.respHeaders = ""
for k, v in pairs(ngx.resp.get_headers()) do
    if type(v) == "table" then
        for _, v1 in pairs(v) do
            msg.respHeaders = msg.respHeaders..k..": "..v1.."\n"
        end
    else
        msg.respHeaders = msg.respHeaders..k..": "..v.."\n"
    end
end
-- 服务
msg.tags = ngx.var.proxy_tags or ""
msg.serviceName = ngx.var.proxy_host or ngx.ctx.sub_proxy_host or ""
msg.serviceAddr = ngx.var.upstream_addr or ngx.ctx.sub_upstream_addr or ""
msg.serviceAuth = ngx.ctx.sub_proxy_host or ""
-- 参数
local ajson = "application/json"
local rqtyp = ngx.var.http_content_type
if rqtyp and string.sub(rqtyp, 1, #ajson) == ajson then
    msg.reqBody = ngx.var.request_body -- json格式的参数被记录
else
    msg.reqBody = "" -- 不记录参数
end
-- 响应
--local rtype = ngx.resp.get_headers()["content-type"]
--local rptyp = ngx.var.upstream_http_content_type
--if rptyp and string.sub(rptyp, 1, #ajson) == ajson then
if ngx.ctx.resp_body ~= nil then
    -- body_filter_by_lua
    -- 每次请求的响应输出在ngx.arg[1]中；而是否到eof则标记在ngx.arg[2]中
    msg.respBody = ngx.ctx.resp_body   --json格式的返回结果被记录
else
    msg.respBody = "" -- 不记录返回结果
end
msg.result2 = "成功"
if msg.status >= "400" then
    msg.result2 = "错误"
elseif msg.status >= "300" then
    msg.result2 = "重定向"
elseif msg.respBody ~= nil and msg.respBody ~= "" then
    -- 解析 json
    local tblj = cjson.decode(msg.respBody)
    if not tblj.success then
        if tblj.showType == 9 then
            msg.result2 = "重定向"
        else
            msg.result2 = "错误"
        end
    end
end
-- table to json
local msg_str = cjson.encode(msg)
local bytes, err = logger.log(msg_str)
if err then
    ngx.log(ngx.ERR, "failed to log message: ", err)
    return
end