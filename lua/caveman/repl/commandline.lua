local M = {}
local const = require('caveman.repl.const')

---@alias Completion fun(arg_lead: string, cmd_line: string, cursor_pos: integer):string[]

---@class Flag
---@field type string|fun(string):boolean, string?
---error string or nil if ok
---@field default any
---@field transform (fun(string):any)?
---@field complete fun():string[]

---@alias Flags table<string, Flag>

---@param s string
---@param delimiter string
---@return string, string?
local function split_once(s, delimiter)
    local pos = s:find(delimiter, 1, true)
    if not pos then
        return s, nil
    end
    local before = string.sub(s, 1, pos - 1)
    local after = string.sub(s, pos + 1)
    return before, after
end

---@type table<string, fun(string):boolean>
local builtin_types = {
    boolean = function(x) return x == "true" or x == "false" end,
    number = function(x) return tonumber(x) and true or false end,
    string = function() return true end
}

---@param flags Flags
---@param args string[]
---@return {flags: table<string, any>, rest: string[]}
function M.parse_flags(flags, args)
    local parsed = {}
    local rest = {}
    for _, arg in ipairs(args) do
        local flag_name, val = split_once(arg, '=')
        flag_name = string.gsub(flag_name, '^%-', '')

        local flag = flags[flag_name]
        local validator = assert(
            type(flag.type) == "function"
            and flag.type --[[@as fun(string):boolean,string?]]
            or builtin_types[flag.type]
        )

        if flag then
            vim.validate({
                [flag_name] = { val, validator },
            })

            parsed[flag_name] = flag.transform and flag.transform(val) or val
        else
            table.insert(rest, arg)
        end
    end

    return { flags = parsed, rest = rest }
end

---@param flags Flags
---@return Completion
function M.gen_complete(flags)
    local flag_names = {}
    for name, _ in pairs(flags) do
        table.insert(flag_names, name)
    end

    return function(arg_lead)
        local name, _ = split_once(arg_lead, '=')
        name = string.gsub(name, '^%-', '')
        local flag = flags[name]
        if flag then
            return vim.iter(flag.complete()):map(function(item)
                return string.format('-%s=%s', name, item)
            end):totable()
        end

        return vim.iter(flag_names):map(function(fname)
            return string.format('-%s=', fname)
        end):totable()
    end
end

---@type Flags
M.send_flags = {
    trim = {
        default = "",
        type = function(x)
            if const.TrimBehavior[string.upper(x)] then
                return true
            end
            return false, "trim should be a TrimBehavior"
        end,
        transform = function(s)
            return const.TrimBehavior[string.upper(s)]
        end,
        complete = function()
            return vim.iter(vim.tbl_keys(const.TrimBehavior))
                :map(string.lower)
                :totable()
        end,
    },
    keep_empty = {
        default = false,
        type = "boolean",
        transform = function(s) return s == "true" end,
        complete = function() return { "true", "false" } end,
    }
}

return M
