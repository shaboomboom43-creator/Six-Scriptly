-- SCRIPTLY // 628  -  GITHUB LOADER  (build 6.28.1)
-- One file, one download. Works with executors that provide game:HttpGet or an
-- http request function, and with either loadstring or load.
-- For use in experiences you own or are authorised to test.
local OWNER, REPO, BRANCH = "shaboomboom43-creator", "Scriptly", "main"
local FILE = "ScriptlyClient.lua"

local function env(name)
    local ok, value = pcall(function()
        local genv = (type(getgenv) == "function" and getgenv()) or _G
        return genv[name]
    end)
    return ok and value or nil
end

local compile = loadstring or env("loadstring") or load or env("load")
if type(compile) ~= "function" then
    warn("[Scriptly 628] This executor does not provide loadstring/load.")
    return
end

local function fetch(url)
    local ok, body = pcall(function() return game:HttpGet(url) end)
    if ok and type(body) == "string" and body ~= "" then return body end

    -- Fallback for executors without game:HttpGet.
    local request = env("request") or env("http_request")
    if not request then
        local syn = env("syn")
        request = type(syn) == "table" and syn.request or nil
    end
    if not request then
        local http = env("http")
        request = type(http) == "table" and http.request or nil
    end
    if type(request) == "function" then
        local ok2, res = pcall(request, { Url = url, Method = "GET" })
        if ok2 and type(res) == "table" and res.StatusCode == 200 and type(res.Body) == "string" and res.Body ~= "" then
            return res.Body
        end
    end
    return nil
end

local url = string.format("https://raw.githubusercontent.com/%s/%s/%s/%s?t=%d", OWNER, REPO, BRANCH, FILE, os.time())
local source = fetch(url)
if not source then
    warn("[Scriptly 628] Could not download " .. FILE .. ". Check that the repository is PUBLIC and the branch is '" .. BRANCH .. "'.")
    return
end

local chunk, compileError = compile(source)
if type(chunk) ~= "function" then
    warn("[Scriptly 628] Compilation failed: " .. tostring(compileError))
    return
end

local ran, runtimeError = pcall(chunk)
if not ran then warn("[Scriptly 628] Startup failed: " .. tostring(runtimeError)) end
