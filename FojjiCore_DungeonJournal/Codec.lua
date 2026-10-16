local Addon = FojjiCoreNS
if not (Addon and Addon.IsForever) then return end
local FDJ = Addon.DJ

local Codec = {}
FDJ.Codec = Codec

local floor, byte, char, sub, format = math.floor, string.byte, string.char, string.sub, string.format
local MAX_DEPTH = 24

local function write(value, out, depth)
    local kind = type(value)
    if kind == "string" then
        out[#out + 1] = "s" .. #value .. ":" .. value
    elseif kind == "number" then
        if value ~= value or value == math.huge or value == -math.huge then value = 0 end
        if value == floor(value) and value > -1e15 and value < 1e15 then
            out[#out + 1] = format("i%d;", value)
        else
            out[#out + 1] = format("f%.6g;", value)
        end
    elseif kind == "boolean" then
        out[#out + 1] = value and "y" or "n"
    elseif kind == "table" then
        if depth >= MAX_DEPTH then error("too deep") end
        out[#out + 1] = "("
        local n = #value
        for i = 1, n do write(value[i], out, depth + 1) end
        out[#out + 1] = "|"
        for k, v in pairs(value) do
            local kk = type(k)
            local isArray = kk == "number" and k >= 1 and k <= n and k == floor(k)
            if not isArray and (kk == "string" or kk == "number") and type(v) ~= "function" and type(v) ~= "userdata" then
                write(k, out, depth + 1)
                write(v, out, depth + 1)
            end
        end
        out[#out + 1] = ")"
    else
        out[#out + 1] = "n"
    end
end

function Codec.Serialize(value)
    local out = {}
    write(value, out, 0)
    return table.concat(out)
end

local read

local function readNumber(text, pos)
    local stop = text:find(";", pos, true)
    if not stop then error("bad number") end
    local n = tonumber(sub(text, pos, stop - 1))
    if not n then error("bad number") end
    return n, stop + 1
end

read = function(text, pos, depth)
    local tag = sub(text, pos, pos)
    pos = pos + 1
    if tag == "s" then
        local colon = text:find(":", pos, true)
        if not colon then error("bad string") end
        local len = tonumber(sub(text, pos, colon - 1))
        if not len or len < 0 then error("bad string") end
        local stop = colon + len
        if stop > #text then error("truncated") end
        return sub(text, colon + 1, stop), stop + 1
    elseif tag == "i" or tag == "f" then
        return readNumber(text, pos)
    elseif tag == "y" then
        return true, pos
    elseif tag == "n" then
        return false, pos
    elseif tag == "(" then
        if depth >= MAX_DEPTH then error("too deep") end
        local tbl, i = {}, 0
        while sub(text, pos, pos) ~= "|" do
            if pos > #text then error("truncated") end
            local v
            v, pos = read(text, pos, depth + 1)
            i = i + 1
            tbl[i] = v
        end
        pos = pos + 1
        while sub(text, pos, pos) ~= ")" do
            if pos > #text then error("truncated") end
            local k, v
            k, pos = read(text, pos, depth + 1)
            v, pos = read(text, pos, depth + 1)
            if type(k) == "string" or type(k) == "number" then tbl[k] = v end
        end
        return tbl, pos + 1
    end
    error("bad tag")
end

function Codec.Deserialize(text)
    if type(text) ~= "string" or text == "" then return nil end
    local ok, value, pos = pcall(read, text, 1, 0)
    if not ok or pos ~= #text + 1 then return nil end
    return value
end

local ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
local ENCODE, DECODE = {}, {}
for i = 1, 64 do
    local c = sub(ALPHABET, i, i)
    ENCODE[i - 1] = c
    DECODE[byte(c)] = i - 1
end

function Codec.ToText(raw)
    local out, len = {}, #raw
    for i = 1, len, 3 do
        local a, b, c = byte(raw, i, i + 2)
        local n = a * 65536 + (b or 0) * 256 + (c or 0)
        local d1 = floor(n / 262144)
        local d2 = floor(n / 4096) % 64
        local d3 = floor(n / 64) % 64
        local d4 = n % 64
        out[#out + 1] = ENCODE[d1] .. ENCODE[d2] .. (b and ENCODE[d3] or "") .. (c and ENCODE[d4] or "")
    end
    return table.concat(out)
end

function Codec.FromText(text)
    text = text:gsub("[^%w%-_]", "")
    local out, len = {}, #text
    for i = 1, len, 4 do
        local c1, c2, c3, c4 = byte(text, i, i + 3)
        local d1, d2 = DECODE[c1], c2 and DECODE[c2]
        if not d1 or not d2 then return nil end
        local d3, d4 = c3 and DECODE[c3], c4 and DECODE[c4]
        local n = d1 * 262144 + d2 * 4096 + (d3 or 0) * 64 + (d4 or 0)
        out[#out + 1] = char(floor(n / 65536))
        if d3 then out[#out + 1] = char(floor(n / 256) % 256) end
        if d4 then out[#out + 1] = char(n % 256) end
    end
    return table.concat(out)
end

function Codec.Digest(text)
    local h1, h2 = 7919, 104729
    for i = 1, #text do
        local b = byte(text, i)
        h1 = (h1 * 31 + b) % 1000003
        h2 = (h2 * 17 + b * i) % 999983
    end
    return format("%05x%05x", h1, h2)
end

local function deflate(raw)
    local api = C_EncodingUtil
    if not (api and api.CompressString and Enum and Enum.CompressionMethod) then return nil end
    local ok, packed = pcall(api.CompressString, raw, Enum.CompressionMethod.Deflate)
    if ok and type(packed) == "string" and #packed < #raw then return packed end
    return nil
end

local function inflate(packed)
    local api = C_EncodingUtil
    if not (api and api.DecompressString and Enum and Enum.CompressionMethod) then return nil end
    local ok, raw = pcall(api.DecompressString, packed, Enum.CompressionMethod.Deflate)
    if ok and type(raw) == "string" then return raw end
    return nil
end

local HEAD = "FDJ"

function Codec.Pack(kind, value)
    local raw = Codec.Serialize(value)
    local mode = "p"
    local packed = deflate(raw)
    if packed then
        raw, mode = packed, "z"
    end
    local body = Codec.ToText(raw)
    return ("%s.%s.%s.%s.%s"):format(HEAD, kind, mode, Codec.Digest(body), body)
end

function Codec.Unpack(text, expectedKind)
    if type(text) ~= "string" then return nil, "empty" end
    text = text:gsub("%s+", "")
    local head, kind, mode, digest, body = text:match("^(%w+)%.(%w+)%.(%a)%.(%x+)%.([%w%-_]+)$")
    if head ~= HEAD then return nil, "format" end
    if expectedKind and kind ~= expectedKind then return nil, "kind" end
    if Codec.Digest(body) ~= digest then return nil, "damaged" end
    local raw = Codec.FromText(body)
    if not raw then return nil, "damaged" end
    if mode == "z" then
        raw = inflate(raw)
        if not raw then return nil, "unsupported" end
    elseif mode ~= "p" then
        return nil, "unsupported"
    end
    local value = Codec.Deserialize(raw)
    if value == nil then return nil, "damaged" end
    return value, kind
end
