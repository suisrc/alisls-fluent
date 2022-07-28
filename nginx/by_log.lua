-- log_by_lua
local cjson = require "cjson"
local logger = require "resty.logger.socket"
if not logger.initted() then
    local ok, err = logger.init{
        host="127.0.0.1", -- 10.244.4.200
        port=514,
        sock_type="udp",
        flush_limit = 1, -- flush after each log, >1会发生日志丢失
        --drop_limit = 5678
    }
    if not ok then
        ngx.log(ngx.ERR, "failed to initialize the logger: ", err)
        return
    end
end
-- https://www.cnblogs.com/JohnABC/p/6182915.html
-- https://nginx.org/en/docs/http/ngx_http_core_module.html#variables
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
msg.userAgent = ngx.var.http_user_agent
msg.referer = ngx.var.http_referer
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
msg.userCode = tblj.uco or ""
msg.tenantCode = tblj.tco or ""
msg.roleCode = tblj.trc or ""
msg.appCode = tblj.three or ""
msg.appTenCode = tblj.app or ""
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
-- 服务
msg.serviceName = ngx.var.proxy_host or ""
msg.serviceAddr = ngx.var.upstream_addr or ""
-- 请求描述
msg.host = ngx.var.host
msg.path = ngx.var.request_uri
msg.method = ngx.var.method
msg.status = ngx.var.status
msg.startTime = ngx.req.start_time()
msg.reqTime = ngx.var.request_time
-- msg.reqTime = ngx.now() - msg.startTime
msg.reqHeaders = ngx.req.raw_header(true)
msg.respHeaders = "" -- 这里格式化
for k, v in pairs(ngx.resp.get_headers()) do
    if type(v) == "table" then
        for _, v1 in pairs(v) do
            msg.respHeaders = msg.respHeaders..k..": "..v1.."\r\n"
        end
    else
        msg.respHeaders = msg.respHeaders..k..": "..v.."\r\n"
    end
end
local ajson = "application/json"
local rqtyp = ngx.var.http_content_type
if rqtyp and string.sub(rqtyp, 1, #ajson) == ajson then
    msg.reqBody = ngx.var.request_body -- json格式的参数被记录
else
    msg.reqBody = "" -- 不记录参数
end
local json = ""
local rptyp = ngx.var.upstream_http_content_type
if rptyp and string.sub(rptyp, 1, #ajson) == ajson then
    -- body_filter_by_lua
    -- 每次请求的响应输出在ngx.arg[1]中；而是否到eof则标记在ngx.arg[2]中
    msg.respBody = ngx.ctx.resp_buffered   --json格式的返回结果被记录
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