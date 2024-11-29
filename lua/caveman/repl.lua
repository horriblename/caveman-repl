local M = {}
local const = require('caveman.repl.const')
local commandline = require('caveman.repl.commandline')

local state = {
    ---@type table<integer, integer>
    jobs = {}
}

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
---@param style TrimBehavior
---@return fun():string?
local function trim_range(from, to, style)
    local trimmer
    if style == const.TrimBehavior.NONE then
        trimmer = function(s) return s end
    elseif style == const.TrimBehavior.ALWAYS then
        trimmer = function(s) return s:match('^%s*(.-)%s*$') end
    else
        local indent = vim.fn.indent(from)
        trimmer = function(s)
            return trim_inner(s, vim.bo.tabstop, indent)
        end
    end

    local i = from - 1

    return function()
        i = i + 1
        if i >= to then
            return nil
        end

        return trimmer(vim.fn.getline(i))
    end
end

---Validate a vim.b.* option and return its value, or nil if not set
---@param key string
---@param type string|string[]
---@return any?
local function validate_b_opt(key, type)
    vim.validate({
        ["vim.b." .. key] = { vim.b[key], type, true }
    })
end

---@param cmd string|string[]?
function M.start(cmd)
    vim.validate({ cmd = { cmd, { 'string', 'table' }, true } })
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

    local trim_style = parsed.flags.trim or
        validate_b_opt("caveman_repl_trim", "boolean") or
        const.TrimBehavior.FOLLOW_FIRST_LINE

    for line in trim_range(opts.line1, opts.line2, trim_style) do
        vim.api.nvim_chan_send(job_id, line .. '\n')
    end
end

function M._get_state()
    return state
end

return M
