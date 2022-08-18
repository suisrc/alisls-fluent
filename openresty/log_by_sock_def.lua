-- 移除了用户信息部分内容

-- log_by_lua
local cjson = require "cjson"
local logger = require "resty.logger.socket"
if not logger.initted() then
    local ok, err = logger.init{
        host      = os.getenv("LUA_SYSLOG_HOST") or "127.0.0.1",
        port      = tonumber(os.getenv("LUA_SYSLOG_PORT")) or 5144,
        sock_type = os.getenv("LUA_SYSLOG_TYPE") or "udp",
        -- flush after each log, >1会发生日志丢失
        flush_limit= 1,
        --drop_limit= 5678
    }
    if not ok then
        ngx.log(ngx.ERR, "failed to initialize the logger: ", err)
        return
    end
end
-- 日志级别信息
local msg = {}
msg.traceId = ngx.var.http_x_request_id
msg.clientId = ngx.var.http_x_client_id or ngx.var.cookie__xc
msg.remoteIp = ngx.var.http_x_real_ip or ngx.var.realip_remote_addr
msg.userAgent = ngx.var.http_user_agent or ""
msg.referer = ngx.var.http_referer or ""
msg.flowId = ngx.var.arg_flow or ""
-- 登录用户级基本信息在这里不做记录
-- 请求鉴权匹配的策略，记录请求通过接口的策略
msg.matchPolicys = ngx.var.http_x_request_sky_policys or ngx.ctx.sub_headers and ngx.ctx.sub_headers["X-Request-Sky-Policys"] or ""
-- 请求描述
msg.scheme = ngx.var.scheme or ""
msg.host = ngx.var.proxy_host or ngx.var.host or ""
msg.path = ngx.var.proxy_uri or ngx.var.request_uri or ""
msg.method = ngx.var.request_method or ""
msg.status = ngx.var.status or ""
msg.startTime = os.date("%Y-%m-%dT%H:%M:%S", ngx.req.start_time()) or ""
msg.reqTime = ngx.var.request_time or ""
-- msg.reqTime = ngx.now() - msg.startTime
-- 服务
msg.tags = ngx.var.proxy_tags or ""
msg.serviceName = ngx.var.proxy_host or ngx.ctx.sub_proxy_host or ""
msg.serviceAddr = ngx.var.upstream_addr or ngx.ctx.sub_upstream_addr or ""
msg.serviceAuth = ngx.ctx.sub_proxy_host or ""
msg.requester = msg.remoteIp     -- 请求者
msg.responder = msg.serviceName  -- 响应者
-- msg.reqHeaders = ngx.req.raw_header(true) or ""
-- msg.reqCookies = ngx.var.http_cookie or ""
local rpsky = "x-request-sky-"  -- 包含认证敏感信息，不能对外开放
local rpsrv = "x-service-name"  -- 应答的服务器
msg.reqHeaders = ""
msg.reqHeader2s = ""
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
    if k == rpsrv then
        msg.requester = v
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
    if k == rpsrv then
        msg.responder = v
    end
end
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
elseif msg.respBody ~= nil and msg.respBody ~= "" and string.sub(msg.respBody, 1, 1) ~= "#" then
    -- 解析 json
    local resj = cjson.decode(msg.respBody)
    -- 返回值可能存在不规范情况，即不是json类型
    if type(resj) == "table" and (not resj.success) then
        if resj.showType == 9 then
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