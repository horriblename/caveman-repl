local M = {}
local const = require('caveman.repl.const')
local commandline = require('caveman.repl.commandline')

local state = {
    ---@type table<integer, integer>
    jobs = {}
}

---Get boolean config value
---@param arg boolean?
---@param b string name of vim.b variable
---@param g string? name of vim.g variable
---@param default boolean
---@return boolean
local function get_bool_config(arg, b, g, default)
    if arg ~= nil then
        return arg
    elseif vim.b[b] ~= nil then
        return vim.b[b]
    elseif g and vim.g[g] ~= nil then
        return vim.g[g]
    else
        return default
    end
end

---@param s string
---@param tab_size integer
---@param to_trim integer
---@return string
local function trim_inner(s, tab_size, to_trim)
    local indent = 1

    for i, char in s:gmatch('()(.)') do
        if indent > to_trim then
            return s:sub(i --[[@as integer]])
        end
        if char == ' ' then
            indent = indent + 1
        elseif char == '\t' then
            indent = indent + tab_size
        else
            return s:sub(i --[[@as integer]])
        end
    end
    return ""
end

---@param from integer
---@param to integer
---@param opt {trim: TrimBehavior, keep_empty: boolean}
---@return fun():string?
local function trim_range(from, to, opt)
    local trimmer
    if opt.trim == const.TrimBehavior.NONE then
        trimmer = function(s) return s end
    elseif opt.trim == const.TrimBehavior.ALWAYS then
        trimmer = function(s) return s:match('^%s*(.-)%s*$') end
    else
        local indent = vim.fn.indent(from)
        trimmer = function(s)
            return trim_inner(s, vim.bo.tabstop, indent)
        end
    end

    local i = from - 1

    return function()
        while true do
            i = i + 1
            if i > to then
                return nil
            end

            local line = vim.fn.getline(i)
            local should_send = not opt.keep_empty or string.find(line, '[^%s]')
            if should_send then
                return trimmer(line)
            end
        end
    end
end

---Validate a vim.b.* option and return its value, or nil if not set
---@param key string
---@param typ string|string[]|fun(any):boolean
---@param transform (fun(any):any)?
---@return any?
local function validate_b_opt(key, typ, transform)
    local val = vim.b[key]
    vim.print(val)
    if not val then
        return nil
    end
    vim.validate({
        ["vim.b." .. key] = { val, typ, true }
    })
    return transform and transform(val) or val
end

---Validate a vim.b.* option and return its value, or nil if not set
---@param key string
---@param typ string|string[]|fun(any):boolean
---@param transform (fun(any):any)?
---@return any?
local function validate_g_opt(key, typ, transform)
    local val = vim.g[key]
    if not val then
        return nil
    end
    vim.validate({
        ["vim.g." .. key] = { val, typ, true }
    })
    return transform and transform(val) or val
end

---@param cmd string|string[]?
function M.start(cmd)
    vim.validate({ cmd = { cmd, { 'string', 'table' }, true } })
    if type(cmd) == "table" and cmd[1] == nil then
        cmd = nil
    end
    cmd = cmd or
        validate_b_opt("caveman_repl_cmd", { "string", "table" }) or
        {}

    local current_win = vim.api.nvim_get_current_win()

    vim.cmd('botright split')
    if type(cmd) == "table" then
        vim.cmd.terminal(unpack(cmd))
    else
        vim.cmd.terminal(cmd)
    end
    local term_id = vim.b.terminal_job_id

    vim.api.nvim_set_current_win(current_win)
    local buf = vim.api.nvim_get_current_buf()
    state.jobs[buf] = term_id
end

function M.send_range(opts)
    local bufnr = vim.api.nvim_get_current_buf()
    local job_id = state.jobs[bufnr]
    if not job_id then
        vim.notify('No job id found for buffer ' .. bufnr, vim.log.levels.ERROR)
        return
    end
    local parsed = commandline.parse_flags(commandline.send_flags, opts.fargs)

    local trim_flag = commandline.send_flags.trim
    local opt = {
        trim = parsed.flags.trim or
            validate_b_opt("caveman_repl_trim", trim_flag.type, trim_flag.transform) or
            validate_g_opt("caveman_repl_trim", trim_flag.type, trim_flag.transform) or
            const.TrimBehavior.FOLLOW_FIRST_LINE,
        keep_empty = get_bool_config(
            parsed.flags.keep_empty,
            "caveman_repl_keep_empty",
            "caveman_repl_keep_empty",
            false
        )
    }

    vim.print(opt)

    for line in trim_range(opts.line1, opts.line2, opt) do
        vim.api.nvim_chan_send(job_id, line .. '\n')
    end
end

function M._get_state()
    return state
end

return M
